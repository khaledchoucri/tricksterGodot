extends Node
## Exports grey pose guides for AI frame generation from an exported actor:
## every frame becomes a flat grey figure (pose, depth and limb order kept,
## the original design dropped) on a 512 x 512 canvas with the feet at
## (256, 420) and the body scaled to about 320 px. Also writes 4-frame strips
## for multi-frame generation, contact sheets, and the frames' hand points
## scaled to the canvas.
##
## Output goes to the git-ignored original_assets/pose_guides/<actor>/: these
## are derived from the original game's sprites and must stay local.
##
## Run: godot --headless --path . res://scenes/tools/pose_guides.tscn -- [actor] [actions]
##   actor defaults to buffalo; actions is a comma list (default: all).

const CANVAS := 512
const FEET := Vector2i(256, 420)
const BODY_HEIGHT := 320.0
const LEVELS := 3          # grey levels kept from the original shading
const BACKGROUND := Color(1, 0, 1)  # magenta, like the generated art


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var actor := args[0] if args.size() > 0 else "buffalo"
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	var src := "res://original_assets/actors/%s/" % actor
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + actor + ".json"))
	var cell := Vector2i(manifest.cell[0], manifest.cell[1])
	var anchor := Vector2i(manifest.anchor[0], manifest.anchor[1])
	var scale := BODY_HEIGHT / _body_height(src, manifest, cell, anchor)
	var out := ProjectSettings.globalize_path("res://original_assets/pose_guides/%s/" % actor)
	var count := 0
	for action: String in manifest.actions:
		if only.size() > 0 and not action in only:
			continue
		var info: Dictionary = manifest.actions[action]
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(src + info.sheet))
		sheet.convert(Image.FORMAT_RGBA8)
		for d: String in info.dirs:
			var dir_path := out + "%s/%s/" % [action, d]
			DirAccess.make_dir_recursive_absolute(dir_path)
			var frames: Array[Image] = []
			var sockets: Array = []
			for i in info.dirs[d].size():
				var f: Dictionary = info.dirs[d][i]
				var raw := sheet.get_region(Rect2i(int(f.col) * cell.x, int(f.row) * cell.y, cell.x, cell.y))
				var guide := _guide(raw, anchor, scale)
				guide.save_png(dir_path + "frame_%02d.png" % i)
				frames.append(guide)
				if f.has("hand"):
					var hand := Vector2(FEET) + Vector2(f.hand[0], f.hand[1]) * scale
					sockets.append({"frame": i, "hand": [roundi(hand.x), roundi(hand.y)], "front": f.front})
				else:
					sockets.append({"frame": i})
				count += 1
			_contact(frames).save_png(dir_path + "contact.png")
			for s in range(0, frames.size(), 4):
				_contact(frames.slice(s, s + 4)).save_png(dir_path + "strip_%02d-%02d.png" % [s, mini(s + 3, frames.size() - 1)])
			var meta := {"actor": actor, "action": action, "dir": d, "canvas": CANVAS, "feet": [FEET.x, FEET.y],
				"scale": scale, "frame_ms": info.dirs[d].map(func(f: Dictionary) -> int: return int(f.ms)),
				"sockets": sockets}
			var file := FileAccess.open(dir_path + "guide.json", FileAccess.WRITE)
			file.store_string(JSON.stringify(meta, "  "))
	print("pose guides: %d frames, scale %.2f, in %s" % [count, scale, out])
	get_tree().quit()


## Feet-to-crown height of the neutral pose (idle facing se), in source pixels.
func _body_height(src: String, manifest: Dictionary, cell: Vector2i, anchor: Vector2i) -> float:
	var info: Dictionary = manifest.actions.get("idle", manifest.actions.values()[0])
	var d: String = "se" if info.dirs.has("se") else info.dirs.keys()[0]
	var f: Dictionary = info.dirs[d][0]
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(src + info.sheet))
	var used := sheet.get_region(Rect2i(int(f.col) * cell.x, int(f.row) * cell.y, cell.x, cell.y)).get_used_rect()
	return float(anchor.y - used.position.y)


func _guide(raw: Image, anchor: Vector2i, scale: float) -> Image:
	# Blur away small details (faces, patterns) so only pose and broad
	# light/shadow masses remain.
	var soft := raw.duplicate() as Image
	soft.resize(raw.get_width() / 3, raw.get_height() / 3, Image.INTERPOLATE_BILINEAR)
	soft.resize(raw.get_width(), raw.get_height(), Image.INTERPOLATE_BILINEAR)
	var grey := Image.create(raw.get_width(), raw.get_height(), false, Image.FORMAT_RGBA8)
	for y in raw.get_height():
		for x in raw.get_width():
			var c := soft.get_pixel(x, y)
			if raw.get_pixel(x, y).a < 0.5:
				continue
			var level := floorf(c.get_luminance() / maxf(c.a, 0.01) * LEVELS) / (LEVELS - 1)
			var v := 0.22 + 0.6 * clampf(level, 0.0, 1.0)
			grey.set_pixel(x, y, Color(v, v, v * 1.02, 1.0))
	grey.resize(roundi(raw.get_width() * scale), roundi(raw.get_height() * scale), Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	canvas.fill(BACKGROUND)
	var at := FEET - Vector2i(roundi(anchor.x * scale), roundi(anchor.y * scale))
	canvas.blend_rect(grey, Rect2i(Vector2i.ZERO, grey.get_size()), at)
	return canvas


func _contact(frames: Array[Image]) -> Image:
	var sheet := Image.create(CANVAS * frames.size(), CANVAS, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, CANVAS, CANVAS), Vector2i(i * CANVAS, 0))
	return sheet
