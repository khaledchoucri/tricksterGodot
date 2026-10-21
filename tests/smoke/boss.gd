extends SmokeSection
## The bosses (the Golden Mole, Tombeth), a lingering spell, death and the rollback, then Megalopolis.


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
	check(boss != null and game.room.data.map == "map_dg11b", "boss room loads the Dark Cave with the Golden Mole")
	if boss:
		boss.take_hit(int(boss.max_hp * 0.36), Vector2.RIGHT, 0.0, true)
		await wait(1.3)
		check(enemies().size() >= 3, "boss summons Torobbies below 66%% HP (%d enemies)" % enemies().size())

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
	check(Run.max_hp == Run.stat("HP") and Run.bonus_hp == 15, "restorations apply to the next run (max HP %d)" % Run.max_hp)
	var reach: float = Combat.ground(hub.room.nearest_reachable(Run.hub.gate_position) - hub.gate.global_position).length()
	check(reach < 1.0, "the expedition gate stands on reachable ground")
	hub.queue_free()
