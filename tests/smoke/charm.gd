extends SmokeSection
## The Charm line: Cat and Raccoon, the beast forms, every Charm skill.

## Map-independent checks for prepared animation and duration.
const CHARM_PREPARATION := preload("res://tests/smoke/charm_preparation.gd")


## The Charm line: Cat and Raccoon, the server's HV-weighted attacks, the
## beast forms, Galder, and every Charm skill on a dummy.
func run() -> void:
	var checks: SmokeSection = CHARM_PREPARATION.new()
	checks.runner = runner
	add_child(checks)
	checks.run()
	checks.free()
	var p: Player = game.player
	var saved: String = Profile.class_id

	Profile.class_id = "raccoon"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"raccoon" and Run.job.id == &"teacher" and p.sprite.actor_name == "raccoon",
		"Raccoon starts as a Teacher")
	Profile.class_id = "cat"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"cat" and Run.job.id == &"model" and Run.deck.card_level(&"power_blow") == 1
		and p.sprite.actor_name == "cat" and Run.cls.basic_skill == null,
		"Cat starts as a Model with Power Blow, fighting with her weapon's combo")

	# The server's attacks: Volley Kick is AP + 16 HV, so Charm points (HV)
	# grow it far more than Power Blow (AP alone); Final Blow grows with the
	# HP you've lost.
	check(is_equal_approx(Run.formulas.attack_power("AP+16HV"), Run.stat("AP") + 16.0 * Run.stat("HV")),
		"Run.formulas.attack_power reads the server's expression (AP + 16 HV = %d)" % Run.formulas.attack_power("AP+16HV"))
	var kick := Run.deck.card(&"volley_kick")
	var blow := Run.deck.card(&"power_blow")
	var final := Run.deck.card(&"final_blow")
	var kick0 := Run.formulas.skill_mult(kick)
	var blow0 := Run.formulas.skill_mult(blow)
	check(is_equal_approx(kick0, 1.0) and is_equal_approx(blow0, 1.0), "at level 1 the multipliers start at 1")
	Run.type_points["charm"] += 5  # +10 HV
	Run.stats_changed()
	var kick1 := Run.formulas.skill_mult(kick)
	check(kick1 > 1.5 and is_equal_approx(Run.formulas.skill_mult(blow), 1.0),
		"Charm points grow Volley Kick (x%.2f) but not Power Blow (x%.2f)" % [kick1, Run.formulas.skill_mult(blow)])
	Run.type_points["charm"] -= 5
	Run.stats_changed()
	var fb0 := Run.formulas.skill_mult(final)
	Run.hp = Run.max_hp / 2
	check(Run.formulas.skill_mult(final) > fb0, "Final Blow hits harder the more HP you've lost (x%.2f -> x%.2f)" % [fb0, Run.formulas.skill_mult(final)])
	Run.hp = Run.max_hp
	check(Run.formulas.skill_mult(Run.deck.card(&"wild_nail")) == Run.formulas.attack_power("16HV") / Run.formulas.attack_power("16HV", true),
		"Wild Nail is HV alone")

	# Evolution is a talent: learned, Cat is the beast (trs001) for good, with
	# no MP drain; only Evolution's skills work, and only they are offered.
	# Beast's Instinct is timed on top of it, and Evolution outlasts it.
	check(not Run.deck.card(&"evolution").is_skill(), "Evolution is a talent")
	check(not Run.deck.requirements_met(Run.deck.card(&"beast_claw")) and not Run.deck.requirements_met(Run.deck.card(&"fatal_wound")),
		"Evolution's skills aren't offered before it")
	var ap0 := Run.stat("AP")
	var dp0 := Run.stat("DP")
	Run.deck.add_card(&"evolution")
	p.become_beast()
	check(Run.form == &"evolution" and p.sprite.actor_name == "beast_evolution" and Run.stat("AP") > ap0
		and Run.stat("DP") < dp0, "Evolution turns Cat into the beast (trs001): AP %d -> %d, DP %d -> %d" % [ap0,
		Run.stat("AP"), dp0, Run.stat("DP")])
	check(p.combo == Player.BEAST_COMBO and not p.weapon.visible, "the beast fights with its claws, no weapon")
	check(Run.deck.requirements_met(Run.deck.card(&"beast_claw")) and Run.deck.requirements_met(Run.deck.card(&"fatal_wound")),
		"with it, Beast Claw and Fatal Wound open up")
	Run.mp = Run.max_mp / 2
	var mp1 := Run.mp
	await wait(1.2)
	check(Run.form == &"evolution" and Run.mp >= mp1, "Evolution never drains MP or ends (MP %d -> %d)" % [mp1, Run.mp])
	Run.mp = Run.max_mp
	for id: StringName in [&"volley_kick", &"beast_claw", &"wild_nail"]:
		Run.deck.cards[id] = 1
	Run.deck.loadout = [&"volley_kick", &"beast_claw", &"wild_nail"] as Array[StringName]
	for i in 3:
		p.skills.slot_ready_at[i] = 0.0
	check(not p.skills.try_cast(0) and Run.form_block(&"volley_kick") == "Not in Evolution",
		"Volley Kick doesn't work in Evolution")
	check(not p.skills.try_cast(2), "nor Wild Nail, Metamorphosis's")
	check(p.skills.try_cast(1), "Beast Claw does")
	await wait(0.8)
	var ent: JobData = load("res://data/jobs/entertainer.tres")
	var job_e := Run.job
	Run.jobs.append(ent)
	Run.job = ent
	var offered_e: Array[StringName] = []
	for i in 20:
		for c in Run.deck.card_offers(3, false):
			if c.is_skill():
				offered_e.append(c.id)
	var stray_e := offered_e.filter(func(id: StringName) -> bool: return not Run.form_allows(id))
	check(stray_e.is_empty(), "Evolution is only offered skills it can use: %s" % [offered_e if stray_e.is_empty() else stray_e])
	Run.jobs.erase(ent)
	Run.job = job_e
	Run.deck.cards[&"beasts_instinct"] = 1
	Run.deck.loadout[0] = &"beasts_instinct"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	check(p.skills.try_cast(0), "Beast's Instinct casts in Evolution")
	await wait(0.7)
	var ap_i := Run.stat("AP")
	check(Run.instinct and not p.skills.try_cast(1), "in Beast's Instinct, no skills (AP %d)" % ap_i)
	mp1 = Run.mp
	await wait(1.0)
	check(Run.mp < mp1, "Beast's Instinct drains MP (%d -> %d)" % [mp1, Run.mp])
	p.instinct_until = p.now()
	await wait(0.2)
	check(not Run.instinct and Run.form == &"evolution" and Run.stat("AP") < ap_i, "when it ends, Evolution stays")
	for id: StringName in [&"evolution", &"volley_kick", &"beast_claw", &"wild_nail", &"beasts_instinct"]:
		Run.deck.cards.erase(id)
	Run.deck.loadout = [&"", &"", &""] as Array[StringName]
	Run.form = &""
	Run.stats_changed()
	p.refresh_gear()
	check(p.sprite.actor_name == "cat", "back to Cat for the next checks")

	# Metamorphosis is a talent: learned, you're the beast for good, with no
	# MP drain; only beast skills work, and only they are offered.
	var meta := Run.deck.card(&"metamorphosis")
	check(not meta.is_skill(), "Metamorphosis is a talent")
	check(not Run.deck.requirements_met(Run.deck.card(&"wild_nail")) and not Run.deck.requirements_met(Run.deck.card(&"card_soldier")),
		"Metamorphosis's skills aren't offered before it")
	ap0 = Run.stat("AP")
	dp0 = Run.stat("DP")
	Run.deck.add_card(&"metamorphosis")
	p.become_beast()
	check(Run.form == &"metamorphosis" and p.sprite.actor_name == "beast_metamorphosis" and Run.stat("DP") > dp0
		and Run.stat("AP") < ap0, "Metamorphosis turns you into the beast (trs002): DP %d -> %d, AP %d -> %d" % [dp0,
		Run.stat("DP"), ap0, Run.stat("AP")])
	check(Run.deck.requirements_met(Run.deck.card(&"wild_nail")) and Run.deck.requirements_met(Run.deck.card(&"heavy_hit"))
		and Run.deck.requirements_met(Run.deck.card(&"card_soldier")), "with it, Wild Nail, Heavy Hit and Card Soldier open up")
	Run.mp = Run.max_mp / 2
	mp1 = Run.mp
	await wait(1.2)
	check(Run.form == &"metamorphosis" and Run.mp >= mp1, "it never drains MP or ends (MP %d -> %d)" % [mp1, Run.mp])
	Run.mp = Run.max_mp
	Run.deck.cards[&"card_strike"] = 1
	Run.deck.cards[&"wild_nail"] = 1
	Run.deck.loadout[0] = &"card_strike"
	Run.deck.loadout[1] = &"wild_nail"
	p.skills.slot_ready_at[0] = 0.0
	p.skills.slot_ready_at[1] = 0.0
	check(not p.skills.try_cast(0) and Run.form_block(&"card_strike") != "", "Card Strike doesn't work in Metamorphosis")
	check(p.skills.try_cast(1), "Wild Nail does")
	await wait(0.6)
	var cm: JobData = load("res://data/jobs/card_master.tres")
	var job0 := Run.job
	Run.jobs.append(cm)
	Run.job = cm
	var offered: Array[StringName] = []
	for i in 20:
		for c in Run.deck.card_offers(3, false):
			if c.is_skill():
				offered.append(c.id)
	var stray := offered.filter(func(id: StringName) -> bool: return not Run.form_allows(id))
	check(stray.is_empty() and &"wild_nail" in Run.deck.card_pool().map(func(c: CardData) -> StringName: return c.id),
		"a beast is only offered skills it can use: %s" % [offered if stray.is_empty() else stray])
	Run.jobs.erase(cm)
	Run.job = job0
	for id: StringName in [&"metamorphosis", &"card_strike", &"wild_nail"]:
		Run.deck.cards.erase(id)
	Run.deck.loadout[0] = &""
	Run.deck.loadout[1] = &""
	Run.form = &""
	Run.stats_changed()
	p.refresh_gear()

	# Galder: spent from the run's purse; short of it, no cast.
	Run.deck.cards[&"galder_thrower"] = 1
	Run.deck.loadout[0] = &"galder_thrower"
	Run.purse.galder = 5
	p.skills.slot_ready_at[0] = 0.0
	check(not p.skills.try_cast(0), "Galder Thrower needs its Galder")
	Run.purse.galder = 100
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	check(p.skills.try_cast(0) and Run.purse.galder == 80, "Galder Thrower spends 20 Galder (100 -> %d)" % Run.purse.galder)
	await wait(0.5)

	await _card_reach(p)
	await _one_pair_fan(p)
	await _full_house(p)

	# Every Charm skill does its job on a dummy.
	var skills: Array[CardData] = []
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/charm/"):
			skills.append(c)
	check(skills.size() == 27, "the Charm line has 27 active skills: %d" % skills.size())
	for c in skills:
		var kind := c.behavior.resource_path.get_file()
		var ahead := 60.0 if kind == "charm_strike.gd" else 120.0 if kind in ["card_throw.gd", "pouch_throw.gd", "galder_barrage.gd"] else 50.0
		var dummy := await _dummy(p, ahead)
		dummy.elements = {}
		var extra: Array[Enemy] = []
		if c.id == &"four_of_a_kind":
			for i in 3:
				var e2: Enemy = game.room.spawn(&"torobbie", dummy.global_position + Vector2(10 * (i + 1), 8))
				extra.append(e2)
			await wait(0.6)
			for e2 in extra:
				e2.max_hp = 99999
				e2.hp = 99999
		var before := dummy.hp
		p.end_instinct()
		Run.form = &""  # the forms don't end on their own
		Run.deck.cards.erase(&"metamorphosis")
		Run.deck.cards.erase(&"evolution")
		Run.deck.cards[c.id] = 1
		Run.deck.loadout[0] = c.id
		if c.form != &"":
			var need: StringName = c.form
			Run.form = need if need != &"beast" else &"metamorphosis"
			Run.deck.cards[Run.form] = 1
			Run.stats_changed()
		Run.mp = Run.max_mp
		Run.hp = Run.max_hp
		Run.purse.galder = 500
		p.skills.slot_ready_at[0] = 0.0
		p.invulnerable_until = p.now() + 9.0
		var hp_before := Run.hp
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
			&"beasts_instinct":
				did = Run.instinct and Run.form == &"evolution"
				how = "instinct %s" % Run.instinct
			&"flux_capacitor":
				did = Run.hp < hp_before
				how = "HP %d -> %d" % [hp_before, Run.hp]
			&"skunk_pouch", &"deadly_funk":
				did = dummy.state == Enemy.State.HURT
				how = "state %s" % dummy.state
			&"full_house":
				# One card in five is a bad hand (BAD_HAND) that hurts you instead.
				did = dummy.hp < before or Run.hp < hp_before
				how = "%d -> %d, HP %d -> %d" % [before, dummy.hp, hp_before, Run.hp]
			_:
				did = dummy.hp < before
				how = "%d -> %d" % [before, dummy.hp]
		check(cast and did, "%s casts and works (%s)%s" % [c.id, how, "" if did else _why(cast, dummy, p)])
		p.end_instinct()
		Run.form = &""
		Run.deck.cards.erase(c.id)
		for e2 in extra:
			_remove(e2)
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0
	check(Run.deck.card(&"galder_barrage") in (load("res://data/echoes/echo_entertainer.tres") as EnemyData).runes,
		"the Echo of an Entertainer lends the Charm line's own Galder Barrage")

	# Hybrids.
	var diva: JobData = load("res://data/jobs/diva.tres")
	var duke: JobData = load("res://data/jobs/duke.tres")
	check(not diva.unlocked() and not duke.unlocked(), "Diva and Duke start locked")
	check(Run.deck.card(&"card_strike") in diva.cards and Run.deck.card(&"volley_kick") in duke.cards
		and not Run.deck.card(&"evolution") in duke.cards and not Run.deck.card(&"metamorphosis") in diva.cards,
		"a Diva learns Card Master skills and a Duke Entertainer skills, but not the other's beast")

	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)


