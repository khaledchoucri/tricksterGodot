extends SmokeSection
## Elemental attack compounds and their hit effects; shields and guns.


func run() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id
	Profile.class_id = "buffalo"
	Run.new_run()
	p.refresh_gear()
	var w := Run.gear.equipped("weapon")
	var target := await _dummy(p, 60.0)
	target.elements = {}
	# A plain hit, then one with Fire and Water compounded on the weapon.
	var plain := 0
	var hp := target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	plain = hp - target.hp
	w.slots = maxi(w.slots, 2)
	w.compounds.clear()
	w.compounds.append({"material": "cocos_shell", "stat": "Fire", "value": 20})
	w.compounds.append({"material": "cool_ice", "stat": "Water", "value": 10})
	Run.stats_changed()
	target.set_meta("element_fx_at", -INF)
	hp = target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	var with_el := hp - target.hp
	var fx: Array[String] = []
	for n: Node in game.room.get_children():
		if n is Cake and (n as Cake).effect.begins_with("element_"):
			fx.append((n as Cake).effect)
	check(absf(float(with_el) / plain - 1.3) < 0.05, "Fire 20%% and Water 10%% add 30%% to the hit (%d -> %d)" % [plain, with_el])
	check("element_fire" in fx and "element_ice" in fx, "each element plays its own hit effect at once %s" % [fx])
	# Resistance takes its share off that element only; physical resistance off the hit.
	target.elements = {"Fire": 50}
	hp = target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	var resisted := hp - target.hp
	check(absf(float(resisted) / plain - 1.2) < 0.05, "50%% Fire resistance halves the Fire part (%d)" % resisted)
	target.elements = {"Physical": 40}
	w.compounds.clear()
	Run.stats_changed()
	hp = target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	check(absf(float(hp - target.hp) / plain - 0.6) < 0.05, "40%% physical resistance takes 40%% off a hit (%d)" % (hp - target.hp))
	check(target.attack_element() == "", "physical resistance is never a monster's attack element")
	var mats: Array[String] = []
	for r in Run.route.regions:
		for e in r.enemies:
			if e.material and e.material.is_element():
				mats.append(e.material.stat)
	for k: String in MaterialData.ELEMENTS:
		check(k in mats, "a monster drops a %s attack material" % k)
	_remove(target)

	# Shields and guns.
	Profile.class_id = "lion"
	Run.new_run()
	p.refresh_gear()
	var offered_shield := false
	for i in 40:
		Run.route.depth = i % 16
		for g in Run.gear.gear_offers(3):
			offered_shield = offered_shield or g.data.slot == ItemData.Slot.SHIELD
	Run.route.depth = 0
	check(not offered_shield, "a gunner is never offered a shield")
	Profile.class_id = "fox"
	Run.new_run()
	Run.deck.cards[&"gun_carrier"] = 1
	var shield := GearItem.roll(load("res://data/items/wood_buckler.tres"), 0.0)
	Run.gear.equip(shield)
	check(Run.gear.equipped("shield") == shield, "Fox wears a shield with a sword")
	Run.gear.equip(GearItem.roll(load("res://data/items/ebony_gun.tres"), 0.0))
	check(Run.gear.carries_gun() and Run.gear.equipped("shield") == null and shield in Run.gear.displaced,
		"taking up a gun puts the shield away")
	check(Run.gear.equip(shield) == null and Run.gear.equipped("shield") == null, "no shield goes on beside a gun")
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.3)
