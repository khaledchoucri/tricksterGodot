class_name ActorSprite
extends AnimatedSprite2D
## Plays exported actor animations by action name and facing vector.
## Sheets come from tools/export_actor.py: animations are named
## "<action>_<dir>" and every frame shares one foot anchor.
##
## Works with any set of directions: it picks the closest one the art has,
## and a missing side is drawn by mirroring the other (an art set may ship
## only s, se, e, ne, n). Frames can carry a hand socket, where a held weapon
## (HeldWeapon) attaches.
##
## Playable characters also have a palette (outfits dyed through
## set_outfit) and worn items (hats, shields, masks: wear()) placed on every
## frame from the original pivot tables (tools/export_equip.py).

const PALETTE_SHADER := preload("res://shaders/palette.gdshader")
const EQUIP_DIR := "res://original_assets/equip"

const DIRS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const MIRROR := {"e": "w", "se": "sw", "s": "s", "sw": "se", "w": "e", "nw": "ne", "n": "n", "ne": "nw"}

var available: Dictionary = {}  # action -> Array of direction codes
var lengths: Dictionary = {}    # action -> seconds at speed 1.0
var sockets: Dictionary = {}    # animation name -> Array of {"hand": Vector2, "front": bool} or null per frame
var facing := Vector2(1, 1).normalized()
var action := ""
## Draw the left-facing directions by mirroring the right ones even when
## left-facing art exists (to compare the two).
var prefer_mirror := false

var _anchor := Vector2.ZERO
var _cell := Vector2.ZERO
var actor_name := ""
var _stop_at := -1  # frame to hold on when playing part of a clip
var _last_dir: Dictionary = {}  # action -> direction last used, for tie-breaking
var _palette: Dictionary = {}   # {"base": [[r, g, b] x256], "parts": {"w13": {index: [r, g, b]}}}
var _palette_tex: ImageTexture
var _equip: Dictionary = {}     # {"groups": {group: {animation: [[x, y, frame, front] or 0]}}, "items": {item: group}}
var _worn: Dictionary = {}      # slot -> {"item", "sprite": Sprite2D, "frames": Array, "group": String}


## Loads <folder>/<actor_name>/<actor_name>.json and .tres. Original sprites
## live in original_assets/actors/; imported new art in art_build/.
func setup(p_actor: String, folder := "res://original_assets/actors") -> bool:
	var base := "%s/%s/%s" % [folder, p_actor, p_actor]
	if not ResourceLoader.exists(base + ".tres") or not FileAccess.file_exists(base + ".json"):
		push_warning("Missing exported sprites for %s; run tools/export_actor.py" % p_actor)
		return false
	# Setting up again (a job change) replaces everything from the last actor.
	for slot: String in _worn:
		(_worn[slot].sprite as Node).queue_free()
	_worn.clear()
	_equip = {}
	_palette = {}
	available.clear()
	lengths.clear()
	sockets.clear()
	_last_dir.clear()
	actor_name = p_actor
	sprite_frames = load(base + ".tres")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	centered = false
	_anchor = Vector2(manifest.anchor[0], manifest.anchor[1])
	_cell = Vector2(manifest.cell[0], manifest.cell[1])
	offset = -_anchor
	var s := float(manifest.get("display_scale", 1.0))
	scale = Vector2(s, s)
	if manifest.get("filter", "") == "linear":
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = null
	if manifest.has("palette"):
		_palette = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/%s" % [folder, p_actor, manifest.palette]))
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = PALETTE_SHADER
		material = mat
		set_outfit({})
	var equip_path := base + "_equip.json"
	if FileAccess.file_exists(equip_path):
		_equip = JSON.parse_string(FileAccess.get_file_as_string(equip_path))
	for act: String in manifest.actions:
		var dirs: Dictionary = manifest.actions[act].dirs
		available[act] = dirs.keys()
		var total := 0.0
		for f in dirs.values()[0]:
			total += minf(f.ms, 400.0)  # long holds (death poses) are capped
		lengths[act] = total / 1000.0
		for d: String in dirs:
			var per_frame: Array = []
			for f: Dictionary in dirs[d]:
				per_frame.append({"hand": Vector2(f.hand[0], f.hand[1]), "front": f.front} if f.has("hand") else null)
			sockets["%s_%s" % [act, d]] = per_frame
	return true


static func dir_index(v: Vector2) -> int:
	return posmod(roundi(v.angle() / (PI / 4.0)), 8)


func has_action(act: String) -> bool:
	return available.has(act)


## Closest direction the art can show for `v`: [direction code in the
## sheets, mirrored?]. Ties keep the direction used last, so aiming straight
## along an axis between two drawn directions doesn't flicker.
func dir_for(act: String, v: Vector2) -> Array:
	var want := dir_index(v)
	var dirs: Array = available.get(act, [])
	var best: Array = []
	var best_dist := 99
	var last: String = _last_dir.get(act, "")
	for d: String in DIRS:
		var source := ""
		var mirrored := false
		if prefer_mirror and d in ["w", "sw", "nw"] and MIRROR[d] in dirs:
			source = MIRROR[d]
			mirrored = true
		elif d in dirs:
			source = d
		elif MIRROR[d] in dirs:
			source = MIRROR[d]
			mirrored = true
		else:
			continue
		var dist := absi(DIRS.find(d) - want)
		dist = mini(dist, 8 - dist)
		if dist < best_dist or (dist == best_dist and d == last):
			best_dist = dist
			best = [source, mirrored, d]
	if best.is_empty():
		return ["", false]
	_last_dir[act] = best[2]
	return [best[0], best[1]]


