class_name RunGear
extends RefCounted
## Your gear (Run.gear): what's equipped, refining and compounding it, its weight, guns and the shop.

## Equipment slots: the six core run-gear slots.
const EQUIP_SLOTS: Array[String] = ["weapon", "hat", "shield", "innerwear", "acc1", "acc2"]
## EQUIP_SLOTS key -> GearItem.
var equipment: Dictionary = {}


func equipped(slot_key: String) -> GearItem:
	return equipment.get(slot_key)


## Equipment slot keys an item can go in.
func slot_keys_for(data: ItemData) -> Array[String]:
	match data.slot:
		ItemData.Slot.WEAPON: return ["weapon"]
		ItemData.Slot.HAT: return ["hat"]
		ItemData.Slot.SHIELD: return ["shield"]
		ItemData.Slot.INNERWEAR: return ["innerwear"]
	return ["acc1", "acc2"]


## What the last equip() put away besides the item it replaced: a shield, when
## a gun is taken up ("a loaded gun can't share your hands with a shield").
var displaced: Array[GearItem] = []


## Whether `item` can go on now: no shield while a gun is carried.
func can_equip(item: GearItem) -> bool:
	return not (item.data.slot == ItemData.Slot.SHIELD and carries_gun())


## Puts an item on (in the first free fitting slot unless `slot_key` is
## given) and returns what it replaced, or null.
func equip(item: GearItem, slot_key := "") -> GearItem:
	displaced = []
	if not can_equip(item):
		return null
	if slot_key == "":
		var keys := slot_keys_for(item.data)
		slot_key = keys[0]
		for k in keys:
			if not equipment.has(k):
				slot_key = k
				break
	var old: GearItem = equipment.get(slot_key)
	var before := Run.max_hp
	equipment[slot_key] = item
	if carries_gun() and equipment.has("shield"):
		displaced.append(equipment["shield"])
		equipment.erase("shield")
	Run.stats_changed()
	if Run.max_hp > before:
		Run.heal(Run.max_hp - before)
	return old


## City refining costs this many times a run anvil's Galder.
const CITY_COST := 3


func city_refine_cost(g: GearItem) -> Dictionary:
	var cost := g.refine_cost()
	cost.galder *= CITY_COST
	return cost


func can_city_refine(g: GearItem) -> bool:
	var cost := city_refine_cost(g)
	return g.can_refine() and Profile.ore >= cost.ore and Profile.galder >= cost.galder


## Marx refines stored item `index` with banked Galder and ore: "success",
## "fail" or "drop". Saves the item.
func city_refine(index: int, roll := -1.0) -> String:
	var g := GearItem.from_dict(Profile.warehouse[index], item_by_id)
	var cost := city_refine_cost(g)
	Profile.ore -= cost.ore
	Profile.galder -= cost.galder
	var result := "fail"
	if (Run.rng.randf() if roll < 0.0 else roll) < g.refine_chance():
		g.refine += 1
		result = "success"
	elif g.refine >= 4 and Run.rng.randf() < 0.5:
		g.refine -= 1
		result = "drop"
	Profile.update_item(index, g.to_dict())
	return result


## Paul compounds a banked material into stored item `index`. Returns the compound.
func city_compound(index: int, mat: MaterialData) -> Dictionary:
	var g := GearItem.from_dict(Profile.warehouse[index], item_by_id)
	Profile.materials[String(mat.id)] = int(Profile.materials.get(String(mat.id), 0)) - mat.need
	var c := g.compound(mat)
	Profile.update_item(index, g.to_dict())
	return c


## Whether an equipped legend has this effect.
func legend_on(effect: StringName) -> bool:
	for g: GearItem in equipment.values():
		if g.data.legend and g.data.legend_effect == effect:
			return true
	return false


func weapon_family() -> String:
	var w := equipped("weapon")
	return w.data.family if w else "sword"


func equip_load() -> int:
	var total := 0
	for g: GearItem in equipment.values():
		total += g.data.weight
	return total


func load_limit() -> int:
	return Run.stat("WT") / 4


func overweight() -> bool:
	return equip_load() > load_limit()


