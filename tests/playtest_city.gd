class_name PlaytestCity
extends RefCounted
## The playtest bot between runs (tests/playtest.gd): it buys what the city can afford, invests
## banked leftovers in the stored gear it wears and in a starting skill, and wears the best stored
## item for each slot, as a player would.

var bot: Node


func _init(p_bot: Node) -> void:
	bot = p_bot


## Between runs, invest banked leftovers in the worn stored gear and in a starting
## skill, as a player would: the bot masters the first skill it can start
## with as far as it can, and carries it.
func city_craft() -> void:
	if Run.city.system_on(&"mastery"):
		for c in Run.deck.all_cards():
			if not Run.deck.can_start_with(c):
				continue
			while Run.deck.can_master(c):
				Run.deck.master_card(c)
				print("   mastered %s (starts at Lv %d)" % [c.display_name, Run.deck.start_level(c.id)])
			if Run.deck.start_level(c.id) > 0:
				Profile.start_skills[String(Run.cls.id)] = String(c.id)
				break
	if not Run.city.system_on(&"warehouse"):
		return
	for h: int in Profile.loadout.values():
		_invest(h)


## Refines and compounds a worn stored item in the city while the odds are fair.
func _invest(h: int) -> void:
	for _i in 6:
		var g := GearItem.from_dict(Profile.warehouse[h], Run.gear.item_by_id)
		if not Run.gear.can_city_refine(g) or g.refine_chance() < 0.45:
			break
		print("   city refine %s: %s" % [g.title(), Run.gear.city_refine(h)])
	for id: String in Profile.materials.keys():
		var m := Run.purse.material_by_id(StringName(id))
		var g := GearItem.from_dict(Profile.warehouse[h], Run.gear.item_by_id)
		if m and g.free_slots() > 0 and int(Profile.materials[id]) >= m.need:
			var c := Run.gear.city_compound(h, m)
			print("   city compound %s into %s: %s +%d" % [m.display_name, g.title(), c.stat, c.value])


## Between runs, buy whatever the city can afford, in the guide's order,
## then claim card sets and buy wardrobe pieces (worn if the slot is free).
func restore_city() -> void:
	for r: RestorationData in Run.hub.restorations:
		while Profile.can_buy(r):
			Profile.buy(r)
			print("   restored %s (%d TM, %d shards left)" % [r.display_name, Profile.tm, Profile.shards])
	if not Run.city.system_on(&"cards"):
		return
	for s in Run.hub.card_sets:
		if s.complete() and not s.claimed():
			Profile.set_flag("set_" + String(s.id))
			_take(s.reward, "claimed")
	for w in Run.hub.wardrobe:
		if w.price_tm > 0 and not Profile.owns(w.id) and Profile.tm >= w.price_tm and Profile.shards >= w.price_shards:
			Profile.tm -= w.price_tm
			Profile.shards -= w.price_shards
			_take(w, "bought")
	print("   cards %d, wardrobe %s" % [Profile.cards.size(), Profile.worn])


func _take(w: WardrobeData, how: String) -> void:
	Profile.give_wardrobe(w.id)
	if not Profile.worn.has(w.slot):
		Profile.wear(w.slot, w.id)
	print("   %s %s" % [how, w.display_name])


## Between runs, wear the best stored item for each slot (as a player would).
func choose_loadout() -> void:
	var order: Array[int] = []
	for i in Profile.warehouse.size():
		var g := GearItem.from_dict(Profile.warehouse[i], Run.gear.item_by_id)
		if g and Run.gear.can_use(g.data):
			order.append(i)
	var score := func(i: int) -> float: return bot._score(GearItem.from_dict(Profile.warehouse[i], Run.gear.item_by_id))
	order.sort_custom(func(a: int, b: int) -> bool: return score.call(a) > score.call(b))
	Profile.loadout = {}
	for i in order:
		var g := GearItem.from_dict(Profile.warehouse[i], Run.gear.item_by_id)
		for k in Run.gear.slot_keys_for(g.data):
			if not Profile.loadout.has(k):
				Profile.loadout[k] = i
				print("   wearing %s next" % g.title())
				break
	Profile.save()
