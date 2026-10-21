extends Node
## Imports generated character frames into game-ready sheets.
##
## Input: art/actors/<name>/<action>/<dir>/*.png (dirs are e, se, s, sw, w,
## nw, n, ne; any subset). Each PNG is one frame, or a strip of N frames side
## by side when its name ends in _xN (run_x4.png). Files play in name order.
## Frames are on a flat magenta (#FF00FF) background at any size.
## Optional art/actors/<name>/actor.json: {"frame_ms": {"run": 80},
## "loop": {"slash": false}, "reference": "idle/se", "game_body": 80,
## "guides": {"slash": "weapon_crit"}} (which pose guide an action followed).
##
## Per frame: key out the magenta and its colour spill, find the figure,
## scale the whole actor by one factor (so its body is SHEET_BODY px tall in
## the reference frame), put the feet at a fixed anchor, and crop
## every frame of an action to a shared cell with room for an outline. Hand
## points come from the matching pose guide when one exists locally
## (original_assets/pose_guides/). Writes art_build/<name>/: a sheet per
## action, <name>.json (the ActorSprite manifest), <name>.tres (SpriteFrames)
## and palette.png (main colours, for the palette-lock shader).
##
## Run: godot --headless --path . res://scenes/tools/art_import.tscn -- <name>

const DIRS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const CANVAS_BODY := 320.0  # feet-to-crown height on the 512 canvas (the pose guides' scale)
const SHEET_BODY := 160.0   # the same height in the exported sheets
const GAME_BODY := 80.0     # world px, the current sprites' height in the game
const PAD := 8              # transparent margin around every cell (room for the outline)
const WORK_HEIGHT := 700     # frames are reduced to about this height before keying
const DEFAULT_MS := 90
const NO_LOOP: Array[String] = ["attack", "slash", "swing", "weapon_crit", "hit", "faint", "death", "dodge", "cast", "throw", "jump"]
const PALETTE_SIZE := 40

var _cfg: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <actor name>")
		get_tree().quit(1)
		return
	var actor := args[0]
	var src := "res://art/actors/%s/" % actor
	if FileAccess.file_exists(src + "actor.json"):
		_cfg = JSON.parse_string(FileAccess.get_file_as_string(src + "actor.json"))
	var actions := _scan(src)
	if actions.is_empty():
		push_error("no frames found under " + src)
		get_tree().quit(1)
		return
	# 1. Key and trim every frame (at working resolution).
	var figures := {}  # action -> dir -> Array of {image, feet}
	for action: String in actions:
		figures[action] = {}
		for d: String in actions[action]:
			var list: Array = []
			for path: String in actions[action][d]:
				for img in _split(path):
					list.append(_figure(img))
			figures[action][d] = list
	# 2. One scale for the whole actor, from the reference frame.
	var ref: String = _cfg.get("reference", "idle/se")
	var ref_parts := ref.split("/")
	var ref_fig: Dictionary = _first_figure(figures, ref_parts[0], ref_parts[1] if ref_parts.size() > 1 else "se")
	var scale := SHEET_BODY / float(ref_fig.feet.y)
	# 3. Build sheets.
	var out := "res://art_build/%s/" % actor
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var game_body := float(_cfg.get("game_body", GAME_BODY))
	var manifest := {"actor": actor, "source": "art/actors/" + actor, "display_scale": game_body / SHEET_BODY,
		"filter": "linear", "actions": {}}
	var cell_all := Vector2i.ZERO
	var anchor_all := Vector2i.ZERO
	var built := {}
	for action: String in figures:
		built[action] = _build_action(actor, action, figures[action], scale)
		cell_all = cell_all.max(built[action].cell)
	# All actions share one cell and anchor (ActorSprite uses one offset).
	anchor_all = Vector2i(cell_all.x / 2, 0)
	for action: String in built:
		anchor_all.y = maxi(anchor_all.y, built[action].anchor.y)
	var foot_room := 0
	for action: String in built:
		foot_room = maxi(foot_room, built[action].cell.y - built[action].anchor.y)
	cell_all.y = anchor_all.y + foot_room
	for action: String in built:
		var info := _write_sheet(out, actor, action, built[action], cell_all, anchor_all)
		manifest.actions[action] = info
	manifest.cell = [cell_all.x, cell_all.y]
	manifest.anchor = [anchor_all.x, anchor_all.y]
	_save_text(out + actor + ".json", JSON.stringify(manifest, " "))
	_save_text(out + actor + ".tres", _sprite_frames(manifest, out))
	_palette(ref_fig.image).save_png(ProjectSettings.globalize_path(out + "palette.png"))
	print("imported %s: %d actions, cell %s, scale %.3f -> %s" % [actor, built.size(), cell_all, scale, out])
	get_tree().quit()


