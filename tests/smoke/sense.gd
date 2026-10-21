extends SmokeSection
## The Sense line: Fox and Lion, the gun's cycle, every Sense skill.


## The Sense line: Fox and Lion, the gun's cycle, every Sense skill.
func run() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id

	# Fox: Archeologist, Shuriken Master on the attack button, no MP.
	Profile.class_id = "fox"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"fox" and Run.job.id == &"archeologist" and Run.deck.card_level(&"shuriken_master") == 1
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
	check(Run.cls.id == &"lion" and Run.job.id == &"engineer" and Run.deck.card_level(&"gun_carrier") > 0
		and Run.gear.carries_gun() and gun.has_gun(), "Lion starts as an Engineer carrying a gun (Gun Carrier)")
	check(Run.deck.card_level(&"quick_reload") > 0 and Run.deck.card_level(&"overcharge") == 0 and not gun.charges(),
		"Lion starts with Quick Reload; the power gauge waits for Overcharge")
	check(gun.range() > 300.0, "the gun outranges the spells (%d)" % gun.range())
	var basic_hit := Run.formulas.GUN_SHOT * Run.formulas.gun_shot_mult()
	var weakest := INF
	for id: StringName in [&"power_shot", &"double_shot", &"butt_plate", &"shooting_spree", &"berserk"]:
		var c := Run.deck.card(id)
		var per_hit := c.value_at(1) * Run.formulas.skill_mult(c) / maxf(c.param("count", 1, 1.0), 1.0)
		weakest = minf(weakest, per_hit)
	check(weakest > basic_hit, "every gun skill outhits a basic shot (weakest %d vs %d)" % [weakest, basic_hit])
	var reload := gun.reload_time()
	check(is_equal_approx(reload, 120.0 / 90.0), "the Old Ebony Gun reloads in 120000/GaugeSpeed ms (%.2f s)" % reload)
	target = await _dummy(p, 120.0)
	p.invulnerable_until = p.now() + 30.0  # a monster's hit would reset the reload
	for e: Enemy in game.room.enemies:
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
	Run.deck.cards[&"invincible_reload"] = 1
	gun.progress = 100.0
	gun.interrupt(true)
	check(gun.progress == 100.0, "Invincible Reload keeps the reload through a hit")
	Run.deck.cards.erase(&"invincible_reload")
	await wait(0.5)
	Run.deck.cards.erase(&"quick_reload")  # Lion's starter: walking keeps the reload
	p.enter(Player.State.MOVE)
	gun.progress = 100.0
	Input.action_press("move_right")
	await wait(0.3)
	var moved := gun.progress
	Input.action_release("move_right")
	Run.deck.cards[&"quick_reload"] = 1
	gun.progress = 100.0
	Input.action_press("move_right")
	await wait(0.3)
	Input.action_release("move_right")
	check(moved < 50.0 and gun.progress > 100.0,
		"walking resets the reload (%.0f), not with Quick Reload (%.0f)" % [moved, gun.progress])
	Run.deck.cards[&"speedloader"] = 5
	check(gun.reload_time() < reload, "Speedloader shortens the reload (%.2f -> %.2f s)" % [reload, gun.reload_time()])
	check(is_equal_approx(gun.reload_time(), reload / (1.0 + Run.deck.card_value(&"speedloader") / 100.0)),
		"Speedloader raises the fill rate as the client does (2 - Ratio/100)")
	Run.deck.cards.erase(&"speedloader")
	check(Run.deck.grows_basic(Run.deck.card(&"quick_reload")) and Run.deck.grows_basic(Run.deck.card(&"invincible_reload")),
		"a gunner is always offered Quick Reload and Invincible Reload once learnable")
	var ac0 := Run.formulas.gun_stat_mult()
	Run.type_points["power"] += 5  # +10 AC
	Run.stats_changed()
	check(is_equal_approx(Run.formulas.gun_stat_mult(), Run.formulas.gun_attack() / float(Run.ref_stats["AC"])) and Run.formulas.gun_stat_mult() > ac0,
		"gun damage scales with AC (the server's gun formula): x%.2f -> x%.2f" % [ac0, Run.formulas.gun_stat_mult()])
	Run.type_points["power"] -= 5
	Run.stats_changed()
	# The power zone, with Overcharge.
	gun.state = GunCycle.State.LOADED
	gun.power = float(gun.gun.zone) + 5.0
	check(gun.fire() and not gun.last_power, "without Overcharge there is no power shot")
	Run.deck.cards[&"overcharge"] = 1
	gun.state = GunCycle.State.LOADED
	gun.power = float(gun.gun.zone) + 5.0
	check(gun.fire() and gun.last_power, "with Overcharge, a shot fired above PowStartPoint is overcharged")
	Run.deck.cards.erase(&"overcharge")
	# A gun skill fires without a load and leaves the reload alone.
	gun.progress = 60.0
	Run.deck.cards[&"power_shot"] = 1
	Run.deck.loadout[0] = &"power_shot"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	var fired := p.skills.try_cast(0)
	await wait(0.4)
	check(fired and gun.state == GunCycle.State.RELOADING and gun.progress >= 60.0,
		"Power Shot fires mid-reload and doesn't reset it (%.0f)" % gun.progress)
	Run.deck.cards.erase(&"power_shot")
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
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/sense/") and c.id != &"gun_shot" \
				and not c.id in [&"stone_shower"]:
			skills.append(c)
	for c in skills:
		var kind := c.behavior.resource_path.get_file()
		var dummy := await _dummy(p, 60.0 if kind == "close_strike.gd" else 90.0)
		dummy.elements = {}
		var before := dummy.hp
		Run.deck.cards[c.id] = 1
		Run.deck.loadout[0] = c.id
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
		Run.deck.cards.erase(c.id)
		Run.hidden = false
		Run.bunker_until = 0.0
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0

	# Hybrids, as in the Magic line.
	var hunter_lord: JobData = load("res://data/jobs/hunter_lord.tres")
	var cyber: JobData = load("res://data/jobs/cyber_hunter.tres")
	check(not hunter_lord.unlocked() and not cyber.unlocked(), "Hunter Lord and Cyber Hunter start locked")
	check(Run.deck.card(&"power_shot") in hunter_lord.cards and Run.deck.card(&"fan_of_knives") in cyber.cards,
		"a Hunter Lord learns Inventor skills and a Cyber Hunter Explorer skills")

	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)