## The aimed throws reach CARD_REACH (x1.35) past the table's Range: a Lv 1
## Card Strike hits a monster at 190 px, past the original's 150.
func _card_reach(p: Player) -> void:
	var strike := Run.deck.card(&"card_strike")
	var pair := Run.deck.card(&"one_pair")
	check(is_equal_approx(strike.param("range", 1), 202.0) and is_equal_approx(pair.param("range", 5), 308.0),
		"the card throws reach 35%% past the original's Range (Card Strike Lv 1 %d, One Pair Lv 5 %d)" % [
		strike.param("range", 1), pair.param("range", 5)])
	var dummy := await _dummy(p, 190.0)
	Run.deck.cards[&"card_strike"] = 1
	Run.deck.loadout[0] = &"card_strike"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	var before := dummy.hp
	var cast := p.skills.try_cast(0)
	await wait(0.8)
	check(cast and dummy.hp < before, "a Lv 1 Card Strike hits a monster 190 px away (%d -> %d)%s" % [before, dummy.hp,
		"" if dummy.hp < before else _why(cast, dummy, p)])
	Run.deck.cards.erase(&"card_strike")
	Run.deck.loadout[0] = &""
	_remove(dummy)
	await wait(0.3)


## One Pair's cards leave together in a tight fan (the user's ~30 degrees at
## full Lady Luck), centred on the monster aimed at, which they all strike.
func _one_pair_fan(p: Player) -> void:
	var throw: GDScript = load("res://scripts/skills/card_throw.gd")
	var six: Array[float] = throw.fan_angles(6)
	var two: Array[float] = throw.fan_angles(2)
	check(is_equal_approx(rad_to_deg(six[5] - six[0]), 30.0) and is_equal_approx(rad_to_deg(two[1] - two[0]), 6.0),
		"One Pair's fan opens 6 degrees a card, 30 at six cards (%.0f, %.0f)" % [rad_to_deg(two[1] - two[0]), rad_to_deg(six[5] - six[0])])
	var dummy := await _dummy(p, 110.0)
	Run.deck.cards[&"one_pair"] = 5
	Run.deck.cards[&"lady_luck"] = 5  # 4 to 6 cards
	Run.deck.loadout[0] = &"one_pair"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	var before := dummy.hp
	var cast := p.skills.try_cast(0)
	await get_tree().physics_frame
	var angles: Array[float] = []
	var as_cards := true
	for n in game.room.get_children():
		if n is ThrownItem:
			var item := n as ThrownItem
			angles.append(Combat.ground(item.target_point - p.global_position).angle())
			as_cards = as_cards and item.cake == "eft_skl_c_301_sut" and not item.homing
	angles.sort()
	var spread := rad_to_deg(angles[-1] - angles[0]) if angles.size() > 1 else 0.0
	await wait(0.8)
	check(cast and angles.size() >= 4 and angles.size() <= 6 and spread > 10.0 and spread <= 30.5 and dummy.hp < before,
		"One Pair with Lady Luck throws %d cards together in a %.0f-degree fan, striking the monster ahead (%d -> %d)" % [
		angles.size(), spread, before, dummy.hp])
	check(as_cards, "the cards fly as the client's flying card (eft_skl_c_301_sut), each keeping to its line")
	Run.deck.cards.erase(&"one_pair")
	Run.deck.cards.erase(&"lady_luck")
	Run.deck.loadout[0] = &""
	_remove(dummy)
	await wait(0.3)


