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
	get_window().size = Vector2i(1280, 720)  # the shipped window, not headless 1280x1280
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


func profile() -> Node:
	return get_node("/root/Profile")


func _run() -> void:
	profile().use_path("user://smoke_test_profile.json", true)  # never touch the real save
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
		player.attack.start(0)
		for _f in 20:
			player.aim = Combat.ground(target.global_position - player.global_position).normalized()
			await get_tree().physics_frame
	check(target.hp < hp_before, "punch damages %s (%d -> %d)" % [target.data.id, hp_before, target.hp])

	# Pathfinding returns a route between two walkable points.
	var a := room.random_spot(Vector2.ZERO, 0.0)
	var b := room.random_spot(a, 300.0)
	check(room.find_path(a, b).size() > 1, "grid pathfinding finds a route across the room")

	# Every Power-line attack casts and damages a monster in front of Buffalo.
	check(Run.loadout[0] == Run.cls.start_job.starter.id, "the run starts with %s in slot 1" % Run.cls.start_job.starter.id)
	var skill_ids: Array[StringName] = []
	for card in Run.all_cards():
		if card.is_skill() and card.resource_path.begins_with("res://data/skills/power/") 				and not card.id in [&"clinch_release", &"chakra_balance"]:
			skill_ids.append(card.id)
	check(skill_ids.size() == 23, "the Power line has 25 attacks (23 that deal damage): %d" % skill_ids.size())
	for id in skill_ids:
		# Ranges are on the ground plane; place the dummy at a ground distance.
		var reach := 110.0 if id in [&"boxer_dash", &"flash_cut", &"mega_flash_cut", &"piercing_wave", &"earthquake_blade",
			&"inferno_blade", &"tornado_bomb", &"sonic_slash", &"lightning_strike"] else 50.0
		if id == &"shadow":
			reach = 150.0  # Shadow strikes the monster nearest the cursor, 150 ahead without a mouse
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
		player.enter(Player.State.MOVE)
		for other in room.enemies:
			# Park the room's monsters out of the way: nothing else may take the hit
			# (removing them would break the room's clear later on).
			other.global_position = room.random_spot(spot, 400.0)
			other.apply_debuff("hold", 1.0, 2.0)
			other.hp = maxi(other.hp, 99999)  # nor die to a stray hit and end the wave
		var dummy: Enemy = room.spawn(&"torobbie", at)
		await wait(0.6)
		dummy.max_hp = 99999
		dummy.hp = 99999
		var before := dummy.hp
		Run.cards[id] = 1
		Run.loadout[0] = id
		Run.mp = Run.max_mp
		Run.hp = Run.max_hp
		player.skills.slot_ready_at[0] = 0.0
		player.invulnerable_until = player.now() + 5.0  # room monsters mustn't interrupt the cast
		player.aim = ground_dir
		var cast := player.skills.try_cast(0)
		for _f in 90:
			if is_instance_valid(dummy):
				dummy.global_position = at
			await get_tree().physics_frame
		check(cast and dummy.hp < before, "%s casts and damages a monster (%d -> %d)%s" % [id, before, dummy.hp,
			"" if dummy.hp < before else _why(cast, dummy, player)])
		if dummy.is_hittable():
			dummy.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.3)
	player.invulnerable_until = 0.0
	# Echo runes: a borrowed skill in slot 4.
	for c: CardData in Run.echoes.reduce(func(acc: Array, e: EnemyData) -> Array: return acc + e.runes, []):
		var spot2 := Vector2.INF
		var dir2 := Vector2.ZERO
		# Galder Barrage lands on the cursor (150 ahead without a mouse).
		var reach2 := 150.0 if c.id == &"galder_barrage" else 70.0
		for _i in 300:
			var p := room.random_spot(Vector2.ZERO, 0.0)
			var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
			if room.line_clear(p, p + Combat.screen(d) * (reach2 + 60.0)) and room.is_open_spot(p + Combat.screen(d) * reach2):
				spot2 = p
				dir2 = d
				break
		if spot2 == Vector2.INF:  # no open line found: fall back to any open spot
			spot2 = room.random_spot(Vector2.ZERO, 0.0)
			dir2 = Vector2.RIGHT
		player.global_position = spot2
		player.enter(Player.State.MOVE)
		var at2 := spot2 + Combat.screen(dir2) * reach2
		for other in room.enemies:
			# As above: nothing else may take the hit (spells land on the monster nearest the aim).
			other.global_position = room.random_spot(spot2, 400.0)
			other.apply_debuff("hold", 1.0, 3.0)
			other.hp = maxi(other.hp, 99999)
		var target2: Enemy = room.spawn(&"torobbie", at2)
		for _w in 30:
			await wait(0.1)
			if target2.is_hittable():
				break
		var hp0 := target2.hp
		Run.take_rune(c)
		Run.mp = Run.max_mp
		Run.galder = 500
		player.skills.slot_ready_at[3] = 0.0
		player.invulnerable_until = player.now() + 5.0
		player.aim = dir2
		var cast2 := player.skills.try_cast(3)
		for _f in 90:
			if is_instance_valid(target2):
				target2.global_position = at2
			await get_tree().physics_frame
		check(cast2 and target2.hp < hp0, "rune skill %s casts from slot 4 (%d -> %d)%s" % [c.id, hp0, target2.hp,
			"" if target2.hp < hp0 else _why(cast2, target2, player)])
		if target2.is_hittable():
			target2.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.3)
	Run.rune = null
	player.invulnerable_until = 0.0
	Run.cards = {Run.cls.start_job.starter.id: 1}
	Run.loadout.assign([Run.cls.start_job.starter.id, &"piercing_wave", &"shockwave"])
	Run.cards[&"piercing_wave"] = 2
	Run.cards[&"shockwave"] = 1
	Run.add_card(&"tornado_bomb", 1)
	check(Run.loadout[1] == &"tornado_bomb" and Run.card_level(&"piercing_wave") == 0,
		"a new skill can replace a slotted one")
	Run.loadout.assign([Run.cls.start_job.starter.id, &"", &""])
	Run.cards = {Run.cls.start_job.starter.id: 1}
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
	check(Run.card_level(card_id) == 1, "picking adds %s at level 1" % card_id)
	await wait(0.2)
	check(game.hud.pick_panel.visible and game._pick_kind == "gear", "an Equipment reward offers gear")
	var found: GearItem = game._pick_options[0]
	game.hud._on_pick(0)
	await wait(0.2)
	check(Run.equipment.values().has(found), "picking the gear equips %s" % found.title())
	check(game.hud.pick_panel.visible and game._pick_kind == "anvil", "an Anvil reward opens the anvil")
	var weapon: GearItem = Run.equipped("weapon")
	Run.galder = 1000
	var ore_before: int = Run.ore
	var cost: Dictionary = weapon.refine_cost()
	game.hud._on_pick(0)
	await wait(1.0)
	check(game._pick_kind == "anvil" and Run.ore == ore_before - cost.ore,
		"refining at the anvil spends ore and returns to it (%s)" % weapon.title())
	game.hud._on_pick(game._pick_options.size() - 1)
	await wait(0.2)
	Run.equip(GearItem.make(_item("pretty_hammer")))
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
	Run.equip(GearItem.make(Run.cls.start_weapon))
	game.player.refresh_gear()
	check(game.hud.pick_panel.visible and game._pick_kind == "type", "the queued level-up offers the four types next")
	game.hud._on_pick(0)
	await wait(0.4)
	var trained: CardData = game._pick_options[0] if game._pick_kind == "card" else null
	var trained_lv: int = Run.card_level(trained.id) if trained else 0
	check(game.hud.pick_panel.visible and trained and trained_lv > 0, "a level-up also trains a skill you have")
	if trained:
		game.hud._on_pick(0)
		await wait(0.4)
		check(Run.card_level(trained.id) == trained_lv + 1, "training raises %s to Lv %d" % [trained.display_name, Run.card_level(trained.id)])
	check(room.doors.size() == 2, "two exit doors open (%d)" % room.doors.size())

	# Walk through a door into the next room.
	var door: Door = room.doors[0]
	await wait(0.7)
	if game.room == room and is_instance_valid(door):  # it may already have walked into one
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
		if get_tree().get_nodes_in_group("projectiles").size() > 0 or game.room.world.get_children().any(func(n): return n is Projectile):
			saw_shot = true
		await get_tree().physics_frame
		if Run.hp < hp_start:
			break
	check(saw_shot, "Clione fires a projectile")
	check(Run.hp < hp_start, "enemy attacks hurt the player (%d -> %d)" % [hp_start, Run.hp])

	# Job changes, upgrade skills and the Power-line talents.
	await skill_rules()
	# The Magic line: Sheep and Dragon, casting, Seals and Pacts, every spell.
	await magic_line()
	# The Sense line: Fox and Lion, the gun's cycle, every Sense skill.
	await sense_line()

	# Progression guards: damage grows with its stat as in Trickster, and
	# monsters are as tough as their original level, not as deep as the room.
	var outliers: PackedStringArray = []
	for ri in Run.regions.size():
		var r: RegionData = Run.regions[ri]
		for e in r.enemies:
			if e.echo or e.min_depth >= 99:
				continue
			var st := Stats.from_monster(Run.monster_stats(e).get("stats", {}))
			var hp: float = Run.mob_hp(st, r) * e.hp_mult
			if e.is_boss:
				# Basic hits from a par build at the region's end (about 210 a hit
				# after Coral Beach, twice that after Desert Beach).
				var hits: float = hp / (210.0 * (ri + 1))
				if hits < 15.0 or hits > 120.0:
					outliers.append("%s boss takes %.0f hits" % [e.id, hits])
			elif float(Run.mob_hit(st, r)) > Run.region_norm(r).hit * Run.MAX_HIT_SPREAD * Run.MOB_HIT_SCALE * r.damage_scale + 1.0:
				outliers.append("%s hits too hard" % e.id)
	check(outliers.is_empty(), "every monster's HP comes from its original level%s" % ("" if outliers.is_empty() else ": " + ", ".join(outliers)))
	Profile.class_id = "dragon"
	Run.new_run()
	var arrow: CardData = Run.card(&"mana_arrow")
	var before: float = Run.skill_mult(arrow)
	Run._stats["MA"] = Run.stat("MA") * 2
	check(is_equal_approx(Run.skill_mult(arrow), before * 2.0), "twice the MA is twice Mana Arrow's damage (x%.2f -> x%.2f)" % [before, Run.skill_mult(arrow)])
	var always := true
	for i in 20:
		always = always and Run.card(&"mana_arrow") in Run.card_offers(3, true)
	Run.cards[&"mana_arrow"] = 3
	for i in 20:
		always = always and Run.card(&"arrow_rush") in Run.card_offers(3, false)
	for i in 20:
		always = always and Run.card(&"arrow_rush") in Run.card_offers(3, true)
	check(always, "Dragon is always offered Mana Arrow's level-ups, and Arrow Rush (new cards and training) once Mana Arrow is Lv 3")
	# The two basics: Mana Arrow wins on one or two targets, Mana Ring from three,
	# at every stage (the basic and its supplement at the same level).
	var ring: CardData = Run.card(&"mana_ring")
	var rush: CardData = Run.card(&"arrow_rush")
	var boost: CardData = Run.card(&"mana_ring_booster")
	var basics_ok := true
	var basics := PackedStringArray()
	for lv in range(1, 6):
		var arrows := 1.0 + (rush.value_at(lv) - 1.0) * rush.param("ratio", lv) / 100.0 if lv > 1 else 1.0
		var arrow_dps := arrow.value_at(lv) * arrows / arrow.cooldown_at(1)
		var ring_dps := (ring.value_at(lv) + (boost.value_at(lv) if lv > 1 else 0.0)) / ring.cooldown_at(1)
		basics_ok = basics_ok and 2.0 * ring_dps <= arrow_dps * 1.1 and 3.0 * ring_dps > arrow_dps
		basics.append("Lv%d %d vs %d/target" % [lv, arrow_dps, ring_dps])
	check(basics_ok, "Mana Arrow out-damages Mana Ring on 2 targets, Mana Ring wins on 3 (%s)" % ", ".join(basics))
	Profile.class_id = "buffalo"
	Run.new_run()

	# UI audit: the worst-case pick lists fit on screen and can be left.
	var saved_mats: Dictionary = Run.materials.duplicate()
	for path in DirAccess.get_files_at("res://data/materials"):
		var m: MaterialData = load("res://data/materials/" + path.trim_suffix(".remap"))
		Run.material_info[m.id] = m
		Run.materials[m.id] = m.need + 2
	game._open_compounder()
	await wait(0.3)
	var all_ok := true
	for i in game._pick_options.size():
		all_ok = all_ok and game.hud.pick_reachable(i)
	check(all_ok and game.hud.pick_panel.get_global_rect().size.y <= 720.0,
		"a Compounder with %d materials fits on screen and every option is reachable" % (game._pick_options.size() - 1))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.2)
	check(not game.hud.pick_panel.visible or game._pick_kind != "compound_mat", "Esc leaves the Compounder")
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	Run.materials = saved_mats
	var many: Array = []
	for i in 20:
		many.append({"title": "Option %d" % i, "text": "A long description that has to wrap onto a second line inside the pick panel without running under the icon or off the edge."})
	many.append({"title": "Leave", "text": "", "cancel": true})
	game.hud.show_pick("Twenty options", many)
	await wait(0.3)
	check(game.hud.pick_reachable(20) and game.hud.pick_panel.get_global_rect().end.y <= 720.0,
		"a 20-option list scrolls and its Leave option stays pinned on screen (reachable %s, bottom %d)"
		% [game.hud.pick_reachable(20), game.hud.pick_panel.get_global_rect().end.y])
	game.hud.pick_panel.visible = false

	# Jump to Coral Beach's boss room.
	await clear_room()
	Run.depth = Run.regions[0].run_length
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

	# A lingering spell outlives its room (a run ending, a room change) cleanly:
	# the field's end effect used to wait on a freed player and error.
	check(Enemy.projectile_scene().instantiate() is Projectile, "monster shots load (Tutankhamen's curse once got an empty scene)")
	var caster: Player = game.player
	Run.cards[&"undines_garden"] = 1
	Run.loadout[0] = &"undines_garden"
	Run.mp = Run.max_mp
	caster.skills.slot_ready_at[0] = 0.0
	caster.enter(Player.State.MOVE)
	var lingered := caster.skills.try_cast(0)
	await wait(1.5)
	var held := Skill._lingering.size()  # checked once the run is over and the game freed, below

	# Death shows the rollback results.
	Run.hp = 1
	game.player.invulnerable_until = 0.0
	game.player.take_hit(50, Vector2.RIGHT, 0.0, false, 1000000)  # perfect accuracy: no evade
	await wait(2.6)
	check(game.hud.results_panel.visible and game.phase == game.Phase.DEAD, "dying shows the rollback results")
	var P := profile()
	check(P.stats.runs == 1 and P.stats.deaths == 1 and P.tm == Run.tm, "the rollback banks the run (%d TM)" % P.tm)

	# Megalopolis: people, the gate, conversations and restorations.
	Engine.time_scale = 1.0
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	await wait(0.5)
	check(lingered and held > 0 and Skill._lingering.is_empty(),
		"a lingering field lets go when the run ends under it (%d lingering, then %d)" % [held, Skill._lingering.size()])
	var hub = load("res://scenes/hub.tscn").instantiate()
	get_tree().root.add_child(hub)
	await wait(1.0)
	check(hub.npcs.size() == 4 and hub.gate != null and hub.room.is_walkable(hub.player.global_position),
		"the hub builds Megalopolis with %d people and the gate" % hub.npcs.size())
	check(hub.story.conversation_for("cavalier").get("id") == "cav_intro", "Don Cavalier starts with his introduction")
	var guide: Npc = hub._npc(&"cavalier")
	hub.player.global_position = guide.global_position + Vector2(0, 20)
	hub.talk(guide)
	for _i in 30:
		await wait(0.05)
		hub.dialogue._typing = false
		hub.dialogue._advanced.emit()
	check(P.has_flag("met_cavalier") and not hub.talking, "finishing a conversation sets its flag")
	check(hub.story.conversation_for("cavalier").get("id") == "cav_rollback", "after a death he remembers the rollback")
	P.tm = 10000
	var hall: RestorationData = Run.hub.restorations.filter(func(r: RestorationData) -> bool: return r.id == &"training_hall")[0]
	check(P.buy(hall) and P.level(hall.id) == 1 and P.tm == 10000 - hall.tm_cost(1), "restoring the Training Hall spends TM")
	Run.new_run()
	check(Run.max_hp == Run.stat("HP") and Run._bonus_hp == 15, "restorations apply to the next run (max HP %d)" % Run.max_hp)
	var reach: float = Combat.ground(hub.room.nearest_reachable(Run.hub.gate_position) - hub.gate.global_position).length()
	check(reach < 1.0, "the expedition gate stands on reachable ground")
	hub.queue_free()
	_systems(Run)

	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures else 0)


