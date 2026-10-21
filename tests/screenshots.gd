extends Node
## Saves screenshots of the run UI for review: level-up types, gear, the
## anvil, the character sheet, and combat with a hammer. Needs a window
## (not --headless):
##   godot res://tests/screenshots.tscn -- out=C:/some/folder

var out := "user://screenshots"
var game: Game


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)  # the shipped window, not headless 1280x1280
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
		for e: Enemy in game.room.enemies:
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
	if "sheet" in OS.get_cmdline_user_args():
		await _shoot_sheet()
		get_tree().quit()
		return
	if "rest" in OS.get_cmdline_user_args():
		await _shoot_rest()
		get_tree().quit()
		return
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(3.0)
	var player: Player = game.player
	Run.gear.equip(GearItem.roll(load("res://data/items/pretty_hammer.tres"), 0.8))
	Run.gear.equip(GearItem.roll(load("res://data/items/wood_helmet.tres"), 0.8))
	Run.gear.equip(GearItem.roll(load("res://data/items/lucky_amulet.tres"), 0.8))
	while Run.type_points.power < 6:
		Run.apply_type("power")
	Run.apply_type("sense")
	player.refresh_gear()
	for e: Enemy in game.room.enemies:
		e.global_position = player.global_position + Vector2(60, 20)
	player.aim = Vector2(1, 0.3).normalized()
	Run.gear.equip(GearItem.make(load("res://data/items/marky_tricorn.tres")), "hat")
	Run.gear.equip(GearItem.make(load("res://data/items/teddy_bear_shield.tres")), "shield")
	Run.start_job(load("res://data/jobs/knight.tres"))
	player.refresh_gear()
	await _wait(0.3)
	await _snap("00_knight_dressed")
	player.attack.start(0)
	await _wait(0.12)
	await _snap("01_hammer_swing")
	var last: int = player.combo_steps().size() - 1
	player.attack.start(last)
	var fin: ComboStep = player.combo_steps()[last]
	await _wait(fin.windows[0].x / Run.formulas.attack_speed_mult() + 0.03)
	await _snap("02_hammer_finisher")
	game.hud.sheet.toggle()
	await _wait(0.2)
	await _snap("03_character_sheet")
	game.hud.sheet.toggle()
	game._start_pick("type", Stats.TYPE_ORDER.duplicate())
	await _wait(0.3)
	await _snap("04_type_pick")
	game.hud._on_pick(0)
	game._start_pick("gear", Run.gear.gear_offers(2))
	await _wait(0.3)
	await _snap("05_gear_pick")
	game.hud.pick_panel.visible = false
	get_tree().paused = false
	Run.purse.ore = 6
	Run.purse.galder = 500
	game._open_anvil()
	await _wait(0.3)
	await _snap("06_anvil")
	game.hud.pick_panel.visible = false
	get_tree().paused = false
	for path in DirAccess.get_files_at("res://data/materials"):
		var m: MaterialData = load("res://data/materials/" + path.trim_suffix(".remap"))
		Run.purse.material_info[m.id] = m
		Run.purse.materials[m.id] = m.need + 1
	game._open_compounder()
	await _wait(0.3)
	await _snap("06b_compounder_full")
	game.hud.pick_panel.visible = false
	get_tree().paused = false
	game._start_pick("job", Run.job.next_jobs.duplicate())
	await _wait(0.3)
	await _snap("07_job_change")
	game.hud.pick_panel.visible = false
	Profile.restorations["drill_shop"] = 1
	game.hud.drill.start(Run.purse.drill(), 0.02)
	await _wait(0.7)
	game.hud.drill._strike()
	await _wait(0.4)
	await _snap("08_drill")
	get_tree().quit()


func _shoot_hub() -> void:
	Profile.set_flag("met_cavalier")
	for r: RestorationData in Run.hub.restorations:
		Profile.restorations[String(r.id)] = r.max_level
	for m: StringName in [&"torobbie", &"tottochi", &"little_cora", &"blue_penguin", &"fanta_slime"]:
		Profile.add_card(m)
	Profile.tm = 9000
	Run.new_run()
	var sword := GearItem.make(load("res://data/items/wood_sword.tres"))
	sword.refine = 4
	Run.city.save_point(sword)
	var hub: Hub = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await _wait(1.5)
	var julio: Npc = hub.talker.npc(&"julio")
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
	var eugene: Npc = hub.talker.npc(&"eugene")
	hub.talker.talking = false
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


## The character sheet with its equipment window, opened with the character key, wearing a
## few pieces so the slots show items.
func _shoot_sheet() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(2.5)
	for id: String in ["candy_hat", "candy_shield", "might_ring", "golden_mole_vest"]:
		Run.gear.equip(GearItem.roll(load("res://data/items/%s.tres" % id), 0.5))
	game.player.dress()
	_press("character")
	await _wait(0.8)
	await _snap("44_equipment_window")
	_press("character")
	await _wait(0.3)


## Each rest stop as a player meets it: arriving, walking up to Julio, pressing the talk
## key, and paging through his conversation into the shelves.
func _shoot_rest() -> void:
	for r: RestorationData in Run.hub.restorations:
		if r.effect == "system":
			Profile.restorations[String(r.id)] = 1
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(2.0)
	var n := 0
	for d: int in Run.route.plan.size():
		if not Run.route.plan[d].rest:
			continue
		Run.hp = int(Run.max_hp * 0.2)
		Run.route.depth = d
		game._load_room()
		await _wait(3.0)
		await _snap("40_rest_%d_arrive" % n)
		var stop: RestStop = null
		for c in game.room.get_children():
			if c is RestStop:
				stop = c
		var julio := stop.talker.npc(&"julio") if stop else null
		if julio:
			game.player.global_position = game.room.nearest_reachable(julio.global_position + Vector2(24, 20))
			await _wait(0.5)
			await _snap("41_rest_%d_prompt" % n)
			for i in 8:
				_press("interact")
				await _wait(0.6)
				if i == 1:
					await _snap("42_rest_%d_talk" % n)
			await _snap("43_rest_%d_shelves" % n)
			_press("ui_cancel")
			await _wait(0.5)
		n += 1


## A real press and release of an input action, as the keyboard sends it.
func _press(action: String) -> void:
	for down: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame


func _shoot_desert() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(2.0)
	var desert := Run.route.plan.find_custom(func(p: RoomPlan) -> bool: return p.region == Run.route.regions[1] and p.local_depth == 0)
	for depth: int in [desert, desert + 4, Run.route.plan.size() - 1]:
		Run.route.depth = depth
		game._load_room()
		await _wait(3.5)
		if is_instance_valid(game.player):
			game.player.invulnerable_until = game.player.now() + 999.0
		await _wait(1.5)
		await _snap("20_desert_%d" % depth)
		if depth == desert:
			for i in Run.echoes.size():
				game.room.spawn(Run.echoes[i].id, game.player.global_position + Vector2(-120 + 120 * i, -60))
			Run.deck.take_rune(Run.echoes[0].runes[0])
			await _wait(1.0)
			await _snap("21_echoes")