## action -> dir -> sorted file paths
func _scan(src: String) -> Dictionary:
	var out := {}
	var root := DirAccess.open(src)
	if root == null:
		return out
	for action in root.get_directories():
		for d in DirAccess.get_directories_at(src + action):
			if not d in DIRS:
				continue
			var files: Array[String] = []
			for f in DirAccess.get_files_at(src + action + "/" + d):
				if f.to_lower().ends_with(".png"):
					files.append(src + action + "/" + d + "/" + f)
			files.sort()
			if files.size() > 0:
				out.get_or_add(action, {})[d] = files
	return out


func _split(path: String) -> Array[Image]:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	var base := path.get_file().get_basename()
	var n := 1
	var m := RegEx.create_from_string("_x(\\d+)$").search(base)
	if m:
		n = maxi(1, m.get_string(1).to_int())
	var out: Array[Image] = []
	var w := img.get_width() / n
	for i in n:
		out.append(img.get_region(Rect2i(i * w, 0, w, img.get_height())))
	return out


## Keys the background and trims to the figure. Returns {image, feet}: feet
## is the anchor inside the trimmed image (x: torso centre, y: lowest point).
func _figure(img: Image) -> Dictionary:
	if img.get_height() > WORK_HEIGHT:
		var k := float(WORK_HEIGHT) / img.get_height()
		img.resize(roundi(img.get_width() * k), WORK_HEIGHT, Image.INTERPOLATE_LANCZOS)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var magenta := minf(c.r, c.b) - c.g
			if magenta > 0.45:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif magenta > 0.15:
				# Edge pixel: fade it and remove the magenta spill.
				var a := 1.0 - (magenta - 0.15) / 0.3
				var spill := magenta * 0.9
				img.set_pixel(x, y, Color(c.r - spill, c.g, c.b - spill, a))
	var used := _opaque_rect(img)
	img = img.get_region(used)
	return {"image": img, "feet": _feet(img)}


func _opaque_rect(img: Image) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 1, 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Feet anchor: the lowest opaque row, and the horizontal centre of the
## torso band (35-65% down), which doesn't swing like arms and legs.
func _feet(img: Image) -> Vector2i:
	var h := img.get_height()
	var sum := 0.0
	var count := 0
	for y in range(int(h * 0.35), int(h * 0.65)):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				sum += x
				count += 1
	var cx := roundi(sum / count) if count > 0 else img.get_width() / 2
	return Vector2i(cx, h)


func _first_figure(figures: Dictionary, action: String, d: String) -> Dictionary:
	if figures.has(action) and figures[action].has(d):
		return figures[action][d][0]
	if figures.has(action):
		return figures[action].values()[0][0]
	return figures.values()[0].values()[0][0]


## Scales the frames and measures the action's cell around the feet anchor.
func _build_action(actor: String, action: String, dirs: Dictionary, scale: float) -> Dictionary:
	var frames := {}  # dir -> Array of {image, feet}
	var left := 0
	var right := 0
	var up := 0
	for d: String in dirs:
		var list: Array = []
		for fig: Dictionary in dirs[d]:
			var img: Image = (fig.image as Image).duplicate()
			img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
			var feet := Vector2i(roundi(fig.feet.x * scale), img.get_height())
			left = maxi(left, feet.x)
			right = maxi(right, img.get_width() - feet.x)
			up = maxi(up, feet.y)
			list.append({"image": img, "feet": feet})
		frames[d] = list
	var half := maxi(left, right) + PAD
	return {"frames": frames, "cell": Vector2i(half * 2, up + PAD * 2), "anchor": Vector2i(half, up + PAD),
		"sockets": _guide_sockets(actor, action, dirs.keys())}