func _item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id)


## Stats, types and traits, jobs and prerequisites, gear, weight and refining.
func _systems(Run: Node) -> void:
	_restore_all(Run)
	Run.new_run()
	var ap: int = Run.stat("AP")
	var ac: int = Run.stat("AC")
	var t: Dictionary = Run.apply_type("power")
	check(Run.stat("AP") == ap + 4 and Run.stat("AC") == ac + 2 and t.is_empty(), "a Power point raises AP and AC")
	Run.apply_type("power")
	t = Run.apply_type("power")
	check(t.get("id") == &"staggering_finish" and Run.has_trait(&"staggering_finish"),
		"three Power points unlock Staggering Finish")
	var hp: int = Run.max_hp
	Run.gain_exp(Run.exp_to_next())
	check(Run.level == 2 and Run.max_hp > hp and Run.hp == Run.max_hp, "levelling grows HP along Buffalo's graph")

	Run.new_run()
	var mult: float = Run.attack_mult()
	Run.equip(GearItem.make(_item("wood_sword")))
	check(Run.stat("AP") == Run.cls.base.AP + 20 and Run.attack_mult() > mult * 1.2,
		"a Wood Sword raises AP and combo damage (x%.2f)" % (Run.attack_mult() / mult))
	Run.equip(GearItem.make(_item("lucky_amulet")))
	Run.equip(GearItem.make(_item("topaz_ring")))
	check(Run.equipped("acc1").data.id == &"lucky_amulet" and Run.equipped("acc2").data.id == &"topaz_ring",
		"two accessories fill both accessory slots")
	check(not Run.overweight() and Run.speed_mult() == 1.0, "light gear stays under the load limit")
	Run.equip(GearItem.make(_item("bamboo_sword")))
	Run.equip(GearItem.make(_item("clam_shield")))
	check(Run.overweight() and Run.speed_mult() < 1.0, "heavy gear past WT / 4 (%d / %d) slows you" % [Run.equip_load(), Run.load_limit()])
	var pouch := GearItem.make(_item("pocket_pouch"))
	Run.equip(pouch, "acc1")
	check(not Run.overweight(), "a Pocket Pouch (+200 WT) carries the load")

	var sword := GearItem.make(_item("wood_sword"))
	Run.equip(sword)
	Run.ore = 50
	Run.galder = 5000
	var before: int = Run.stat("AP")
	check(Run.try_refine(sword, 0.0) == "success" and sword.refine == 1 and Run.stat("AP") > before
		and sword.title() == "Wood Sword +1", "refining succeeds and raises AP (%d -> %d)" % [before, Run.stat("AP")])
	var dropped := false
	for _i in 40:
		sword.refine = 5
		if Run.try_refine(sword, 0.999) == "drop":
			dropped = sword.refine == 4
			break
	check(dropped, "a failed refine from +5 can drop a level")
	check(not Run.can_afford_refine(sword) or Run.ore > 0, "refining costs Bronze Fragments and Galder")

	Run.depth = 0
	var early: Array = Run.gear_offers(30)
	Run.depth = 5
	var late: Array = Run.gear_offers(30)
	check(early.all(func(g: GearItem) -> bool: return g.data.level <= 1)
		and late.any(func(g: GearItem) -> bool: return g.data.level >= 13), "deeper rooms drop higher-level gear")
	var rolls: Array = []
	for _i in 60:
		rolls.append(GearItem.roll(_item("wood_sword"), 1.0))
	check(rolls.any(func(g: GearItem) -> bool: return g.prefix != ""), "drops can roll Trickster prefixes (%s)"
		% rolls.filter(func(g: GearItem) -> bool: return g.prefix != "")[0].title())

	Run.new_run()
	var offered_smash := false
	for _i in 40:
		for c: CardData in Run.card_offers(3, false):
			offered_smash = offered_smash or c.id == &"upper_smash"
	check(not offered_smash, "Upper Smash waits for Bull's Eye Lv 3 (the original's 10 of 11)")
	Run.cards[&"bulls_eye"] = 3
	for _i in 40:
		for c: CardData in Run.card_offers(3, false):
			offered_smash = offered_smash or c.id == &"upper_smash"
	check(offered_smash, "Bull's Eye Lv 3 opens Upper Smash")

	Run.depth = Run.region.job_change_depth
	check(Run.job_change_due() and Run.job.id == &"fighter", "the trial room brings the Fighter's job change")
	var sword_mult: float = Run.attack_mult()
	var knight: JobData = Run.job.next_jobs[0]
	Run.start_job(knight)
	var knight_only: bool = Run.card_offers(3, false, knight).all(func(c: CardData) -> bool: return c in knight.cards)
	check(Run.job.id == &"knight" and knight_only, "advancing to Knight opens the Knight tree")
	var third: Array = Run.job.next_jobs.map(func(j: JobData) -> String: return String(j.id))
	check(third == ["gladiator", "mercenary"] and Run.job.next_jobs[0].unlocked() and not Run.job.next_jobs[1].unlocked(),
		"a Knight goes on to Gladiator, or Mercenary once a Gladiator clear unlocks it")
	Profile.stats["clears_gladiator"] = 1
	check(Run.job.next_jobs[1].unlocked(), "a Gladiator clear unlocks the Mercenary")
	Profile.stats.erase("clears_gladiator")
	check(Run.attack_mult() > sword_mult * 1.1, "Sword Mastery strengthens the sword combo")

	Run.new_run()
	var evade: float = Run.evade_chance(50)
	for _i in 3:
		Run.apply_type("charm")
	check(Run.evade_chance(50) > evade + 0.08, "Charm raises evasion and unlocks Light Feet")
	for _i in 10:
		Run.apply_type("magic")
	Run.mp = 0
	var hp_before: int = Run.hp
	check(Run.spend_mp(10) and Run.hp == hp_before - 20, "Overcast pays missing MP with HP")

	# Monster materials and compounding.
	Run.new_run()
	var penguin: EnemyData = Run.region.enemy(&"blue_penguin")
	var ice: MaterialData = penguin.material
	var drop: Dictionary = Run.add_kill(0, 0, 0, true, false, ice, 0.0)
	check(drop.material == ice and Run.material_count(ice) == 2, "an elite Blue Penguin drops 2 Cool Ice")
	Run.add_material(ice, 2)
	var blade := GearItem.make(_item("wood_sword"))
	Run.equip(blade)
	check(Run.compoundable_materials().has(ice) and Run.compound_targets().has("weapon"),
		"4 Cool Ice can be compounded into the Wood Sword's slot")
	var c: Dictionary = Run.compound(blade, ice)
	check(c.stat == "Water" and c.value >= ice.min_value and c.value <= ice.max_value and Run.material_count(ice) == 0
		and blade.free_slots() == 0, "compounding uses 4 Cool Ice and rolls Water attack %d" % c.value)
	check(Run.element_attack().get("Water", 0) == c.value, "the sword's Water attack counts toward elemental damage")
	var hard: MaterialData = Run.region.enemy(&"bustshell").material
	var helm := GearItem.make(_item("candy_hat"))
	Run.equip(helm)
	var dp: int = Run.stat("DP")
	Run.add_material(hard, hard.need)
	var hc: Dictionary = Run.compound(helm, hard)
	check(Run.stat("DP") == dp + hc.value, "Hard Scales compounded into a hat add DP (+%d)" % hc.value)
	var shop: Array[Dictionary] = Run.shop_offers()
	check(shop.any(func(o: Dictionary) -> bool: return o.kind == "gear") and shop.any(func(o: Dictionary) -> bool: return o.kind == "potion"),
		"the shop sells gear and potions")
	Run.depth = 4
	Run.current_room().feature = &"blue_penguin"
	var roller = load("res://scripts/room.gd").new()
	var penguins := 0
	var total := 0
	for _r in 6:
		for w in roller._make_waves(4, false):
			for e in w:
				total += 1
				penguins += 1 if e.id == &"blue_penguin" else 0
	check(penguins * 3 >= total, "a Blue Penguin den fills its waves with penguins (%d of %d)" % [penguins, total])

	# Warehouse, heirlooms, level sync and rollback.
	Run.new_run()
	var heir := GearItem.make(_item("wood_sword"))
	heir.refine = 5
	Run.equip(heir)
	check(Run.save_point(heir) and Profile.warehouse.size() == 1 and heir.stored == 0, "a Portable Port sends the sword home")
	Profile.set_heirloom(0)
	Run.new_run()
	var carried: GearItem = Run.equipped("weapon")
	check(carried.data.id == &"wood_sword" and carried.refine == 5 and carried.effective_refine() == 3
		and carried.sync_factor() < 1.0, "the heirloom comes back level-synced: %s" % carried.title())
	var synced_ap: int = carried.stats().AP
	Run.depth = 3
	Run.sync_heirlooms()
	check(carried.stats().AP > synced_ap and carried.sync_factor() == 1.0, "deeper rooms lift the sync (AP %d -> %d)"
		% [synced_ap, carried.stats().AP])
	Run.depth = 0
	Run.ore = 20
	Run.galder = 5000
	Run.try_refine(carried, 0.0)
	check(Run.unsaved_changes().size() == 1, "refining the heirloom is unsaved until a Port")
	Run.new_run()
	check(Run.equipped("weapon").refine == 5, "dying without saving rolls the heirloom back to +5")
	Run.try_refine(Run.equipped("weapon"), 0.0)
	Run.save_point()
	Run.new_run()
	check(Run.equipped("weapon").refine == 6, "saving at a Port keeps the +6")
	var kept: Dictionary = Profile.bank_leftovers(false, 101, 5, {&"cool_ice": 3})
	check(kept.galder == 50 and Profile.ore == 2 and Profile.materials.get("cool_ice", 0) == 1,
		"a rollback banks half the leftover Galder, ore and materials")
	Profile.bank_leftovers(true, 100, 4, {&"cool_ice": 4})
	check(Profile.galder == 150 and Profile.materials.cool_ice == 5, "a clear banks all of them")
	Profile.use_path("user://smoke_test_profile.json", true)
	Run.new_run()
	check(not Run.system_on(&"smithing") and not Run.job_change_due(), "a fresh city has no smithing or job changes")
	Run.depth = Run.region.job_change_depth
	check(not Run.job_change_due(), "without the Job Hall the trial room changes nothing")
	_restore_all(Run)
	check(Run.system_on(&"smithing") and Run.job_change_due(), "restoring the Job Hall turns the job change on")

	# Monster cards and the wardrobe.
	Profile.restorations["card_house"] = 1
	var boss_cards := 0
	for _i in 40:
		boss_cards += 1 if Run.roll_card(&"golden_mole", false, true) else 0
	check(boss_cards > 8 and boss_cards < 32, "bosses drop their cards half the time (%d / 40)" % boss_cards)
	var shore: CardSetData = Run.hub.card_sets.filter(func(s: CardSetData) -> bool: return s.id == &"shore_critters")[0]
	for m in shore.monsters:
		Profile.add_card(m)
	check(shore.complete() and shore.reward.id == &"bunny_ears", "three cards complete the Shore Critters set")
	Profile.give_wardrobe(&"buffalo_horn")
	Profile.wear("ear", &"buffalo_horn")
	Run.new_run()
	var mult_horn: float = Run.attack_mult()
	check(Run.quirk(&"elite_bane") and Run.stat("AP") == Run.cls.base.AP + 2 + 6 and mult_horn > 1.0,
		"wearing Buffalo's Horn adds AP and its quirk")
	Profile.wear("ear", &"")
	Run.new_run()

	# Echoes appear in elite rooms only after a first clear.
	Run.new_run()
	Run.depth = Run.regions[0].elite_depths[0]
	var echo_seen := false
	for _i in 40:
		echo_seen = echo_seen or Run.echo_here() != null
	check(not echo_seen or int(Profile.stats.get("clears", 0)) >= 1, "no Echoes before the first clear")
	Profile.stats["clears"] = max(1, int(Profile.stats.get("clears", 0)))
	for _i in 40:
		echo_seen = echo_seen or Run.echo_here() != null
	check(echo_seen, "after a clear, Echoes haunt elite rooms")
	Run.new_run()

	# Bunny: a second class from data alone.
	var bunny: ClassData = Run.classes[1]
	check(not bunny.unlocked() or int(Profile.stats.get("clears", 0)) >= 1, "Bunny's slot opens after a clear")
	Profile.stats["clears"] = 1
	Profile.class_id = "bunny"
	Run.new_run()
	check(Run.cls.id == &"bunny" and Run.job.id == &"schoolgirl" and Run.job.next_jobs[0].id == &"boxer"
		and Run.card_level(&"shockwave") == 1, "Bunny starts as a Schoolgirl with Shockwave, headed for Boxer")
	var boxer: JobData = Run.job.next_jobs[0]
	Run.start_job(boxer)
	var champ_or_duel: Array = boxer.next_jobs.map(func(j: JobData) -> String: return String(j.id))
	check(champ_or_duel == ["champion", "duelist"] and not boxer.next_jobs[1].unlocked(),
		"a Boxer goes on to Champion, or Duelist after a Champion clear")
	Profile.class_id = "buffalo"
	Run.new_run()

	# Drilling.
	Profile.restorations["drill_shop"] = 1
	var drill: DrillData = Run.drill()
	check(drill != null and drill.id == &"basic_drill", "the Drill Shop gives a Basic Drill")
	var shallow: Dictionary = Run.dig_rewards(10)
	var deep: Dictionary = Run.dig_rewards(80)
	check(shallow.ore > 0 and shallow.material == null and deep.material != null and deep.shard == 1,
		"deeper digs bring up materials and Harkon Shards")

	# The custom Trickster.
	check(not Run.trickster_unlocked(), "the Trickster is locked at first")
	Profile.stats["clears_gladiator"] = 1
	Profile.stats["clears_champion"] = 1
	Profile.stats["runes_echo_bard"] = 1
	check(Run.trickster_unlocked(), "a 3rd-job clear with Buffalo and with Bunny unlocks the Trickster")
	Profile.custom = {"kit": "fists", "graph": "Magic / Sense", "trees": ["knight", "bard_tree"]}
	Profile.class_id = "trickster"
	Run.new_run()
	var pool_ids: Array = Run.card_pool().map(func(c: CardData) -> String: return String(c.id))
	check(Run.cls.id == &"trickster" and not Run.cls.armed and "lacerator" in pool_ids and "drip_bomb" in pool_ids
		and "shockwave" in pool_ids and Run.has_passive(&"data_bleed"),
		"a fists Trickster with Knight and Bard trees offers Lacerator, Drip Bomb and the Fighter tree")
	check(float(Run.cls.graph.magic) == 0.5, "its type graph is the Magic / Sense preset")
	Profile.class_id = "buffalo"
	Profile.custom = {}
	for k in ["clears_gladiator", "clears_champion", "runes_echo_bard"]:
		Profile.stats.erase(k)
	Run.new_run()

	# Master Louis raises card caps.
	var wave: CardData = Run.card(&"shockwave")
	Profile.materials[String(wave.master_material.id)] = 6
	Profile.galder = 600
	check(Run.can_master(wave) and Run.card_cap(&"shockwave") == 5, "6 Hard Scales and 500 G can master Shockwave")
	Run.master_card(wave)
	Run.cards[&"shockwave"] = 5
	Run.add_card(&"shockwave")
	check(Run.card_cap(&"shockwave") == 6 and Run.card_level(&"shockwave") == 6, "a mastered Shockwave reaches Lv 6")
	Profile.mastery = {}
	Run.new_run()

	# Server Settings (Heat).
	Profile.server_settings = {"server_load": 2, "pk_mode": 1, "hardcore": 1}
	check(ServerSettings.heat() == 7 and is_equal_approx(ServerSettings.monster_hp_mult(), 1.3),
		"Server Load 2 + PK Mode + Hardcore is Heat 7")
	Run.new_run()
	Run.revives = 1
	check(not Run.try_revive(), "Hardcore Server allows no revives")
	Run.tm = 1000
	Run.shards = 0
	Run.finish(true)
	check(Run.last_result.tm == 1700 and Run.last_result.bounty == 7 and Profile.best_heat == 7,
		"clearing at Heat 7 banks +70% TM and a 7-shard bounty")
	Run.new_run()
	Run.tm = 1000
	Run.finish(true)
	check(Run.last_result.bounty == 0, "the bounty is paid once per Heat level")
	Profile.server_settings = {}
	Run.new_run()


