extends Node
## Saves screenshots of the run UI for review: level-up types, gear, the
## anvil, the character sheet, and combat with a hammer. Needs a window
## (not --headless):
##   godot res://tests/screenshots.tscn -- out=C:/some/folder

var out := "user://screenshots"
var game


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Profile.use_path("user://screenshot_profile.json", true)
	_shoot.call_deferred()


func _snap(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("saved ", file)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout


func _shoot() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(3.0)
	var player: Player = game.player
	Run.equip(GearItem.roll(load("res://data/items/pretty_hammer.tres"), 0.8))
	Run.equip(GearItem.roll(load("res://data/items/wood_helmet.tres"), 0.8))
	Run.equip(GearItem.roll(load("res://data/items/lucky_amulet.tres"), 0.8))
	while Run.type_points.power < 6:
		Run.apply_type("power")
	Run.apply_type("sense")
	player.refresh_gear()
	for e in game.room.enemies:
		e.global_position = player.global_position + Vector2(60, 20)
	player.aim = Vector2(1, 0.3).normalized()
	player.attack.start(0)
	await _wait(0.12)
	await _snap("01_hammer_swing")
	player.attack.start(2)
	await _wait(0.28)
	await _snap("02_hammer_finisher")
	game.hud.sheet.toggle()
	await _wait(0.2)
	await _snap("03_character_sheet")
	game.hud.sheet.toggle()
	game._start_pick("type", Stats.TYPE_ORDER.duplicate())
	await _wait(0.3)
	await _snap("04_type_pick")
	game.hud._on_pick(0)
	game._start_pick("gear", Run.gear_offers(2))
	await _wait(0.3)
	await _snap("05_gear_pick")
	game.hud.pick_panel.visible = false
	get_tree().paused = false
	Run.ore = 6
	Run.galder = 500
	game._open_anvil()
	await _wait(0.3)
	await _snap("06_anvil")
	game.hud.pick_panel.visible = false
	get_tree().paused = false
	game._start_pick("job", Run.job.next_jobs.duplicate())
	await _wait(0.3)
	await _snap("07_job_change")
	get_tree().quit()
