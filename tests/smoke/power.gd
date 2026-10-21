extends SmokeSection
## The Power line: every Power attack and echo rune, job changes, upgrade skills and its talents.


## Every Power-line attack and echo rune casts and damages a monster in front of Buffalo.
func attacks() -> void:
	var Run := run_state()
	var room: Room = game.room
	var player: Player = game.player
	# Every Power-line attack casts and damages a monster in front of Buffalo.
	check(Run.deck.loadout[0] == Run.cls.start_job.starter.id, "the run starts with %s in slot 1" % Run.cls.start_job.starter.id)
	var skill_ids: Array[StringName] = []
	for card: CardData in Run.deck.all_cards():
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
		Run.deck.cards[id] = 1
		Run.deck.loadout[0] = id
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
		Run.deck.take_rune(c)
		Run.mp = Run.max_mp
		Run.purse.galder = 500
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
	Run.deck.rune = null
	player.invulnerable_until = 0.0
	Run.deck.cards = {Run.cls.start_job.starter.id: 1}
	Run.deck.loadout.assign([Run.cls.start_job.starter.id, &"piercing_wave", &"shockwave"])
	Run.deck.cards[&"piercing_wave"] = 2
	Run.deck.cards[&"shockwave"] = 1
	Run.deck.add_card(&"tornado_bomb", 1)
	check(Run.deck.loadout[1] == &"tornado_bomb" and Run.deck.card_level(&"piercing_wave") == 0,
		"a new skill can replace a slotted one")
	Run.deck.loadout.assign([Run.cls.start_job.starter.id, &"", &""])
	Run.deck.cards = {Run.cls.start_job.starter.id: 1}
	Run.pending_levels = 0  # the dummies' EXP shouldn't queue level-ups for the checks below
	Run.xp = 0


func rules() -> void:
	var p: Player = game.player
	for e: Enemy in enemies():
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
	var tempest: CardData = Run.deck.card(&"tempest_strike")
	check(tempest.upgrades == &"lacerator" and not Run.deck.can_learn(tempest), "Tempest Strike needs Lacerator in hand")
	Run.deck.add_card(&"lacerator")
	Run.deck.cards[&"lacerator"] = 3
	check(Run.deck.can_learn(tempest) and Run.deck.can_learn(Run.deck.card(&"tidal_slash")), "Lacerator Lv 3 opens Tempest Strike and Tidal Slash")
	var at := Run.deck.loadout.find(&"lacerator")
	Run.deck.add_card(&"tempest_strike")
	check(Run.deck.loadout[at] == &"tempest_strike" and Run.deck.card_level(&"lacerator") == 0 and Run.deck.card_level(&"tempest_strike") == 3,
		"Tempest Strike takes Lacerator's slot and level, replacing it")
	check(not Run.deck.can_learn(Run.deck.card(&"tidal_slash")), "with Lacerator gone, Tidal Slash is no longer offered")
	Run.deck.cards[&"tempest_strike"] = 2
	var gale_offered := false
	for _i in 30:
		for c: CardData in Run.deck.card_offers(3, false, load("res://data/jobs/gladiator.tres")):
			gale_offered = gale_offered or c.id == &"gale_strike"
	check(not gale_offered, "Gale Strike isn't offered before Tempest Strike Lv 3")
	Run.deck.cards[&"tempest_strike"] = 3
	Run.start_job(load("res://data/jobs/gladiator.tres"))
	check(Run.deck.can_learn(Run.deck.card(&"gale_strike")), "Tempest Strike Lv 3 opens Gale Strike for the Gladiator")
	Run.deck.add_card(&"piercing_wave")
	Run.deck.cards[&"piercing_wave"] = 3
	Run.deck.add_card(&"earthquake_blade")
	check(Run.deck.card_level(&"piercing_wave") == 0 and Run.deck.known_level(&"piercing_wave") == 3
		and Run.deck.requirements_met(Run.deck.card(&"lightning_strike")),
		"Earthquake Blade replaces Piercing Wave and still opens Lightning Strike")
	check(Run.deck.card_cap(&"guard_break") == 1 and not Run.deck.can_master(Run.deck.card(&"guard_break")),
		"Guard Break stays at Lv 1, as in the original")

	# Talents with the original effects.
	Run.new_run()
	var ap: int = Run.stat("AP")
	Run.deck.add_card(&"pumping_heart")
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
	Run.deck.add_card(&"shockvibe")
	Run.deck.add_card(&"armor_breaker")
	Run.deck.add_card(&"suffocate")
	p.deal_hit(target, 10.0, 1.0, 0.0, false)
	check(target.accuracy() < acc or acc == 0, "Shockvibe lowers a hit monster's accuracy (%d -> %d)" % [acc, target.accuracy()])
	check(target.defense_mult() >= defense and not target.can_hide(), "Armor Breaker lowers its DP; Suffocate keeps it from hiding")
	Run.deck.add_card(&"guard")
	p._tick_talents(0.016)
	hp = Run.hp
	p.invulnerable_until = 0.0
	p.take_hit(20, Vector2.LEFT, 0.0, false, 9999)
	check(Run.hp == hp and Run.guard_blocks == 0, "Guard blocks a physical hit outright")
	p.invulnerable_until = 0.0
	p.take_hit(20, Vector2.LEFT, 0.0, true, 9999)
	check(Run.hp < hp, "Guard doesn't block magic")
	Run.deck.add_card(&"clinch_release")
	Run.deck.loadout[1] = &"clinch_release"
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