## Hand points from the local pose guides, relative to the feet in canvas px.
func _guide_sockets(actor: String, action: String, dirs: Array) -> Dictionary:
	var out := {}
	var guide_action := String(_cfg.get("guides", {}).get(action, action))
	for d: String in dirs:
		var path := Assets.POSE_GUIDES + "%s/%s/%s/guide.json" % [actor, guide_action, d]
		if not FileAccess.file_exists(path):
			continue
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var list: Array = []
		for s: Dictionary in g.sockets:
			var k := SHEET_BODY / CANVAS_BODY
			list.append({"hand": [roundi((int(s.hand[0]) - int(g.feet[0])) * k), roundi((int(s.hand[1]) - int(g.feet[1])) * k)],
				"front": s.front} if s.has("hand") else {})
		out[d] = list
	return out


func _write_sheet(out: String, actor: String, action: String, built: Dictionary, cell: Vector2i, anchor: Vector2i) -> Dictionary:
	var frames: Dictionary = built.frames
	var dir_list: Array[String] = []
	for d in DIRS:
		if frames.has(d):
			dir_list.append(d)
	var cols := 0
	for d in dir_list:
		cols = maxi(cols, frames[d].size())
	var sheet := Image.create(cell.x * cols, cell.y * dir_list.size(), false, Image.FORMAT_RGBA8)
	var ms: int = int(_cfg.get("frame_ms", {}).get(action, DEFAULT_MS))
	var info := {"sheet": "%s_%s.png" % [actor, action], "dirs": {}}
	for r in dir_list.size():
		var d := dir_list[r]
		var entries: Array = []
		for c: int in frames[d].size():
			var f: Dictionary = frames[d][c]
			var at: Vector2i = Vector2i(c * cell.x, r * cell.y) + anchor - f.feet
			sheet.blend_rect(f.image, Rect2i(Vector2i.ZERO, f.image.get_size()), at)
			var entry := {"col": c, "row": r, "ms": ms}
			var sockets: Array = built.sockets.get(d, [])
			if c < sockets.size() and sockets[c].has("hand"):
				entry.hand = sockets[c].hand
				entry.front = sockets[c].front
			entries.append(entry)
		info.dirs[d] = entries
	sheet.save_png(ProjectSettings.globalize_path(out + info.sheet))
	return info


## The reference frame's main colours, most common first.
func _palette(img: Image) -> Image:
	var counts := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.9:
				continue
			var key := Vector3i(roundi(c.r * 15), roundi(c.g * 15), roundi(c.b * 15))
			counts[key] = counts.get(key, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return counts[a] > counts[b])
	var picked: Array[Color] = []
	for k: Vector3i in keys:
		var col := Color(k.x / 15.0, k.y / 15.0, k.z / 15.0)
		var distinct := true
		for p in picked:
			if Vector3(p.r - col.r, p.g - col.g, p.b - col.b).length() < 0.08:
				distinct = false
				break
		if distinct:
			picked.append(col)
		if picked.size() >= PALETTE_SIZE:
			break
	var pal := Image.create(PALETTE_SIZE, 1, false, Image.FORMAT_RGBA8)
	for i in picked.size():
		pal.set_pixel(i, 0, picked[i])
	return pal


func _sprite_frames(m: Dictionary, out: String) -> String:
	var cw: int = m.cell[0]
	var ch: int = m.cell[1]
	var ext: PackedStringArray = []
	var subs: PackedStringArray = []
	var anims: PackedStringArray = []
	var actions: Array = m.actions.keys()
	actions.sort()
	for i in actions.size():
		var act: String = actions[i]
		var info: Dictionary = m.actions[act]
		ext.append('[ext_resource type="Texture2D" path="%s%s" id="%d"]' % [out, info.sheet, i + 1])
		for d: String in info.dirs:
			var items: PackedStringArray = []
			for f: Dictionary in info.dirs[d]:
				var sid := "%s_%s_%d" % [act, d, f.col]
				subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%d")\nregion = Rect2(%d, %d, %d, %d)\n' % [sid, i + 1, int(f.col) * cw, int(f.row) * ch, cw, ch])
				items.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
			var ms: int = info.dirs[d][0].ms
			var loop := "false" if act in NO_LOOP or not bool(_cfg.get("loop", {}).get(act, true)) else "true"
			anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": %.3f\n}' % [", ".join(items), loop, act, d, 1000.0 / ms])
	return '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n[resource]\nanimations = [%s]\n' % [
		ext.size() + subs.size() + 1, "\n".join(ext), "\n".join(subs), ", ".join(anims)]


func _save_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