func _restore_all(Run: Node) -> void:
	for r: RestorationData in Run.hub.restorations:
		if r.effect == "system":
			Profile.restorations[String(r.id)] = 1


func skill_rules() -> void:
	var p: Player = game.player
	for e in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await wait(0.5)
	p.global_position = game.room.random_spot(p.global_position, 0.0)
	p.invulnerable_until = 0.0
	p.aim = Vector2.RIGHT
	check(p.sprite.actor_name == Run.cls.actor, "a run starts as the class's own character")
	Run.take_damage(30)
	var hp: int = Run.hp
	var points: Dictionary = Run.type_points.duplicate()
	Run.start_job(load("res://data/jobs/knight.tres"))
	p.refresh_gear()
	check(p.sprite.actor_name == "knight" and Run.actor() == "knight", "becoming a Knight turns you into the Knight")
	check(Run.hp == hp and Run.type_points == points, "a job change brings no type points or heal (none in Trickster)")
	Run.start_job(load("res://data/jobs/gladiator.tres"))
	p.refresh_gear()
	check(p.sprite.actor_name == "power_m", "a Gladiator takes the Power 3rd-job body")

	# Advanced forms are offered only with their base skill and replace it.
	Run.new_run()
	Run.start_job(load("res://data/jobs/knight.tres"))
	var tempest: CardData = Run.card(&"tempest_strike")
	check(tempest.upgrades == &"lacerator" and not Run.can_learn(tempest), "Tempest Strike needs Lacerator in hand")
	Run.add_card(&"lacerator")
	Run.cards[&"lacerator"] = 3
	check(Run.can_learn(tempest) and Run.can_learn(Run.card(&"tidal_slash")), "Lacerator Lv 3 opens Tempest Strike and Tidal Slash")
	var at := Run.loadout.find(&"lacerator")
	Run.add_card(&"tempest_strike")
	check(Run.loadout[at] == &"tempest_strike" and Run.card_level(&"lacerator") == 0 and Run.card_level(&"tempest_strike") == 3,
		"Tempest Strike takes Lacerator's slot and level, replacing it")
	check(not Run.can_learn(Run.card(&"tidal_slash")), "with Lacerator gone, Tidal Slash is no longer offered")
	Run.cards[&"tempest_strike"] = 2
	var gale_offered := false
	for _i in 30:
		for c: CardData in Run.card_offers(3, false, load("res://data/jobs/gladiator.tres")):
			gale_offered = gale_offered or c.id == &"gale_strike"
	check(not gale_offered, "Gale Strike isn't offered before Tempest Strike Lv 3")
	Run.cards[&"tempest_strike"] = 3
	Run.start_job(load("res://data/jobs/gladiator.tres"))
	check(Run.can_learn(Run.card(&"gale_strike")), "Tempest Strike Lv 3 opens Gale Strike for the Gladiator")
	Run.add_card(&"piercing_wave")
	Run.cards[&"piercing_wave"] = 3
	Run.add_card(&"earthquake_blade")
	check(Run.card_level(&"piercing_wave") == 0 and Run.known_level(&"piercing_wave") == 3
		and Run.requirements_met(Run.card(&"lightning_strike")),
		"Earthquake Blade replaces Piercing Wave and still opens Lightning Strike")
	check(Run.card_cap(&"guard_break") == 1 and not Run.can_master(Run.card(&"guard_break")),
		"Guard Break stays at Lv 1, as in the original")

	# Talents with the original effects.
	Run.new_run()
	var ap: int = Run.stat("AP")
	Run.add_card(&"pumping_heart")
	check(Run.stat("AP") > ap, "Pumping Heart raises AP (%d -> %d)" % [ap, Run.stat("AP")])
	var target: Enemy = game.room.spawn("torobbie", p.global_position + Vector2(50, 0))
	target.max_hp = 99999
	target.hp = 99999
	for i in 40:
		if target.is_hittable():
			break
		await wait(0.1)
	var acc: int = target.accuracy()
	var defense: float = target.defense_mult()
	Run.add_card(&"shockvibe")
	Run.add_card(&"armor_breaker")
	Run.add_card(&"suffocate")
	p.deal_hit(target, 10.0, 1.0, 0.0, false)
	check(target.accuracy() < acc or acc == 0, "Shockvibe lowers a hit monster's accuracy (%d -> %d)" % [acc, target.accuracy()])
	check(target.defense_mult() >= defense and not target.can_hide(), "Armor Breaker lowers its DP; Suffocate keeps it from hiding")
	Run.add_card(&"guard")
	p._tick_talents(0.016)
	hp = Run.hp
	p.invulnerable_until = 0.0
	p.take_hit(20, Vector2.LEFT, 0.0, false, 9999)
	check(Run.hp == hp and Run.guard_blocks == 0, "Guard blocks a physical hit outright")
	p.invulnerable_until = 0.0
	p.take_hit(20, Vector2.LEFT, 0.0, true, 9999)
	check(Run.hp < hp, "Guard doesn't block magic")
	Run.add_card(&"clinch_release")
	Run.loadout[1] = &"clinch_release"
	p.invulnerable_until = 0.0
	p.take_hit(5, Vector2.LEFT, 300.0, false, 9999)
	p.skills.slot_ready_at[1] = 0.0
	Run.mp = Run.max_mp
	p.buffer_action("skill_2")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p.state == Player.State.SKILL and p.knock == Vector2.ZERO, "Clinch Release can be cast while staggered and cancels it")
	await wait(0.4)
	Run.hp = Run.max_hp / 2
	p.start_regen(0.05, 0.2, 2.0)
	await wait(0.5)
	check(Run.hp > Run.max_hp / 2, "Chakra Balance recovers HP over time")
	target.take_hit(999999, Vector2.RIGHT, 0.0, true)
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)


