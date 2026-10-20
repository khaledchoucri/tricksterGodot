extends Node
## Casts every attack of a class line at a few monsters and saves a frame of
## each just after it goes off (spells: after their cast time), plus a card
## pick with an upgrade offer and, for mages, a frame mid-cast. Needs a window:
##   godot res://tests/skill_shots.tscn -- out=C:/some/folder [class=bunny|sheep|dragon|cat|raccoon]

var out := "user://skill_shots"
var game


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Profile.use_path("user://skill_shots_profile.json", true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("class="):
			Profile.class_id = a.substr(6)
	_shoot.call_deferred()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout


func _snap(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("saved ", file)


func _shoot() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(3.0)
	var p: Player = game.player
	for e in game.room.enemies:
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await _wait(1.6)
	var line := "magic" if Run.cls.basic_skill else "charm" if Run.cls.id in [&"cat", &"raccoon"] else "power"
	var ids: Array[StringName] = []
	for c in Run.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/%s/" % line):
			ids.append(c.id)
	var home: Vector2 = game.room.random_spot(Vector2.ZERO, 0.0)
	for _i in 200:
		var spot: Vector2 = game.room.random_spot(Vector2.ZERO, 0.0)
		if game.room.is_open_spot(spot + Vector2(120, 0)) and game.room.is_open_spot(spot + Vector2(70, 40)):
			home = spot
			break
	var dummies: Array[Enemy] = []
	for off in [Vector2(55, 10), Vector2(95, -25), Vector2(80, 45)]:
		var e: Enemy = game.room.spawn(&"torobbie", home + off)
		dummies.append(e)
	await _wait(0.8)
	for i in ids.size():
		var id := ids[i]
		p.global_position = home
		p.enter(Player.State.MOVE)
		p.invulnerable_until = p.now() + 999.0
		p.aim = Vector2.RIGHT
		for k in dummies.size():
			if is_instance_valid(dummies[k]):
				dummies[k].max_hp = 99999
				dummies[k].hp = 99999
				dummies[k].global_position = home + [Vector2(55, 10), Vector2(95, -25), Vector2(80, 45)][k]
		Run.cards[id] = 3
		Run.loadout[0] = id
		p.end_instinct()
		Run.form = &""
		# The Charm line's conditions: Galder in the purse, the beast form a
		# beast skill needs, full HP for Mass Destruction.
		Run.galder = 999
		Run.hp = Run.max_hp
		if SkillCaster.FORM_NEEDED.has(id) or id == &"beasts_instinct":
			var need: StringName = SkillCaster.FORM_NEEDED.get(id, &"evolution")
			need = need if need != &"" else &"metamorphosis"
			Run.cards[need] = 3
			Run.add_card(need)
			p.become_beast()
			await _wait(0.3)
		Run.mp = Run.max_mp
		p.skills.slot_ready_at[0] = 0.0
		p.skills.try_cast(0)
		var cast_time := Run.card(id).cast_at(3)
		if i == 0 and cast_time > 0.0:
			await _wait(cast_time * 0.6)
			await _snap("00_casting")
			await _wait(cast_time * 0.4)
		else:
			await _wait(cast_time)
		if Run.is_basic(id):
			await _wait(0.06)
			await _snap("%02d_%s_flight" % [i, id])  # the projectile on its way
			await _wait(0.14)
		else:
			await _wait(0.2)
		await _snap("%02d_%s" % [i, id])
		await _wait(1.0)
	# A pick offering an upgrade.
	if line == "magic":
		Run.cards = {&"water_shield": 3, Run.cls.basic_skill.id: 1}
		game._start_pick("card", [Run.card(&"undines_blessing"), Run.card(&"seal_of_fire"), Run.card(&"mist_of_mana")])
	else:
		Run.cards = {&"lacerator": 3}
		Run.loadout.assign([&"lacerator", &"", &""])
		game._start_pick("card", [Run.card(&"tempest_strike"), Run.card(&"tidal_slash"), Run.card(&"pumping_heart")])
	await _wait(0.3)
	await _snap("90_upgrade_pick")
	get_tree().quit()
