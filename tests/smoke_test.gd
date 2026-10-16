extends Node
## Headless smoke test for a Coral Beach run.
## Run: godot --headless --path . res://tests/smoke_test.tscn

var failures := 0
var game


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func run_state() -> Node:
	return get_node("/root/Run")


func _ready() -> void:
	_run.call_deferred()


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e.is_hittable())


func clear_room() -> void:
	for _i in 60:
		if game.phase != game.Phase.FIGHT:
			return
		for e in enemies():
			e.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.5)


func _run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	var Run := run_state()
	await wait(2.6)

	var room: Room = game.room
	check(room != null and room.world != null, "first room builds from %s" % (room.data.map if room else "?"))
	check(room.is_walkable(game.player.global_position), "player starts on walkable ground")
	check(room.get_child_count() > 3 and room.world.get_child_count() > 1, "room has ground, props and the player")
	await wait(1.5)
	check(enemies().size() > 0, "wave 1 spawns (%d enemies)" % enemies().size())

	# Punch an enemy placed in front of the player.
	var player: Player = game.player
	var target: Enemy = enemies()[0]
	var hp_before := target.hp
	target.global_position = player.global_position + Vector2(30, 6)
	for _i in 2:
		player.aim = Combat.ground(target.global_position - player.global_position).normalized()
		player._start_attack(0)
		for _f in 20:
			player.aim = Combat.ground(target.global_position - player.global_position).normalized()
			await get_tree().physics_frame
	check(target.hp < hp_before, "punch damages %s (%d -> %d)" % [target.data.id, hp_before, target.hp])

	# Pathfinding returns a route between two walkable points.
	var a := room.random_spot(Vector2.ZERO, 0.0)
	var b := room.random_spot(a, 300.0)
	check(room.find_path(a, b).size() > 1, "grid pathfinding finds a route across the room")

	# Every active skill casts and damages a monster in front of Buffalo.
	check(Run.loadout[0] == Run.STARTER_SKILL, "the run starts with %s in slot 1" % Run.STARTER_SKILL)
	var skill_ids: Array[StringName] = []
	for card in Run.region.cards:
		if card.is_skill():
			skill_ids.append(card.id)
	for id in skill_ids:
		# Ranges are on the ground plane; place the dummy at a ground distance.
		var reach := 55.0 if id in [&"lacerator", &"shockwave"] else 110.0
		var spot := Vector2.INF
		var ground_dir := Vector2.ZERO
		for _i in 300:
			var p := room.random_spot(Vector2.ZERO, 0.0)
			var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
			if room.line_clear(p, p + Combat.screen(d) * 130.0) and room.is_open_spot(p + Combat.screen(d) * reach):
				spot = p
				ground_dir = d
				break
		var at := spot + Combat.screen(ground_dir) * reach
		player.global_position = spot
		player._enter(Player.State.MOVE)
		var dummy: Enemy = room.spawn(&"torobbie", at)
		await wait(0.6)
		var before := dummy.hp
		Run.cards[id] = 1
		Run.loadout[0] = id
		Run.mp = Run.MAX_MP
		Run.hp = Run.max_hp
		player.slot_ready_at[0] = 0.0
		player.aim = ground_dir
		var cast := player._try_cast(0)
		for _f in 90:
			if is_instance_valid(dummy):
				dummy.global_position = at
			await get_tree().physics_frame
		check(cast and dummy.hp < before, "%s casts and damages a monster (%d -> %d)" % [id, before, dummy.hp])
		if dummy.is_hittable():
			dummy.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.3)
	Run.cards = {Run.STARTER_SKILL: 1}
	Run.loadout.assign([Run.STARTER_SKILL, &"piercing_wave", &"shockwave"])
	Run.cards[&"piercing_wave"] = 2
	Run.cards[&"shockwave"] = 1
	Run.add_card(&"tornado_bomb", 1)
	check(Run.loadout[1] == &"tornado_bomb" and Run.card_level(&"piercing_wave") == 0,
		"a new skill can replace a slotted one")
	Run.loadout.assign([Run.STARTER_SKILL, &"", &""])
	Run.cards = {Run.STARTER_SKILL: 1}
	Run.pending_levels = 0  # the dummies' EXP shouldn't queue level-ups for the checks below
	Run.xp = 0

	# Scenery in front of the player fades and the silhouette shows.
	var behind := Vector2.INF
	for prop in room.props:
		for dy in [10.0, 20.0, 30.0]:
			var feet := prop.position - Vector2(0, dy)
			if room.is_walkable(feet) and prop.hides(feet + Vector2(0, -26), feet.y):
				behind = feet
				break
		if behind != Vector2.INF:
			break
	if behind != Vector2.INF:
		player.global_position = behind
		for _f in 3:
			await get_tree().physics_frame
		var faded := room.props.any(func(p: Prop) -> bool: return p.target_alpha < 1.0)
		check(faded and player.silhouette.visible, "props hiding the player fade and the silhouette shows")
	else:
		print("SKIP  no prop to hide behind in this room")

	# A dash vaults an obstacle when there's open ground past it.
	var vault_from := Vector2.INF
	var vault_dir := Vector2.ZERO
	for _i in 400:
		var p := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		if room.vault_distance(p, d, player.dash_distance, player.vault_extra) > 0.0:
			vault_from = p
			vault_dir = d
			break
	if vault_from != Vector2.INF:
		player.global_position = vault_from
		player._enter(Player.State.MOVE)
		player.dash_ready_at = 0.0
		Input.action_press("dash")
		player._buffered = "dash"
		player._buffered_at = player.now()
		player.aim = Combat.ground(vault_dir).normalized()
		await get_tree().physics_frame
		Input.action_release("dash")
		await wait(0.5)
		var moved := (player.global_position - vault_from).dot(vault_dir)
		check(moved > 40.0 and room.is_walkable(player.global_position),
			"dash vaults an obstacle and lands on open ground (%.0f px)" % moved)
	else:
		print("SKIP  no vaultable obstacle found in this room")

	# Levels earned in combat are chosen after the room reward.
	Run.gain_exp(Run.exp_to_next())
	check(Run.pending_levels == 1, "gaining EXP queues a level-up")

	await clear_room()
	await wait(1.0)
	check(game.hud.pick_panel.visible and game._pick_kind == "card", "clearing room 1 offers a skill card")
	var card_id: StringName = game._pick_options[0].id
	game.hud._on_pick(0)
	check(Run.card_level(card_id) == 1, "picking adds %s at level 1" % card_id)
	await wait(0.2)
	check(game.hud.pick_panel.visible and game._pick_kind == "stat", "the queued level-up offers stats next")
	game.hud._on_pick(0)
	await wait(0.4)
	check(room.doors.size() == 2, "two exit doors open (%d)" % room.doors.size())

	# Walk through a door into the next room.
	var door: Door = room.doors[0]
	await wait(0.7)
	game.player.global_position = door.global_position
	await wait(2.6)
	check(Run.depth == 1 and game.room != room, "entering a door loads room 2 (%s)" % game.room.data.id)

	# Clione's shot travels and hurts the player.
	await wait(1.0)
	for e in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	var clione: Enemy = game.room.spawn("clione", game.room.random_spot(game.player.global_position, 150.0))
	await wait(0.7)
	# Somewhere in range with a clear line of fire.
	var me: Vector2 = game.player.global_position
	for _i in 300:
		var p: Vector2 = game.room.random_spot(me, 160.0)
		if Combat.ground(p - me).length() < 240.0 and game.room.line_clear(p, me):
			clione.global_position = p
			break
	var hp_start: int = Run.hp
	var saw_shot := false
	for _f in 400:
		if get_tree().get_nodes_in_group("projectiles").size() > 0 or game.room.world.get_children().any(func(n): return n is Projectile):
			saw_shot = true
		await get_tree().physics_frame
		if Run.hp < hp_start:
			break
	check(saw_shot, "Clione fires a projectile")
	check(Run.hp < hp_start, "enemy attacks hurt the player (%d -> %d)" % [hp_start, Run.hp])

	# Jump to the boss room.
	await clear_room()
	Run.depth = Run.plan.size() - 1
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	game._load_room()
	await wait(3.0)
	var boss: Enemy = null
	for e in enemies():
		if e.is_boss:
			boss = e
	check(boss != null and game.room.data.map == "map_dg11b", "boss room loads the Dark Cave with the Golden Mole")
	if boss:
		boss.take_hit(int(boss.max_hp * 0.36), Vector2.RIGHT, 0.0, true)
		await wait(1.3)
		check(enemies().size() >= 3, "boss summons Torobbies below 66%% HP (%d enemies)" % enemies().size())

	# Death shows the rollback results.
	Run.hp = 1
	game.player.invulnerable_until = 0.0
	game.player.take_hit(50, Vector2.RIGHT, 0.0)
	await wait(2.6)
	check(game.hud.results_panel.visible and game.phase == game.Phase.DEAD, "dying shows the rollback results")

	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures else 0)