## Takes a dummy away without a death (no EXP, no room clear).
func _remove(e: Enemy) -> void:
	if is_instance_valid(e):
		game.room.enemies.erase(e)
		e.queue_free()


## A dummy in front of the player that won't die from the checks.
## Why a spell check missed: did the cast start, where was the target, and
## what else was in the room.
func _why(cast: bool, e: Enemy, p: Player) -> String:
	var others := 0
	for o in game.room.enemies:
		if o != e and o.is_hittable():
			others += 1
	return " [cast %s, target %s at %.0f px, state %d, player state %d, %d other monsters]" % [cast,
		"valid" if is_instance_valid(e) else "gone", e.global_position.distance_to(p.global_position) if is_instance_valid(e) else -1.0,
		e.state if is_instance_valid(e) else -1, p.state, others]


func _dummy(p: Player, ahead: float) -> Enemy:
	var room: Room = game.room
	var spot := Vector2.INF
	var dir := Vector2.RIGHT
	for _i in 300:
		var at := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		if room.line_clear(at, at + Combat.screen(d) * (ahead + 40.0)) and room.is_open_spot(at + Combat.screen(d) * ahead):
			spot = at
			dir = d
			break
	p.global_position = spot
	p.enter(Player.State.MOVE)
	p.aim = dir
	for other in room.enemies.duplicate():
		_remove(other)  # nothing else may take the hit
	var e: Enemy = room.spawn(&"torobbie", spot + Combat.screen(dir) * ahead)
	for _w in 30:
		await wait(0.1)
		if e.is_hittable():
			break
	e.max_hp = 99999
	e.hp = 99999
	return e


