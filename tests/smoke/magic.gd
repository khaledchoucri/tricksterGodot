extends SmokeSection
## The Magic line: Sheep and Dragon, casting, Seals and Pacts, every spell.


func run() -> void:
	var p: Player = game.player
	for e: Enemy in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await wait(0.5)
	p.invulnerable_until = 0.0
	check(Run.classes.size() == 8 and Run.classes.all(func(c: ClassData) -> bool: return c.unlocked()),
		"all eight characters are playable from the start")
	var saved: String = Profile.class_id

	# Sheep: Librarian, Mana Ring on the attack button, no MP.
	Profile.class_id = "sheep"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"sheep" and Run.job.id == &"librarian" and Run.deck.card_level(&"mana_ring") == 1
		and not &"mana_ring" in Run.deck.loadout and p.sprite.actor_name == "sheep",
		"Sheep starts as a Librarian with Mana Ring as her basic attack, not in a slot")
	var target := await _dummy(p, 90.0)
	var mp := Run.mp
	var hp := target.hp
	p.buffer_action("attack")
	await wait(2.5)  # the rings appear by her, then swoop in (the client's flight)
	check(target.hp < hp and Run.mp >= mp, "left click casts Mana Ring at no MP (%d -> %d, MP %d -> %d)" % [hp, target.hp, mp, Run.mp])
	var never := true
	for _i in 60:
		for c: CardData in Run.deck.card_offers(3, false):
			never = never and not c.id in [&"mana_arrow", &"arrow_rush"]
	check(never, "Sheep is never offered Mana Arrow or Arrow Rush")

	# MP regenerates for mages.
	Run.mp = 0
	await wait(1.0)
	check(Run.mp > 0, "a mage regenerates MP over time (%d after 1 s)" % Run.mp)

	# Casting: half the original Delay, locked in place, only a dash gets out.
	Run.start_job(load("res://data/jobs/bard.tres"))
	p.refresh_gear()
	Run.deck.cards[&"seal_of_water"] = 1
	Run.deck.add_card(&"drip_bomb")
	var slot := Run.deck.loadout.find(&"drip_bomb")
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[slot] = 0.0
	var at := p.global_position
	var bomb := Run.deck.card(&"drip_bomb")
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
	check(not Run.deck.can_learn(Run.deck.card(&"seal_of_fire")) and not Run.deck.can_learn(Run.deck.card(&"seal_of_earth"))
		and Run.deck.can_learn(Run.deck.card(&"seal_of_thunder")), "Seal of Water closes the Fire and Earth seals")
	check(not Run.deck.can_learn(Run.deck.card(&"whirlwind_blaze")), "without Seal of Fire, fire magic isn't offered")
	Run.deck.cards[&"seal_of_thunder"] = 1
	Run.deck.cards[&"electro_attack"] = 3
	check(not Run.deck.requirements_met(Run.deck.card(&"tesla_field")), "Sheep's Tesla Field waits for Mana Ring Lv 3")
	Run.deck.cards[&"mana_ring"] = 3
	check(Run.deck.requirements_met(Run.deck.card(&"tesla_field")), "Mana Ring Lv 3 stands in for Mana Arrow in Sheep's Tesla Field")
	Run.start_job(load("res://data/jobs/witch.tres"))
	check(Run.deck.can_learn(Run.deck.card(&"dark_pact")) and Run.deck.can_learn(Run.deck.card(&"light_pact")), "a Witch can learn Magician skills")
	Run.deck.cards[&"water_shield"] = 2
	Run.start_job(load("res://data/jobs/soul_master.tres"))
	Run.deck.add_card(&"undines_blessing")
	check(Run.deck.card_level(&"water_shield") == 0 and Run.deck.card_level(&"undines_blessing") == 2 and Run.formulas.resist("Water") > 0.0,
		"Undine's Blessing replaces the Water Shield and keeps its resistance (%d%%)" % Run.formulas.resist("Water"))
	_remove(target)

	# Dragon: Shaman, Mana Arrow, and the Priest can't learn dark magic.
	Profile.class_id = "dragon"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"dragon" and Run.job.id == &"shaman" and Run.deck.card_level(&"mana_arrow") == 1,
		"Dragon starts as a Shaman with Mana Arrow")
	never = true
	for _i in 60:
		for c: CardData in Run.deck.card_offers(3, false):
			never = never and not c.id in [&"mana_ring", &"mana_ring_booster"]
	check(never, "Dragon is never offered Mana Ring or Mana Ring Booster")
	Run.start_job(load("res://data/jobs/magician.tres"))
	Run.deck.cards[&"mana_arrow"] = 3
	Run.deck.cards[&"light_pact"] = 1
	check(Run.deck.requirements_met(Run.deck.card(&"light_wave")), "Mana Arrow stands in for Mana Ring in Dragon's Light Wave")
	Run.deck.cards.erase(&"light_pact")
	Run.start_job(load("res://data/jobs/priest.tres"))
	check(not Run.deck.can_learn(Run.deck.card(&"dark_pact")) and Run.deck.can_learn(Run.deck.card(&"light_pact")), "a Priest can't learn dark magic")
	Run.start_job(load("res://data/jobs/wizard.tres"))
	check(Run.deck.can_learn(Run.deck.card(&"seal_of_fire")), "a Wizard can learn Bard skills")

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
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/magic/") and not c.id in [&"basic_healing", &"med_cure"]:
			spells.append(c)
	check(spells.size() == 50, "the Magic line has 50 spells in play: %d" % spells.size())
	for c in spells:
		var kind := c.behavior.resource_path.get_file()
		var near := kind in ["spell_nova.gd", "spell_whisper.gd"] or c.id == &"hinder_snare"
		var dummy := await _dummy(p, 45.0 if near else 90.0)
		dummy.elements = {}
		var before := dummy.hp
		Run.deck.cards[c.id] = 1
		Run.deck.loadout[0] = c.id
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
		Run.deck.cards.erase(c.id)
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)
