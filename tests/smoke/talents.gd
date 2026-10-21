extends SmokeSection
## Every Talent hook does its job (Guard's block is checked in the Power line).


## Elemental attack compounds (the server's 0x59c4a0) and their hit effects
## (the client's 0x5c69d0), and no shield beside a gun.
## Every Talent hook does its job (Guard's block is checked in the Power line).
func run() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id
	Profile.class_id = "sheep"
	Run.new_run()
	p.refresh_gear()
	var foe := await _dummy(p, 60.0)
	p.invulnerable_until = 0.0

	# tick and absorb: Shield of Heaven's barrier fills, then takes a hit first.
	Run.deck.cards[&"shield_of_heaven"] = 1
	p._tick_talents(0.016)
	var barrier := roundi(Run.stat("MA") * Run.deck.card(&"shield_of_heaven").value_at(1) / 100.0)
	check(barrier > 0 and Run.barrier == barrier, "Shield of Heaven's barrier fills to its share of MA (%d)" % Run.barrier)
	var hp := Run.hp
	p.take_hit(1, Vector2.LEFT, 0.0, false, 9999)
	check(Run.hp == hp and Run.barrier < barrier, "the barrier takes a hit before your HP (%d left)" % Run.barrier)
	Run.deck.cards.erase(&"shield_of_heaven")
	Run.barrier = 0

	# tick: Oath of Light heals every 10 s.
	Run.deck.cards[&"oath_of_light"] = 1
	Run.hp = Run.max_hp / 2
	hp = Run.hp
	for _i in 11:
		p._tick_talents(1.0)
	check(Run.hp > hp, "Oath of Light heals every 10 s (%d -> %d)" % [hp, Run.hp])
	Run.deck.cards.erase(&"oath_of_light")

	# tick: Berserker's rage costs HP while a monster is around.
	Run.deck.cards[&"berserker"] = 1
	Run.hp = Run.max_hp
	hp = Run.hp
	for _i in 3:
		p._tick_talents(1.0)
	check(Run.hp < hp, "Berserker drains HP in a fight (%d -> %d)" % [hp, Run.hp])
	Run.deck.cards.erase(&"berserker")

	# retaliate: Dark Barrier turns a physical hit back, Mana Reflector a magic one.
	for id: StringName in [&"dark_barrier", &"mana_reflector"]:
		Run.deck.cards[id] = 5
		var before := foe.hp
		for t in Run.deck.talents():
			t.retaliate(p, foe, 200, id == &"mana_reflector")
		check(foe.hp < before, "%s strikes back at the attacker (%d -> %d)" % [id, before, foe.hp])
		Run.deck.cards.erase(id)

	# revive: Revival brings you back with its share of max HP, then waits its cooldown.
	Run.deck.cards[&"revival"] = 1
	Run.revival_ready_at = 0.0
	Run.hp = 0
	var back := Run.try_revive()
	check(back and Run.hp == maxi(1, roundi(Run.max_hp * Run.deck.card(&"revival").value_at(1) / 100.0))
		and Run.revival_ready_at > Events.time, "Revival brings you back from a fatal blow (%d HP)" % Run.hp)
	Run.deck.cards.erase(&"revival")
	Run.hp = Run.max_hp

	# on_cast: Blood Testament makes a spell cost HP.
	Run.deck.cards[&"blood_testament"] = 1
	var spell: CardData = Run.deck.all_cards().filter(func(c: CardData) -> bool: return c.is_skill() and c.cast_at(1) > 0.0)[0]
	hp = Run.hp
	for t in Run.deck.talents():
		t.on_cast(spell, 1, 0)
	check(Run.hp < hp, "Blood Testament: casting %s costs HP (%d -> %d)" % [spell.id, hp, Run.hp])
	Run.deck.cards.erase(&"blood_testament")
	Run.hp = Run.max_hp

	# adjust: Desperate Rally raises your damage low on HP; Sharp Sense the power shot.
	var full := Run.formulas.attack_mult()
	Run.deck.cards[&"desperate_rally"] = 3
	Run.hp = 1
	check(Run.formulas.attack_mult() > full, "Desperate Rally hits harder near death (x%.2f -> x%.2f)" % [full, Run.formulas.attack_mult()])
	Run.deck.cards.erase(&"desperate_rally")
	Run.hp = Run.max_hp
	Run.deck.cards[&"sharp_sense"] = 1
	var keen: CardData = Run.deck.card(&"keen_sense")
	var want := (100.0 + keen.value_at(Run.deck.MAX_CARD_LEVEL)) * (1.0 + Run.deck.card(&"sharp_sense").value_at(1) / 100.0) - 100.0
	check(is_equal_approx(Run.formulas.power_shot_bonus(), want), "Sharp Sense builds on a mastered Keen Sense (+%.0f%%)" % Run.formulas.power_shot_bonus())
	Run.deck.cards.erase(&"sharp_sense")

	_remove(foe)
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.3)