func magic_line() -> void:
	var p: Player = game.player
	for e in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await wait(0.5)
	p.invulnerable_until = 0.0
	check(Run.classes.size() == 6 and Run.classes.all(func(c: ClassData) -> bool: return c.unlocked()),
		"all six characters are playable from the start")
	var saved: String = Profile.class_id

	# Sheep: Librarian, Mana Ring on the attack button, no MP.
	Profile.class_id = "sheep"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"sheep" and Run.job.id == &"librarian" and Run.card_level(&"mana_ring") == 1
		and not &"mana_ring" in Run.loadout and p.sprite.actor_name == "sheep",
		"Sheep starts as a Librarian with Mana Ring as her basic attack, not in a slot")
	var target := await _dummy(p, 90.0)
	var mp := Run.mp
	var hp := target.hp
	p.buffer_action("attack")
	await wait(2.5)  # the rings appear by her, then swoop in (the client's flight)
	check(target.hp < hp and Run.mp >= mp, "left click casts Mana Ring at no MP (%d -> %d, MP %d -> %d)" % [hp, target.hp, mp, Run.mp])
	var never := true
	for _i in 60:
		for c: CardData in Run.card_offers(3, false):
			never = never and not c.id in [&"mana_arrow", &"arrow_rush"]
	check(never, "Sheep is never offered Mana Arrow or Arrow Rush")

	# MP regenerates for mages.
	Run.mp = 0
	await wait(1.0)
	check(Run.mp > 0, "a mage regenerates MP over time (%d after 1 s)" % Run.mp)

	# Casting: half the original Delay, locked in place, only a dash gets out.
	Run.start_job(load("res://data/jobs/bard.tres"))
	p.refresh_gear()
	Run.cards[&"seal_of_water"] = 1
	Run.add_card(&"drip_bomb")
	var slot := Run.loadout.find(&"drip_bomb")
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[slot] = 0.0
	var at := p.global_position
	var bomb := Run.card(&"drip_bomb")
	check(is_equal_approx(bomb.cast_at(1), 0.5), "Drip Bomb casts in 0.5 s (the original's 1.0, halved)")
	p.skills.try_cast(slot)
	Input.action_press("move_right")
	p.buffer_action("attack")
	p.take_hit(5, Vector2.LEFT, 300.0, false, 9999)
	await wait(0.25)
	check(p.state == Player.State.SKILL and p.skills.casting_left() > 0.0 and p.global_position.distance_to(at) < 2.0,
		"mid-cast: a hit, a move and an attack press don't move or interrupt the caster")
	Input.action_release("move_right")
	mp = Run.mp
	p.buffer_action("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p.state == Player.State.DASH and Run.mp > mp, "a dash cancels the cast and refunds its MP (%d -> %d)" % [mp, Run.mp])
	await wait(0.5)

	# Seals shut out two elements; job lists decide who learns what.
	check(not Run.can_learn(Run.card(&"seal_of_fire")) and not Run.can_learn(Run.card(&"seal_of_earth"))
		and Run.can_learn(Run.card(&"seal_of_thunder")), "Seal of Water closes the Fire and Earth seals")
	check(not Run.can_learn(Run.card(&"whirlwind_blaze")), "without Seal of Fire, fire magic isn't offered")
	Run.cards[&"seal_of_thunder"] = 1
	Run.cards[&"electro_attack"] = 3
	check(not Run.requirements_met(Run.card(&"tesla_field")), "Sheep's Tesla Field waits for Mana Ring Lv 3")
	Run.cards[&"mana_ring"] = 3
	check(Run.requirements_met(Run.card(&"tesla_field")), "Mana Ring Lv 3 stands in for Mana Arrow in Sheep's Tesla Field")
	Run.start_job(load("res://data/jobs/witch.tres"))
	check(Run.can_learn(Run.card(&"dark_pact")) and Run.can_learn(Run.card(&"light_pact")), "a Witch can learn Magician skills")
	Run.cards[&"water_shield"] = 2
	Run.start_job(load("res://data/jobs/soul_master.tres"))
	Run.add_card(&"undines_blessing")
	check(Run.card_level(&"water_shield") == 0 and Run.card_level(&"undines_blessing") == 2 and Run.resist("Water") > 0.0,
		"Undine's Blessing replaces the Water Shield and keeps its resistance (%d%%)" % Run.resist("Water"))
	_remove(target)

	# Dragon: Shaman, Mana Arrow, and the Priest can't learn dark magic.
	Profile.class_id = "dragon"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"dragon" and Run.job.id == &"shaman" and Run.card_level(&"mana_arrow") == 1,
		"Dragon starts as a Shaman with Mana Arrow")
	never = true
	for _i in 60:
		for c: CardData in Run.card_offers(3, false):
			never = never and not c.id in [&"mana_ring", &"mana_ring_booster"]
	check(never, "Dragon is never offered Mana Ring or Mana Ring Booster")
	Run.start_job(load("res://data/jobs/magician.tres"))
	Run.cards[&"mana_arrow"] = 3
	Run.cards[&"light_pact"] = 1
	check(Run.requirements_met(Run.card(&"light_wave")), "Mana Arrow stands in for Mana Ring in Dragon's Light Wave")
	Run.cards.erase(&"light_pact")
	Run.start_job(load("res://data/jobs/priest.tres"))
	check(not Run.can_learn(Run.card(&"dark_pact")) and Run.can_learn(Run.card(&"light_pact")), "a Priest can't learn dark magic")
	Run.start_job(load("res://data/jobs/wizard.tres"))
	check(Run.can_learn(Run.card(&"seal_of_fire")), "a Wizard can learn Bard skills")

	# Element resistance now applies to spells.
	var foe := await _dummy(p, 60.0)
	foe.elements = {"Fire": 50}
	hp = foe.hp
	p.deal_hit(foe, 100.0, 1.0, 0.0, false, {"element": "Fire"})
	var fire_hit := hp - foe.hp
	hp = foe.hp
	p.deal_hit(foe, 100.0, 1.0, 0.0, false, {})
	check(fire_hit < hp - foe.hp, "a monster resists the element it's strong against (%d vs %d)" % [fire_hit, hp - foe.hp])
	_remove(foe)

	# Every Magic spell does its job on a dummy.
	var spells: Array[CardData] = []
	for c in Run.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/magic/") and not c.id in [&"basic_healing", &"med_cure"]:
			spells.append(c)
	check(spells.size() == 50, "the Magic line has 50 spells in play: %d" % spells.size())
	for c in spells:
		var kind := c.behavior.resource_path.get_file()
		var near := kind in ["spell_nova.gd", "spell_whisper.gd"] or c.id == &"hinder_snare"
		var dummy := await _dummy(p, 45.0 if near else 90.0)
		dummy.elements = {}
		var before := dummy.hp
		Run.cards[c.id] = 1
		Run.loadout[0] = c.id
		Run.mp = Run.max_mp
		Run.hp = Run.max_hp / 2
		var hp0 := Run.hp
		p.skills.slot_ready_at[0] = 0.0
		p.invulnerable_until = p.now() + 9.0
		var cast := p.skills.try_cast(0)
		var pin := dummy.global_position
		# Dimensional Rift lingers; Mana Arrow and Mana Ring wait by you before they fly in.
		var until := p.now() + (4.5 if c.id == &"dimensional_rift" else 3.0 if c.id in [&"mana_arrow", &"mana_ring"] else 2.2)
		while p.now() < until:
			if is_instance_valid(dummy):
				dummy.global_position = pin  # it would walk out of fields and bursts
			await get_tree().physics_frame
		var did := false
		var how := ""
		if kind == "spell_heal.gd":
			did = Run.hp > hp0
			how = "heals %d -> %d" % [hp0, Run.hp]
		elif kind == "spell_debuff.gd":
			did = dummy.hp < before or not dummy.debuffs.is_empty()
			how = "debuffs %s, %d -> %d" % [dummy.debuffs.keys(), before, dummy.hp]
		elif c.id in [&"undines_garden", &"raions_space", &"salamanders_territory", &"gnomes_domain", &"sylphs_playground"]:
			did = dummy.debuffs.keys().any(func(k: String) -> bool: return k.begins_with("resist_"))
			how = "lowers %s" % [dummy.debuffs.keys()]
		else:
			did = dummy.hp < before
			how = "%d -> %d" % [before, dummy.hp]
		check(cast and did, "%s casts and works (%s)%s" % [c.id, how, "" if did else _why(cast, dummy, p)])
		Run.cards.erase(c.id)
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)


