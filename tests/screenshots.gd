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
	if "hub" in OS.get_cmdline_user_args():
		await _shoot_hub()
		get_tree().quit()
		return
	if "bunny" in OS.get_cmdline_user_args():
		Profile.stats["clears"] = 1
		Profile.class_id = "bunny"
		game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		await _wait(3.0)
		for e in game.room.enemies:
			e.global_position = game.player.global_position + Vector2(50, 15)
		game.player.aim = Vector2(1, 0.3).normalized()
		game.player.attack.start(2)
		await _wait(0.12)
		await _snap("30_bunny_punch")
		get_tree().quit()
		return
	if "desert" in OS.get_cmdline_user_args():
		await _shoot_desert()
		get_tree().quit()
		return
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


func _shoot_hub() -> void:
	Profile.set_flag("met_cavalier")
	for r: RestorationData in Run.hub.restorations:
		Profile.restorations[String(r.id)] = r.max_level
	for m in [&"torobbie", &"tottochi", &"little_cora", &"blue_penguin", &"fanta_slime"]:
		Profile.add_card(m)
	Profile.tm = 9000
	Run.new_run()
	var sword := GearItem.make(load("res://data/items/wood_sword.tres"))
	sword.refine = 4
	Run.save_point(sword)
	var hub = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await _wait(1.5)
	var julio: Npc = hub._npc(&"julio")
	hub.player.global_position = julio.global_position + Vector2(-40, 30)
	await _wait(0.5)
	await _snap("10_hub_julio")
	hub.talk(julio)
	for _i in 12:
		await _wait(0.15)
		hub.dialogue._typing = false
		if hub.dialogue._scroll.visible:
			break
		hub.dialogue._advanced.emit()
	await _wait(0.4)
	await _snap("11_warehouse_menu")
	hub.dialogue._chosen.emit(hub.dialogue._choices.get_child_count() - 1)
	await _wait(0.5)
	var eugene: Npc = hub._npc(&"eugene")
	hub.talking = false
	hub.player.global_position = eugene.global_position + Vector2(-40, 30)
	hub.talk(eugene)
	for _i in 12:
		await _wait(0.15)
		hub.dialogue._typing = false
		if hub.dialogue._scroll.visible:
			break
		hub.dialogue._advanced.emit()
	await _wait(0.4)
	hub.dialogue._chosen.emit(0)
	await _wait(0.5)
	await _snap("12_card_album")


func _shoot_desert() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(2.0)
	for depth in [Run.regions[0].run_length + 1, Run.regions[0].run_length + 5, Run.plan.size() - 1]:
		Run.depth = depth
		game._load_room()
		await _wait(3.5)
		if is_instance_valid(game.player):
			game.player.invulnerable_until = game.player.now() + 999.0
		await _wait(1.5)
		await _snap("20_desert_%d" % depth)
		if depth == Run.regions[0].run_length + 1:
			for i in Run.echoes.size():
				game.room.spawn(Run.echoes[i].id, game.player.global_position + Vector2(-120 + 120 * i, -60))
			Run.take_rune(Run.echoes[0].runes[0])
			await _wait(1.0)
			await _snap("21_echoes")