## Plays an action facing `v`. `duration` > 0 rescales the clip to that length.
## `frames` [from, to] plays only that part of the clip (backwards if from > to)
## and holds the last frame.
func play_action(act: String, v := Vector2.ZERO, duration := 0.0, restart := false, frames: Array = []) -> void:
	if not has_action(act):
		return
	if v != Vector2.ZERO:
		facing = v.normalized()
	var pick := dir_for(act, facing)
	var anim := "%s_%s" % [act, pick[0]]
	flip_h = pick[1]
	# A flipped frame mirrors inside its cell; keep the feet on the same spot.
	offset = Vector2(_anchor.x - _cell.x if flip_h else -_anchor.x, -_anchor.y)
	action = act
	var share := 1.0
	_stop_at = -1
	if frames.size() == 2:
		var count := sprite_frames.get_frame_count(anim)
		share = float(absi(frames[1] - frames[0]) + 1) / count
		_stop_at = clampi(frames[1], 0, count - 1)
	speed_scale = lengths[act] * share / duration if duration > 0.0 else 1.0
	if animation == anim and is_playing() and not restart and frames.is_empty():
		return
	stop()
	if frames.size() == 2 and frames[0] > frames[1]:
		play_backwards(anim)
	else:
		play(anim)
	if frames.size() == 2:
		frame = clampi(frames[0], 0, sprite_frames.get_frame_count(anim) - 1)


## Hand socket of the frame on screen, relative to the feet, in the parent's space:
## {"hand": Vector2, "front": bool}, or an empty Dictionary if the frame has none.
func hand_socket() -> Dictionary:
	var per_frame: Array = sockets.get(animation, [])
	if frame >= per_frame.size() or per_frame[frame] == null:
		return {}
	var s: Dictionary = per_frame[frame]
	var hand: Vector2 = s.hand * scale  # in the parent's space
	if flip_h:
		hand.x = -hand.x
	return {"hand": hand, "front": s.front}


func _ready() -> void:
	frame_changed.connect(func() -> void:
		if _stop_at >= 0 and frame == _stop_at:
			_stop_at = -1
			pause()
		_place_worn())
	animation_changed.connect(_place_worn)


# ---------------------------------------------------------------- outfits

## Recolours from the character's original palettes: "p" is the hair colour
## chosen at character creation in Trickster (part/<chr>_N.pal), e.g.
## {"p": 3}. The "w" sets (wear_parts) exist in the data too, but how the
## original used them is unconfirmed, so nothing applies them yet.
func set_outfit(dyes: Dictionary) -> void:
	if _palette.is_empty():
		return
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	var base: Array = _palette.base
	for i in 256:
		var c: Array = base[i]
		img.set_pixel(i, 0, Color8(int(c[0]), int(c[1]), int(c[2])))
	for part: String in dyes:
		var over: Dictionary = _palette.parts.get("%s%d" % [part, int(dyes[part])], {})
		for k: String in over:
			var c: Array = over[k]
			img.set_pixel(int(k), 0, Color8(int(c[0]), int(c[1]), int(c[2])))
	if _palette_tex:
		_palette_tex.update(img)
	else:
		_palette_tex = ImageTexture.create_from_image(img)
	(material as ShaderMaterial).set_shader_parameter("palette", _palette_tex)


## Dye variants this character's art has for `part` (e.g. "w1" -> 7).
func outfit_variants(part: String) -> int:
	var n := 0
	while _palette.get("parts", {}).has("%s%d" % [part, n]):
		n += 1
	return n


# ---------------------------------------------------------------- worn items

## Shows `item` (an exported equip sprite such as "hat019", or "" to take it
## off) in `slot`. Items without pivots for this character stay hidden.
func wear(slot: String, item: String) -> void:
	var cur: Dictionary = _worn.get(slot, {})
	if cur.get("item", "") == item:
		return
	if cur.has("sprite"):
		(cur.sprite as Node).queue_free()
	_worn.erase(slot)
	var group: String = _equip.get("items", {}).get(item, "")
	var info_path := "%s/%s.json" % [EQUIP_DIR, item]
	if item == "" or group == "" or not FileAccess.file_exists(info_path):
		return
	var s := Sprite2D.new()
	s.texture = load("%s/%s.png" % [EQUIP_DIR, item])
	s.centered = false
	s.region_enabled = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	_worn[slot] = {"item": item, "sprite": s, "group": group,
		"frames": JSON.parse_string(FileAccess.get_file_as_string(info_path)).frames}
	_place_worn()


func worn_item(slot: String) -> String:
	return _worn.get(slot, {}).get("item", "")


func _place_worn() -> void:
	for slot: String in _worn:
		var w: Dictionary = _worn[slot]
		var s: Sprite2D = w.sprite
		var rows: Array = _equip.groups[w.group].get(animation, [])
		var rec: Variant = rows[frame] if frame < rows.size() else 0
		if not rec is Array or int(rec[2]) >= w.frames.size():
			s.visible = false
			continue
		var f: Array = w.frames[int(rec[2])]
		s.visible = true
		s.region_rect = Rect2(f[0], 0, f[1], f[2])
		var at := Vector2(float(rec[0]) + float(f[3]), float(rec[1]) + float(f[4]))
		s.flip_h = flip_h
		if flip_h:
			at.x = -at.x - float(f[1])
		s.position = at
		s.show_behind_parent = int(rec[3]) == 0