## Up to `n` different items that can drop at this depth, rolled with DA.
## Whether this class can use a weapon: guns need Gun Carrier; a gunner
## (Lion, who starts with one) fights with guns only.
func can_use(it: ItemData) -> bool:
	var gunner := Run.cls.start_weapon != null and Run.cls.start_weapon.family == "gun"
	if it.slot == ItemData.Slot.SHIELD:
		return not gunner and not carries_gun()  # a gun needs both hands
	if it.slot != ItemData.Slot.WEAPON:
		return true
	if it.family == "gun":
		return Run.deck.holds_tag(&"carries_guns")
	return not gunner


func gear_offers(n: int) -> Array[GearItem]:
	var pool: Array[ItemData] = []
	var top := 1 + 3 * Run.route.depth
	for it in items:
		if it.level <= top and it.level >= top - 24 and not it.legend and it != Run.cls.start_weapon and can_use(it):
			pool.append(it)
	Run.shuffle(pool)
	var out: Array[GearItem] = []
	var quality := clampf(Run.stat("DA") / 60.0, 0.0, 1.0)
	for it: ItemData in pool.slice(0, n):
		out.append(GearItem.roll(it, quality))
	return out


func refine_chance(g: GearItem) -> float:
	var c := g.refine_chance() + Run.stat("LK") / 1000.0
	c += Run.mod("refine_chance")
	return clampf(c, 0.0, 0.99)


func can_afford_refine(g: GearItem) -> bool:
	var cost := g.refine_cost()
	return g.can_refine() and Run.purse.ore >= cost.ore and Run.purse.galder >= cost.galder


## One refine attempt: "success", "fail" or "drop" (failed from +4 or more
## and lost a level). Pays the cost either way.
func try_refine(g: GearItem, roll := -1.0) -> String:
	var cost := g.refine_cost()
	Run.purse.ore -= cost.ore
	Run.purse.galder -= cost.galder
	if roll < 0.0:
		roll = Run.rng.randf()
	var result := "fail"
	if roll < refine_chance(g):
		g.refine += 1
		result = "success"
	elif g.refine >= 4 and Run.rng.randf() < 0.5:
		g.refine -= 1
		result = "drop"
	Run.stats_changed()
	return result


## Whether the equipped weapon is a gun you can use: Gun Carrier (Lion
## starts with it; Fox can learn it), as the client's "Gun_NotEquippable".
func carries_gun() -> bool:
	var w := equipped("weapon")
	return w != null and w.data.family == "gun" and Run.deck.holds_tag(&"carries_guns")


## Equipped items with a free compound slot (slot keys).
func compound_targets() -> Array[String]:
	var out: Array[String] = []
	for k in EQUIP_SLOTS:
		var g := equipped(k)
		if g and g.free_slots() > 0:
			out.append(k)
	return out


func compound(g: GearItem, mat: MaterialData) -> Dictionary:
	Run.purse.materials[mat.id] -= mat.need
	var c := g.compound(mat, clampf(Run.stat("DA") / 60.0 * (1.0 + Run.mod("compound%") / 100.0), 0.0, 1.0))
	Run.stats_changed()
	return c


## Elemental attack from all equipped gear: element -> value.
func element_attack() -> Dictionary:
	var out := {}
	for g: GearItem in equipment.values():
		var el := g.elements()
		for k: String in el:
			out[k] = out.get(k, 0) + el[k]
	return out


## What a shop sells this visit: {"kind", "price", ...}.
func shop_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cut := Run.mod_factor("shop_discount%", true)
	for g in gear_offers(2):
		out.append({"kind": "gear", "item": g, "price": int((160 + 24 * g.data.level + 50 * g.slots) * cut)})
	out.append({"kind": "ore", "count": 3, "price": int(180 * cut)})
	var mats: Array[MaterialData] = []
	for e in Run.route.region.enemies:
		if e.material and Run.route.local_depth() >= e.min_depth and not e.is_boss:
			mats.append(e.material)
	if mats.size() > 0:
		var m: MaterialData = mats[Run.rng.randi() % mats.size()]
		out.append({"kind": "material", "material": m, "count": m.need, "price": int(70 * m.need * cut)})
	out.append({"kind": "potion", "heal": 0.4, "price": int(160 * cut)})
	return out


const ITEMS_DIR := "res://data/items/"
var items: Array[ItemData] = []


func load_items() -> void:
	items.clear()
	for f in DirAccess.get_files_at(ITEMS_DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			items.append(load(ITEMS_DIR + f))


func item_by_id(id: StringName) -> ItemData:
	for it in items:
		if it.id == id:
			return it
	return null
