extends Node
## Casts every attack of a class line at a few monsters and saves a frame of
## each just after it goes off (spells: after their cast time), plus a card
## pick with an upgrade offer and, for mages, a frame mid-cast. Needs a window:
##   godot res://tests/skill_shots.tscn -- out=C:/some/folder [class=bunny|sheep|dragon|cat|raccoon]
## To look at a few skills over time: only=one_pair,full_house (just these),
## frames=8 (a frame every 0.08 s from the cast), far=1 (the monsters 2.5x as
## far), with=lady_luck (cards held at Lv 5 alongside).

var out := "user://skill_shots"
var game: Game
var _only: PackedStringArray = []
var _with: PackedStringArray = []
var _frames := 0
var _far := 1.0


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("only="):
			_only = a.substr(5).split(",")
		elif a.begins_with("with="):
			_with = a.substr(5).split(",")
		elif a.begins_with("frames="):
			_frames = int(a.substr(7))
		elif a.begins_with("far="):
			_far = 2.5 if a.substr(4) == "1" else 1.0
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
	for e: Enemy in game.room.enemies:
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await _wait(1.6)
	var line := "magic" if Run.cls.basic_skill else "charm" if Run.cls.id in [&"cat", &"raccoon"] else "power"
	var ids: Array[StringName] = []
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/%s/" % line) and (_only.is_empty() or String(c.id) in _only):
			ids.append(c.id)
	var home: Vector2 = game.room.random_spot(Vector2.ZERO, 0.0)
	for _i in 200:
		var spot: Vector2 = game.room.random_spot(Vector2.ZERO, 0.0)
		if game.room.is_open_spot(spot + Vector2(120, 0)) and game.room.is_open_spot(spot + Vector2(70, 40)):
			home = spot
			break
	var dummies: Array[Enemy] = []
	var offsets: Array[Vector2] = []
	for off: Vector2 in [Vector2(55, 10), Vector2(95, -25), Vector2(80, 45)]:
		offsets.append(off * _far)
	for off: Vector2 in offsets:
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
				dummies[k].global_position = home + offsets[k]
		Run.deck.cards[id] = 3
		for w: String in _with:
			Run.deck.cards[StringName(w)] = 5
		Run.deck.loadout[0] = id
		p.end_instinct()
		Run.form = &""
		# The Charm line's conditions: Galder in the purse, the beast form a
		# beast skill needs, full HP for Mass Destruction.
		Run.purse.galder = 999
		Run.hp = Run.max_hp
		if Run.deck.card(id).form != &"":
			var need: StringName = Run.deck.card(id).form
			need = need if need != &"beast" else &"metamorphosis"
			Run.deck.cards[need] = 3
			Run.deck.add_card(need)
			p.become_beast()
			await _wait(0.3)
		for e: Enemy in game.room.enemies.duplicate():
			if not e in dummies:  # a straggler would take the hits meant for the dummies
				game.room.enemies.erase(e)
				e.queue_free()
		Run.mp = Run.max_mp
		p.skills.slot_ready_at[0] = 0.0
		p.skills.try_cast(0)
		var cast_time := Run.deck.card(id).cast_at(3)
		if i == 0 and cast_time > 0.0:
			await _wait(cast_time * 0.6)
			await _snap("00_casting")
			await _wait(cast_time * 0.4)
		else:
			await _wait(cast_time)
		if _frames > 0:
			for f in _frames:
				await _snap("%02d_%s_%02d" % [i, id, f])
				await _wait(0.08)
			await _wait(1.0)
			continue
		if Run.deck.is_basic(id):
			await _wait(0.06)
			await _snap("%02d_%s_flight" % [i, id])  # the projectile on its way
			await _wait(0.14)
		else:
			await _wait(0.2)
		await _snap("%02d_%s" % [i, id])
		await _wait(1.0)
	# A pick offering an upgrade.
	if line == "magic":
		Run.deck.cards = {&"water_shield": 3, Run.cls.basic_skill.id: 1}
		game._start_pick("card", [Run.deck.card(&"undines_blessing"), Run.deck.card(&"seal_of_fire"), Run.deck.card(&"mist_of_mana")])
	else:
		Run.deck.cards = {&"lacerator": 3}
		Run.deck.loadout.assign([&"lacerator", &"", &""])
		game._start_pick("card", [Run.deck.card(&"tempest_strike"), Run.deck.card(&"tidal_slash"), Run.deck.card(&"pumping_heart")])
	await _wait(0.3)
	await _snap("90_upgrade_pick")
	get_tree().quit()
