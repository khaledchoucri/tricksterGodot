extends SmokeSection
## The bosses (Master Mong, Tombeth), a lingering spell, death and the rollback, then Megalopolis.


## The boss room, a lingering spell, death and the rollback, then Megalopolis.
func run() -> void:
	var Run := run_state()
	await clear_room()
	Run.route.depth = Run.route.regions[0].run_length
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	game._load_room()
	await wait(3.0)
	var boss: Enemy = null
	for e: Enemy in enemies():
		if e.is_boss:
			boss = e
	check(boss is BossMong and game.room.data.map == "map_dg11b" and boss.display_name == "Master Mong",
		"the Coral Beach boss is Master Mong, in the Dark Cave (%s)" % (boss.display_name if boss else "no boss"))
	if boss is BossMong:
		await _master_mong(boss as BossMong)

	# The Caballa Relics: the last region's boss room is the Trident Maze, with Tombeth, who
	# calls Chimu as he loses his first life.
	await clear_room()
	Run.route.depth = Run.route.plan.size() - 1
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	game._load_room()
	await wait(3.0)
	var tombeth: Enemy = null
	for e: Enemy in enemies():
		if e.is_boss:
			tombeth = e
	check(tombeth is BossTombeth and game.room.data.map == "map_dg03e" and Run.route.final_boss(),
		"the last boss room is the Trident Maze with Tombeth (%s)" % (tombeth.data.id if tombeth else "no boss"))
	if tombeth:
		tombeth.take_hit(int(tombeth.max_hp * 0.36), Vector2.RIGHT, 0.0, true)
		await wait(1.3)
		var chimus := enemies().filter(func(e: Enemy) -> bool: return e.data.id == &"chimu").size()
		check(chimus >= 1, "Tombeth calls Chimu as he loses a life (%d)" % chimus)

	# A lingering spell outlives its room (a run ending, a room change) cleanly:
	# the field's end effect used to wait on a freed player and error.
	check(Enemy.projectile_scene().instantiate() is Projectile, "monster shots load (Tutankhamen's curse once got an empty scene)")
	var caster: Player = game.player
	Run.deck.cards[&"undines_garden"] = 1
	Run.deck.loadout[0] = &"undines_garden"
	Run.mp = Run.max_mp
	caster.skills.slot_ready_at[0] = 0.0
	caster.enter(Player.State.MOVE)
	caster.invulnerable_until = caster.now() + 3.0  # the boss would interrupt the cast
	var lingered := caster.skills.try_cast(0)
	await wait(1.0)
	var held := Skill._lingering.size()  # checked once the run is over and the game freed, below

	# Death shows the rollback results.
	Run.hp = 1
	game.player.invulnerable_until = 0.0
	game.player.take_hit(50, Vector2.RIGHT, 0.0, false, 1000000)  # perfect accuracy: no evade
	await wait(2.6)
	check(game.hud.results_panel.visible and game.phase == game.Phase.DEAD, "dying shows the rollback results")
	var P := profile()
	check(P.stats.runs == 1 and P.stats.deaths == 1 and P.tm == Run.purse.tm, "the rollback banks the run (%d TM)" % P.tm)

	# Megalopolis: people, the gate, conversations and restorations.
	Engine.time_scale = 1.0
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	await wait(0.5)
	check(lingered and held > 0 and Skill._lingering.is_empty(),
		"a lingering field lets go when the run ends under it (%d lingering, then %d)" % [held, Skill._lingering.size()])
	var hub: Hub = load("res://scenes/hub.tscn").instantiate()
	get_tree().root.add_child(hub)
	await wait(1.0)
	check(hub.talker.npcs.size() == 5 and hub.gate != null and hub.room.is_walkable(hub.player.global_position),
		"the hub builds Megalopolis with %d people and the gate" % hub.talker.npcs.size())
	check(hub.hud.sheet.equipment.editable, "in the city the equipment window is where the loadout is designed")
	check(hub.talker.story.conversation_for("cavalier").get("id") == "cav_intro", "Don Cavalier starts with his introduction")
	var guide: Npc = hub.talker.npc(&"cavalier")
	hub.player.global_position = guide.global_position + Vector2(0, 20)
	hub.talk(guide)
	for _i in 30:
		await wait(0.05)
		hub.dialogue._typing = false
		hub.dialogue._advanced.emit()
	check(P.has_flag("met_cavalier") and not hub.talker.talking, "finishing a conversation sets its flag")
	check(hub.talker.story.conversation_for("cavalier").get("id") == "cav_rollback", "after a death he remembers the rollback")
	P.tm = 10000
	var hall: RestorationData = Run.hub.restorations.filter(func(r: RestorationData) -> bool: return r.id == &"training_hall")[0]
	check(P.buy(hall) and P.level(hall.id) == 1 and P.tm == 10000 - hall.tm_cost(1), "restoring the Training Hall spends TM")
	Run.new_run()
	check(Run.max_hp == Run.stat("HP") and Run.bonus_hp == 15, "restorations apply to the next run (max HP %d)" % Run.max_hp)
	var reach: float = Combat.ground(hub.room.nearest_reachable(Run.hub.gate_position) - hub.gate.global_position).length()
	check(reach < 1.0, "the expedition gate stands on reachable ground")
	hub.queue_free()


