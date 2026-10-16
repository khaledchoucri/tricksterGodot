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
var _stop_at := -1  # frame to hold on when playing part of a clip
var _last_dir: Dictionary = {}  # action -> direction last used, for tie-breaking


## Loads <folder>/<actor_name>/<actor_name>.json and .tres. Original sprites
## live in original_assets/actors/; imported new art in art_build/.
func setup(actor_name: String, folder := "res://original_assets/actors") -> bool:
	var base := "%s/%s/%s" % [folder, actor_name, actor_name]
	if not ResourceLoader.exists(base + ".tres") or not FileAccess.file_exists(base + ".json"):
		push_warning("Missing exported sprites for %s; run tools/export_actor.py" % actor_name)
		return false
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
			pause())