## Full House is the Gambler's (Item_SkillCardParam 4501: Job Gambler,
## One Pair 10 and Skunk Pouch 10, Lv 3 here): offered only then, it deals a
## flying card to each of up to five enemies, shows the hand over them and
## strikes (or a bad hand turns on you).
func _full_house(p: Player) -> void:
	var fh := Run.deck.card(&"full_house")
	check(fh.jobs == [&"gambler"] and fh.requires == {&"one_pair": 3, &"skunk_pouch": 3},
		"Full House is the Gambler's, after One Pair 3 and Skunk Pouch 3 (%s, %s)" % [fh.jobs, fh.requires])
	var job0 := Run.job
	var jobs0 := Run.jobs.duplicate()
	var gambler: JobData = load("res://data/jobs/gambler.tres")
	Run.jobs.append(load("res://data/jobs/card_master.tres"))
	Run.jobs.append(gambler)
	Run.job = gambler
	Run.deck.cards[&"one_pair"] = 2
	Run.deck.cards[&"skunk_pouch"] = 3
	var early := Run.deck.can_learn(fh)
	Run.deck.cards[&"one_pair"] = 3
	Run.level = Run.deck.unlock_level(fh)  # Full House is TM 150
	var offered := false
	for i in 30:
		offered = offered or fh in Run.deck.card_offers(3, false, gambler)
	Run.level = 1
	check(not early and Run.deck.can_learn(fh) and offered, "a Gambler is offered Full House once One Pair reaches Lv 3")
	var first := await _dummy(p, 70.0)
	var foes: Array[Enemy] = [first]
	for k in 4:
		var e: Enemy = game.room.spawn(&"torobbie", p.global_position + Combat.screen(Vector2.from_angle(TAU * (k + 1) / 5.0) * 70.0))
		foes.append(e)
	await wait(0.6)
	for e in foes:
		e.max_hp = 99999
		e.hp = 99999
	Run.deck.cards[&"full_house"] = 1
	Run.deck.loadout[0] = &"full_house"
	Run.mp = Run.max_mp
	Run.hp = Run.max_hp
	p.skills.slot_ready_at[0] = 0.0
	p.invulnerable_until = p.now() + 9.0
	var cast := p.skills.try_cast(0)
	await wait(0.3)
	var cards := 0
	for n in game.room.get_children():
		if n is ThrownItem and (n as ThrownItem).cake == "eft_skl_c_301_sut":
			cards += 1
	await wait(1.0)
	var struck := foes.filter(func(e: Enemy) -> bool: return e.hp < 99999).size()
	check(cast and cards == 5 and struck >= 3 and struck + (1 if Run.hp < Run.max_hp else 0) >= 4,
		"Full House deals a flying card to each of five monsters (%d cards, %d struck, HP %d/%d)" % [cards, struck, Run.hp, Run.max_hp])
	p.invulnerable_until = 0.0
	for e in foes:
		_remove(e)
	for id: StringName in [&"full_house", &"one_pair", &"skunk_pouch"]:
		Run.deck.cards.erase(id)
	Run.deck.loadout[0] = &""
	Run.jobs.assign(jobs0)
	Run.job = job0
	Run.hp = Run.max_hp
	await wait(0.3)