## Master Mong: three lives in one HP pool, Thief Mongs at the start and at half HP (the user's
## spec), his storm on every life, Mana Shield from his second, Mana Ring and a few Cures on his
## last; his fur as his drop.
func _master_mong(mong: BossMong) -> void:
	var p: Player = game.player
	p.invulnerable_until = p.now() + 60.0  # the casts are counted; the spells don't need to land
	var called: Array[int] = [_thieves()]  # Thief Mongs spawned, counted as they come (some may fall)
	var count_thief := func(e: Enemy) -> void:
		if e.data.id == BossMong.SUMMON_ID:
			called[0] += 1
	Events.enemy_spawned.connect(count_thief)
	check(mong.data.material != null and mong.data.material.item_id == 63354,
		"Master Mong drops Master Mong's Fur (MonItemDropInfo 281)")
	check(mong.storm_look != null and mong.ring_look != null and mong.shield_look != null,
		"Mong's spells wear the player's Mana Storm, Mana Ring and Mana Shield looks")
	mong.global_position = game.room.nearest_reachable(p.global_position + Vector2(90, 0))
	await wait(BossMong.STORM_EVERY + BossMong.STORM_DELAY + 0.5)
	check(_thieves() == mong.summon_start, "Mong comes with %d Thief Mongs (%d)" % [mong.summon_start, _thieves()])
	check(mong.casts.get("storm", 0) >= 1 and mong.casts.get("shield", 0) == 0 and mong.casts.get("ring", 0) == 0,
		"on his first life Mong casts only his storm (%s)" % mong.casts)
	mong.take_hit(int(mong.max_hp * 0.36), Vector2.RIGHT, 0.0, true)
	await wait(1.0)
	check(mong.lives_left() == 2 and mong.is_shielded() and int(mong.stats.MD) == roundi(mong.base_md * 1.19),
		"at 2/3 HP Mong loses a life and raises Mana Shield, MD +19%% (%d lives, %s)" % [mong.lives_left(), mong.casts])
	mong.take_hit(int(mong.max_hp * 0.16), Vector2.RIGHT, 0.0, true)
	await wait(1.5)
	check(called[0] == mong.summon_start + mong.summon_half,
		"at half HP Mong calls %d more Thief Mongs (%d in all, %d standing)" % [mong.summon_half, called[0], _thieves()])
	check(mong.casts.get("ring", 0) == 0, "Mana Ring waits for his last life (%s)" % mong.casts)
	mong.take_hit(int(mong.max_hp * 0.2), Vector2.RIGHT, 0.0, true)
	var low := mong.hp
	mong.global_position = game.room.nearest_reachable(p.global_position + Vector2(90, 0))
	await wait((BossMong.HEAL_EVERY + BossMong.HEAL_CAST) * (mong.heal_casts + 1))
	check(mong.lives_left() == 1 and mong.casts.get("ring", 0) >= 1 and mong.hp > low,
		"on his last life Mong casts Mana Ring and Cures himself (%s, %d -> %d HP)" % [mong.casts, low, mong.hp])
	check(mong.casts.get("heal", 0) == mong.heal_casts, "Mong's Cure runs out after %d casts (%s)" % [mong.heal_casts, mong.casts])
	Events.enemy_spawned.disconnect(count_thief)
	await _thief_steals(p)
	p.invulnerable_until = 0.0


## A Thief Mong's hit takes Galder, and killing it gives it all back.
func _thief_steals(p: Player) -> void:
	var Run := run_state()
	var thief: Enemy = null
	for e: Enemy in enemies():
		if e.data.id == BossMong.SUMMON_ID and e.is_hittable():
			thief = e
	if thief == null:
		check(false, "a Thief Mong is left to test its theft")
		return
	for e: Enemy in enemies():
		if e != thief and e.is_hittable() and not e.is_boss:
			e.take_hit(9999, Vector2.RIGHT, 0.0, true)  # one thief, so the theft is its own
	Run.purse.galder = 100
	p.invulnerable_until = 0.0
	var t := 0.0
	while thief.stolen == 0 and t < 12.0:
		Run.hp = Run.max_hp
		thief.global_position = p.global_position + Vector2(24, 0)
		await wait(0.25)
		t += 0.25
	p.invulnerable_until = p.now() + 60.0
	check(thief.stolen == thief.data.steal_galder and Run.purse.galder == 100 - thief.stolen,
		"a Thief Mong's hit steals %d Galder (%d left)" % [thief.stolen, Run.purse.galder])
	var took := thief.stolen
	thief.take_hit(9999, Vector2.RIGHT, 0.0, true)
	# Its own Galder drop comes on top of what it gives back.
	check(thief.stolen == 0 and Run.purse.galder >= 100,
		"killing the Thief Mong gives the %d Galder back (%d)" % [took, Run.purse.galder])


func _thieves() -> int:
	return enemies().filter(func(e: Enemy) -> bool: return e.data.id == BossMong.SUMMON_ID).size()
