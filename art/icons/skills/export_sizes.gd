extends SceneTree
## Technical size export only. Raw imagegen sources remain unchanged.
## Run: godot --headless --path . --script res://art/icons/skills/export_sizes.gd

const SOURCES := {
	"lacerator": "lacerator_01.png",
	"piercing_wave": "piercing_wave_02.png",
	"inferno_blade": "inferno_blade_01.png",
	"lightning_strike": "lightning_strike_01.png",
	"upper_smash": "upper_smash_01.png",
	"shockwave": "shockwave_01.png",
	"tornado_bomb": "tornado_bomb_01.png",
}

func _initialize() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	for id: String in SOURCES:
		var source := folder.path_join("sources").path_join(SOURCES[id])
		var image := Image.load_from_file(ProjectSettings.globalize_path(source))
		if image == null or image.is_empty():
			printerr("Could not read ", source)
			quit(1)
			return
		if image.get_width() != image.get_height():
			printerr("Expected square source: ", source)
			quit(1)
			return
		image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		var result := image.save_png(ProjectSettings.globalize_path(folder.path_join(id + ".png")))
		if result != OK:
			printerr("Could not export ", id, ": ", error_string(result))
			quit(1)
			return
		print("EXPORTED ", id, " 512x512 RGB")
	quit(0)