## The Sense line: Fox and Lion, the gun's cycle, every Sense skill.
func sense_line() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id

	# Fox: Archeologist, Shuriken Master on the attack button, no MP.
	Profile.class_id = "fox"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"fox" and Run.job.id == &"archeologist" and Run.card_level(&"shuriken_master") == 1
		and p.sprite.actor_name == "fox", "Fox starts as an Archeologist with Shuriken Master as her basic attack")
	var target := await _dummy(p, 90.0)
	var mp := Run.mp
	var hp := target.hp
	p.buffer_action("attack")
	await wait(0.9)
	check(target.hp < hp and Run.mp >= mp, "left click throws a hidden weapon at no MP (%d -> %d)" % [hp, target.hp])
	_remove(target)

	# Lion: Engineer, a gun, Gun Carrier, and the gun's cycle.
	Profile.class_id = "lion"
	Run.new_run()
	p.refresh_gear()
	p.velocity = Vector2.ZERO
	var gun := p.gun
	check(Run.cls.id == &"lion" and Run.job.id == &"engineer" and Run.card_level(&"gun_carrier") > 0
		and Run.carries_gun() and gun.has_gun(), "Lion starts as an Engineer carrying a gun (Gun Carrier)")
	check(Run.card_level(&"quick_reload") > 0 and Run.card_level(&"overcharge") == 0 and not gun.charges(),
		"Lion starts with Quick Reload; the power gauge waits for Overcharge")
	check(gun.range() > 300.0, "the gun outranges the spells (%d)" % gun.range())
	var basic_hit := Run.GUN_SHOT * Run.gun_shot_mult()
	var weakest := INF
	for id: StringName in [&"power_shot", &"double_shot", &"butt_plate", &"shooting_spree", &"berserk"]:
		var c := Run.card(id)
		var per_hit := c.value_at(1) * Run.skill_mult(c) / maxf(c.param("count", 1, 1.0), 1.0)
		weakest = minf(weakest, per_hit)
	check(weakest > basic_hit, "every gun skill outhits a basic shot (weakest %d vs %d)" % [weakest, basic_hit])
	var reload := gun.reload_time()
	check(is_equal_approx(reload, 120.0 / 90.0), "the Old Ebony Gun reloads in 120000/GaugeSpeed ms (%.2f s)" % reload)
	target = await _dummy(p, 120.0)
	p.invulnerable_until = p.now() + 30.0  # a monster's hit would reset the reload
	for e in game.room.enemies:
		if e != target:
			e.apply_debuff("hold", 1.0, 30.0)
	gun.equip(gun.gun)
	await wait(reload + 0.2)
	check(gun.loaded(), "standing still, the gun loads")
	hp = target.hp
	p.buffer_action("attack")
	await wait(0.4)
	check(target.hp < hp and gun.state == GunCycle.State.RELOADING,
		"a shot hits the line (%d -> %d) and starts the reload at once" % [hp, target.hp])
	# What resets a reload.
	gun.progress = 100.0
	p.start_dash()
	check(gun.progress == 0.0, "a dash resets the reload")
	gun.progress = 100.0
	gun.interrupt(true)
	check(gun.progress == 0.0, "a hit resets the reload")
	Run.cards[&"invincible_reload"] = 1
	gun.progress = 100.0
	gun.interrupt(true)
	check(gun.progress == 100.0, "Invincible Reload keeps the reload through a hit")
	Run.cards.erase(&"invincible_reload")
	await wait(0.5)
	Run.cards.erase(&"quick_reload")  # Lion's starter: walking keeps the reload
	p.enter(Player.State.MOVE)
	gun.progress = 100.0
	Input.action_press("move_right")
	await wait(0.3)
	var moved := gun.progress
	Input.action_release("move_right")
	Run.cards[&"quick_reload"] = 1
	gun.progress = 100.0
	Input.action_press("move_right")
	await wait(0.3)
	Input.action_release("move_right")
	check(moved < 50.0 and gun.progress > 100.0,
		"walking resets the reload (%.0f), not with Quick Reload (%.0f)" % [moved, gun.progress])
	Run.cards[&"speedloader"] = 5
	check(gun.reload_time() < reload, "Speedloader shortens the reload (%.2f -> %.2f s)" % [reload, gun.reload_time()])
	check(is_equal_approx(gun.reload_time(), reload / (1.0 + Run.card_value(&"speedloader") / 100.0)),
		"Speedloader raises the fill rate as the client does (2 - Ratio/100)")
	Run.cards.erase(&"speedloader")
	check(Run._grows_basic(Run.card(&"quick_reload")) and Run._grows_basic(Run.card(&"invincible_reload")),
		"a gunner is always offered Quick Reload and Invincible Reload once learnable")
	var ac0 := Run.gun_stat_mult()
	Run.type_points["power"] += 5  # +10 AC
	Run.stats_changed()
	check(is_equal_approx(Run.gun_stat_mult(), Run.gun_attack() / float(Run._ref["AC"])) and Run.gun_stat_mult() > ac0,
		"gun damage scales with AC (the server's gun formula): x%.2f -> x%.2f" % [ac0, Run.gun_stat_mult()])
	Run.type_points["power"] -= 5
	Run.stats_changed()
	# The power zone, with Overcharge.
	gun.state = GunCycle.State.LOADED
	gun.power = float(gun.gun.zone) + 5.0
	check(gun.fire() and not gun.last_power, "without Overcharge there is no power shot")
	Run.cards[&"overcharge"] = 1
	gun.state = GunCycle.State.LOADED
	gun.power = float(gun.gun.zone) + 5.0
	check(gun.fire() and gun.last_power, "with Overcharge, a shot fired above PowStartPoint is overcharged")
	Run.cards.erase(&"overcharge")
	# A gun skill fires without a load and leaves the reload alone.
	gun.progress = 60.0
	Run.cards[&"power_shot"] = 1
	Run.loadout[0] = &"power_shot"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	var fired := p.skills.try_cast(0)
	await wait(0.4)
	check(fired and gun.state == GunCycle.State.RELOADING and gun.progress >= 60.0,
		"Power Shot fires mid-reload and doesn't reset it (%.0f)" % gun.progress)
	Run.cards.erase(&"power_shot")
	_remove(target)

	# A wall stops a shot.
	var room: Room = game.room
	var blocked := false
	for _i in 300:
		var at := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		var far := at + Combat.screen(d) * 150.0
		if room.is_walkable(far) and room.line_clear(at, at + Combat.screen(d) * 30.0) and not room.line_clear(at, far):
			p.global_position = at
			p.enter(Player.State.MOVE)
			p.aim = d
			var behind: Enemy = room.spawn(&"torobbie", far)
			await wait(1.0)
			behind.max_hp = 99999
			behind.hp = 99999
			behind.global_position = far  # it may have walked round the wall
			behind.apply_debuff("hold", 1.0, 5.0)
			gun.state = GunCycle.State.LOADED
			p.skills.slot_ready_at[SkillCaster.BASIC] = 0.0
			p.skills.try_cast(SkillCaster.BASIC)
			await wait(0.3)
			check(behind.hp == 99999, "a wall stops a shot")
			_remove(behind)
			blocked = true
			break
	if not blocked:
		print("SKIP  no wall with open ground behind it found")

	# Every Sense skill does its job on a dummy.
	var skills: Array[CardData] = []
	for c in Run.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/sense/") and c.id != &"gun_shot" \
				and not c.id in [&"stone_shower"]:
			skills.append(c)
	for c in skills:
		var kind := c.behavior.resource_path.get_file()
		var dummy := await _dummy(p, 60.0 if kind == "close_strike.gd" else 90.0)
		dummy.elements = {}
		var before := dummy.hp
		Run.cards[c.id] = 1
		Run.loadout[0] = c.id
		Run.mp = Run.max_mp
		Run.hidden = c.id in [&"sudden_attack", &"poison_assault"]
		gun.state = GunCycle.State.LOADED
		p.skills.slot_ready_at[0] = 0.0
		p.invulnerable_until = p.now() + 9.0
		var cast := p.skills.try_cast(0)
		var pin := dummy.global_position
		var until := p.now() + 2.2
		while p.now() < until:
			if is_instance_valid(dummy):
				dummy.global_position = pin
			await get_tree().physics_frame
		var did := false
		var how := ""
		match c.id:
			&"hide":
				did = Run.hidden
				how = "hidden %s" % Run.hidden
			&"bunker":
				did = Run.in_bunker(p.now())
				how = "bunker %d HP" % Run.bunker_hp
			&"bunker_release":
				did = cast
				how = "cast"
			&"sticky_icky", &"shield_breaker":
				did = not dummy.debuffs.is_empty()
				how = "debuffs %s" % [dummy.debuffs.keys()]
			_:
				did = dummy.hp < before
				how = "%d -> %d" % [before, dummy.hp]
		check(cast and did, "%s casts and works (%s)%s" % [c.id, how, "" if did else _why(cast, dummy, p)])
		Run.cards.erase(c.id)
		Run.hidden = false
		Run.bunker_until = 0.0
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0

	# Hybrids, as in the Magic line.
	var hunter_lord: JobData = load("res://data/jobs/hunter_lord.tres")
	var cyber: JobData = load("res://data/jobs/cyber_hunter.tres")
	check(not hunter_lord.unlocked() and not cyber.unlocked(), "Hunter Lord and Cyber Hunter start locked")
	check(Run.card(&"power_shot") in hunter_lord.cards and Run.card(&"fan_of_knives") in cyber.cards,
		"a Hunter Lord learns Inventor skills and a Cyber Hunter Explorer skills")

	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)
