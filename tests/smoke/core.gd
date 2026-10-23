extends SmokeSection
## The first room: it builds, a wave spawns, a punch lands, pathfinding works; then fading props,
## vaulting, the room reward, gear, the anvil, level-ups, a door and a monster's shot.


## The first room builds, a wave spawns, a punch lands, and pathfinding works.
func first_room() -> void:
	var idle: SmokeSection = preload("res://tests/smoke/idle_slow.gd").new()
	idle.runner = runner
	add_child(idle)
	idle.run()
	idle.free()
	var Run := run_state()
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
		player.attack.start(0)
		for _f in 20:
			player.aim = Combat.ground(target.global_position - player.global_position).normalized()
			await get_tree().physics_frame
	check(target.hp < hp_before, "punch damages %s (%d -> %d)" % [target.data.id, hp_before, target.hp])

	# Pathfinding returns a route between two walkable points.
	var a := room.random_spot(Vector2.ZERO, 0.0)
	var b := room.random_spot(a, 300.0)
	check(room.find_path(a, b).size() > 1, "grid pathfinding finds a route across the room")


## Fading props, vaulting, the room reward, gear, the anvil, level-ups, a door, and a monster's shot.
func rewards() -> void:
	var Run := run_state()
	var room: Room = game.room
	var player: Player = game.player
	# Scenery in front of the player fades and the silhouette shows.
	var behind := Vector2.INF
	for prop in room.props:
		for dy: float in [10.0, 20.0, 30.0]:
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
		player.enter(Player.State.MOVE)
		player.dash_ready_at = 0.0
		Input.action_press("dash")
		player.buffer_action("dash")
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
	game._steps.append_array(["gear", "anvil"])
	game.hud._on_pick(0)
	check(Run.deck.card_level(card_id) == 1, "picking adds %s at level 1" % card_id)
	await wait(0.2)
	check(game.hud.pick_panel.visible and game._pick_kind == "gear", "an Equipment reward offers gear")
	var found: GearItem = game._pick_options[0]
	game.hud._on_pick(0)
	await wait(0.2)
	check(Run.gear.equipment.values().has(found), "picking the gear equips %s" % found.title())
	check(game.hud.pick_panel.visible and game._pick_kind == "anvil", "an Anvil reward opens the anvil")
	var weapon: GearItem = Run.gear.equipped("weapon")
	Run.purse.galder = 1000
	var ore_before: int = Run.purse.ore
	var cost: Dictionary = weapon.refine_cost()
	game.hud._on_pick(0)
	await wait(1.0)
	check(game._pick_kind == "anvil" and Run.purse.ore == ore_before - cost.ore,
		"refining at the anvil spends ore and returns to it (%s)" % weapon.title())
	game.hud._on_pick(game._pick_options.size() - 1)
	await wait(0.2)
	Run.gear.equip(GearItem.make(_item("pretty_hammer")))
	while Run.type_points.power < 6:
		Run.apply_type("power")
	game.player.refresh_gear()
	var steps: Array = game.player.combo_steps()
	game.player.attack.start(0)
	for _f in 30:
		await get_tree().physics_frame
	check(game.player.combo == Player.FAMILY_COMBOS.hammer and steps.size() == 4
		and game.player.weapon.weapon_name == "item_40004",
		"a hammer swaps the combo; Extra Swing adds a 4th swing (%d)" % steps.size())
	Run.gear.equip(GearItem.make(Run.cls.start_weapon))
	game.player.refresh_gear()
	check(game.hud.pick_panel.visible and game._pick_kind == "type", "the queued level-up offers the four types next")
	game.hud._on_pick(0)
	await wait(0.4)
	var trained: CardData = game._pick_options[0] if game._pick_kind == "card" else null
	var trained_lv: int = Run.deck.card_level(trained.id) if trained else 0
	check(game.hud.pick_panel.visible and trained and trained_lv > 0, "a level-up also trains a skill you have")
	if trained:
		game.hud._on_pick(0)
		await wait(0.4)
		check(Run.deck.card_level(trained.id) == trained_lv + 1, "training raises %s to Lv %d" % [trained.display_name, Run.deck.card_level(trained.id)])
	check(room.doors.size() == 2, "two exit doors open (%d)" % room.doors.size())

	# Walk through a door into the next room.
	var door: Door = room.doors[0]
	await wait(0.7)
	if game.room == room and is_instance_valid(door):  # it may already have walked into one
		game.player.global_position = door.global_position
	await wait(2.6)
	check(Run.route.depth == 1 and game.room != room, "entering a door loads room 2 (%s)" % game.room.data.id)

	# Clione's shot travels and hurts the player.
	await wait(1.0)
	for e: Enemy in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	var clione: Enemy = game.room.spawn("clione", game.room.random_spot(game.player.global_position, 150.0))
	await wait(0.7)
	# Somewhere in range with a clear line of fire.
	var me: Vector2 = game.player.global_position
	var placed := false
	for _i in 2000:
		var p: Vector2 = game.room.random_spot(me, 120.0)
		if Combat.ground(p - me).length() < 230.0 and game.room.line_clear(p, me):
			clione.global_position = p
			placed = true
			break
	if not placed:  # no open line near the player: bring both into the open
		game.player.global_position = game.room.random_spot(me, 0.0)
		me = game.player.global_position
		clione.global_position = me + Vector2(140, 0)
	var hp_start: int = Run.hp
	var saw_shot := false
	for _f in 400:
		if get_tree().get_nodes_in_group("projectiles").size() > 0 or game.room.world.get_children().any(func(n: Node) -> bool: return n is Projectile):
			saw_shot = true
		await get_tree().physics_frame
		if Run.hp < hp_start:
			break
	check(saw_shot, "Clione fires a projectile")
	check(Run.hp < hp_start, "enemy attacks hurt the player (%d -> %d)" % [hp_start, Run.hp])
