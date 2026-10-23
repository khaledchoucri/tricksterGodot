extends SmokeSection
## The bosses (Master Mong, Tutankhamen, Tombeth) and their bars, a lingering spell, death and
## the rollback, then Megalopolis.


## The boss room, a lingering spell, death and the rollback, then Megalopolis.
func run() -> void:
	var Run := run_state()
	await clear_room()
	var boss := await _boss_room(0)
	check(boss is BossMong and game.room.data.map == "map_dg11b" and boss.display_name == "Master Mong",
		"the Coral Beach boss is Master Mong, in the Dark Cave (%s)" % (boss.display_name if boss else "no boss"))
	if boss is BossMong:
		await _master_mong(boss as BossMong)

	await _boss_bar()
	await _tutankhamen()
	await _tombeth()

	# A monster spell (Magic Meltdown) cuts your MA for a while, shown on the HUD, then wears off.
	var ma: int = Run.stat("MA")
	Run.apply_debuff("MA", 30.0, 0.5, "Magic Meltdown")
	game.hud.refresh(game.player)
	var label: Label = game.hud.get_node("%DebuffLabel")
	check(absi(Run.stat("MA") - roundi(ma * 0.7)) <= 1, "Magic Meltdown cuts your MA by 30%% (%d -> %d)" % [ma, Run.stat("MA")])
	check(label.visible and label.text.contains("Magic Meltdown"), "the HUD shows it (%s)" % label.text)
	await wait(0.7)
	game.hud.refresh(game.player)
	check(Run.stat("MA") == ma and not label.visible, "and it wears off (%d)" % Run.stat("MA"))

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
	await wait(Boss.STAGGER_FOR + 1.0)
	check(mong.bars == 3 and mong.bars_left() == 2 and mong.is_shielded() and int(mong.stats.MD) == roundi(mong.base_md * 1.19),
		"at 2/3 HP Mong loses a life and raises Mana Shield, MD +19%% (%d lives, %s)" % [mong.bars_left(), mong.casts])
	mong.take_hit(int(mong.max_hp * 0.16), Vector2.RIGHT, 0.0, true)
	await wait(Boss.STAGGER_FOR + 1.5)
	check(called[0] == mong.summon_start + mong.summon_half,
		"at half HP Mong calls %d more Thief Mongs (%d in all, %d standing)" % [mong.summon_half, called[0], _thieves()])
	check(mong.casts.get("ring", 0) == 0, "Mana Ring waits for his last life (%s)" % mong.casts)
	mong.take_hit(int(mong.max_hp * 0.2), Vector2.RIGHT, 0.0, true)
	var low := mong.hp
	mong.global_position = game.room.nearest_reachable(p.global_position + Vector2(90, 0))
	await wait(Boss.STAGGER_FOR + (BossMong.HEAL_EVERY + BossMong.HEAL_CAST) * (mong.heal_casts + 1))
	check(mong.bars_left() == 1 and mong.casts.get("ring", 0) >= 1 and mong.hp > low,
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


## Loads the boss room of `region` (or the last region's) and waits for its boss to step in.
func _boss_room(region: int) -> Boss:
	var Run := run_state()
	await clear_room()
	Run.route.depth = Run.route.plan.find_custom(func(p: RoomPlan) -> bool:
		return p.region == Run.route.regions[region] and p.boss)
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	game._load_room()
	for _i in 40:
		await wait(0.2)
		for e: Enemy in enemies():
			if e is Boss:
				game.player.invulnerable_until = game.player.now() + 999.0
				return e
	return null


## The boss bar's art: one gauge colour per lives left, as the client's MonsterHPInfoUI.nri.
func _boss_bar() -> void:
	var bar: BossHpBar = game.hud.get_node("%BossBar")
	var want: Array[Color] = [Color8(255, 0, 0), Color8(255, 206, 0), Color8(0, 206, 0), Color8(24, 156, 255), Color8(189, 41, 255)]
	var seen: PackedStringArray = []
	for i in 6:
		var tex := bar.gauge_texture(i)
		var c := tex.get_image().get_pixel(10, 3) if tex else Color.BLACK
		seen.append(c.to_html(false))
		if not c.is_equal_approx(want[mini(i, 4)]):
			seen.append("<- wrong")
	check(not "<- wrong" in seen, "boss bars are red, yellow, green, blue, purple by lives left (%s)" % ", ".join(seen))
	bar.set_hp("Test", 500, 1000, 4)
	check(bar.layer() == 1 and absf(bar.fill() - 1.0) < 0.01,
		"500 of 1000 HP in four bars is a full yellow bar over the red (layer %d, fill %.2f)" % [bar.layer(), bar.fill()])
	bar.set_hp("Test", 100, 1000, 4)
	check(bar.layer() == 0 and absf(bar.fill() - 0.4) < 0.01, "and 100 is the red bar 40%% full (%.2f)" % bar.fill())


## Tutankhamen: four bars, his Mads and their spells on him, a stagger as a bar breaks, and two
## Sphinxes at half HP.
func _tutankhamen() -> void:
	var tut := await _boss_room(1) as BossTutankhamen
	check(tut != null, "the Desert Beach boss room has Tutankhamen")
	if tut == null:
		return
	var bar: BossHpBar = game.hud.get_node("%BossBar")
	check(tut.bars == 4 and bar.layer() == 3, "Tutankhamen has four bars, blue on top (%d, layer %d)" % [tut.bars, bar.layer()])
	var card := game.hud.boss_intro()
	check(card != null and (card.get_child(0) as Label).text == tut.display_name, "his name card shows as he steps in")
	await wait(4.5)
	var roles := {}
	for role: StringName in [&"spirit", &"barrier", &"mender"]:
		roles[role] = tut.minion(role) != null
	check(not false in roles.values(), "he calls his Mad Lieutenant, Sergeant and Captain (%s)" % roles)
	check(tut.is_empowered() and tut.has_shield(), "the Lieutenant's Mad Spirit and the Sergeant's Mana Shield are on him (%s, %s)"
		% [tut.is_empowered(), tut.has_shield()])
	var before := tut.hp
	tut.take_hit(300, Vector2.RIGHT, 0.0, true)
	check(tut.hp > before - 300, "the Mana Shield soaks his hits (%d of 300 got through)" % (before - tut.hp))
	tut._barrier = 0
	tut.hp = tut.bar_top() - 200
	tut._cure_at = 0.0
	before = tut.hp
	await wait(0.2)
	check(tut.hp > before, "the Captain's M Cure heals him (%d -> %d)" % [before, tut.hp])
	tut.take_hit(int(tut.hp - tut.bar_hp * 1.98), Vector2.RIGHT, 0.0, true)
	await wait(0.1)
	check(tut.state == Enemy.State.HURT and tut.lives_left == 1 and bar.layer() == 1,
		"losing bars staggers him and the bar drops to yellow (lives %d, layer %d)" % [tut.lives_left, bar.layer()])
	await wait(Boss.STAGGER_FOR + 1.8)
	var sphinxes := enemies().filter(func(e: Enemy) -> bool: return e.data.id == &"sphinx")
	check(sphinxes.size() == 2, "at half his HP he calls two Sphinxes (%d)" % sphinxes.size())
	if not sphinxes.is_empty():
		var sx: Enemy = sphinxes[0]
		check(float(sx.stats.MD) > float(tut.stats.MD) and sx.damage >= tut._base_damage * 0.6,
			"Sphinxes resist magic and hit hard (MD %d, hit %d)" % [sx.stats.MD, sx.damage])


## Tombeth: four bars, Sturdy Shield, Mana Reflector's 10 s on 30, and the rage at half HP with
## his leap and the X of falling rocks.
func _tombeth() -> void:
	var Run := run_state()
	var tb := await _boss_room(Run.route.regions.size() - 1) as BossTombeth
	check(tb != null and game.room.data.map == "map_dg03e" and Run.route.final_boss(),
		"the last boss room is the Trident Maze with Tombeth")
	if tb == null:
		return
	check(tb.bars == 4, "Tombeth has four bars (%d)" % tb.bars)
	var before := tb.hp
	tb.take_hit(100, Vector2.RIGHT, 0.0, true)
	check(before - tb.hp == 50, "Sturdy Shield halves his hits (%d of 100)" % (before - tb.hp))
	tb.take_hit(int((tb.hp - tb.bar_hp * 2.9) / 0.5), Vector2.RIGHT, 0.0, true)
	await wait(Boss.STAGGER_FOR + 0.6)
	check(tb.reflecting() and absf(tb.reflect_until - tb.now() - 10.0) < 1.0 and absf(tb.reflect_ready_at - tb.now() - 30.0) < 1.0,
		"from his second bar Mana Reflector holds 10 s on a 30 s cooldown (%.1f, %.1f)"
		% [tb.reflect_until - tb.now(), tb.reflect_ready_at - tb.now()])
	game.player.invulnerable_until = 0.0
	var hp_before: int = Run.hp
	before = tb.hp
	tb.take_hit(100, Vector2.RIGHT, 0.0, true, {"magic": true})
	check(Run.hp < hp_before and before - tb.hp < 50, "a spell on him comes partly back (%d to you, %d to him)"
		% [hp_before - Run.hp, before - tb.hp])
	game.player.invulnerable_until = game.player.now() + 999.0
	await wait(1.0)
	var chimus := enemies().filter(func(e: Enemy) -> bool: return e.data.id == &"chimu").size()
	check(chimus >= 1, "Tombeth calls Chimu as he loses a bar (%d)" % chimus)
	var speed := tb.run_speed
	var dp: float = tb.stats.DP
	tb.take_hit(int((tb.hp - tb.bar_hp * 1.9) / 0.5), Vector2.RIGHT, 0.0, true)
	await wait(Boss.STAGGER_FOR + 0.3)
	check(tb.enraged and not tb.shielded() and tb.run_speed > speed and float(tb.stats.DP) < dp,
		"at half HP he rages: faster, the shield gone, his DP down (%s, %.0f -> %.0f, DP %d -> %d)"
		% [tb.enraged, speed, tb.run_speed, dp, tb.stats.DP])
	var x := tb.x_pattern(Vector2.ZERO)
	var diagonal := x.all(func(p: Dictionary) -> bool:
		var g := Combat.ground(p.at)
		return is_zero_approx(absf(g.x) - absf(g.y)))
	check(x.size() == 13 and diagonal, "his slam drops 13 rocks on an X across the floor (%d)" % x.size())
	tb._slam_at = 0.0
	var sample := await _sample_rocks(get_tree(), game.room.world, game.room.ground_fx)
	check(sample.x >= 1 and sample.y == sample.x,
		"the rocks fall with a mark on the ground under each (%d rocks, %d marked)" % [sample.x, sample.y])


## Sample during flight instead of after a fixed delay that can outlast the rocks.
## Ours: 90 physics frames allow 1.5 s at the smoke suite's fixed 60 fps for a slam to start.
static func _sample_rocks(tree: SceneTree, world: Node, ground: Node) -> Vector2i:
	for frame: int in 90:
		await tree.physics_frame
		var sample := _rocks_with_marks(world, ground)
		if sample.x > 0:
			return sample
	return Vector2i.ZERO


## Check that each airborne rock has a warning at its landing position.
static func _rocks_with_marks(world: Node, ground: Node) -> Vector2i:
	var sample := Vector2i.ZERO
	for child: Node in world.get_children():
		if not child is FallingRock:
			continue
		sample.x += 1
		for mark: Node in ground.get_children():
			if mark is Telegraph and (mark as Node2D).global_position.is_equal_approx((child as Node2D).global_position):
				sample.y += 1
				break
	return sample
