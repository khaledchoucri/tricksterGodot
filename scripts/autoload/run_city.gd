class_name RunCity
extends RefCounted
## What a run takes from Megalopolis and gives back (Run.city): the restorations' systems and
## bonuses, the loadout and the warehouse, the custom Trickster, and banking the finished run.

## Trees a Trickster can pick from: every class's 2nd and 3rd jobs, and
## the other classes' trees learned through Echo runes.
const TRICKSTER_TREES: Array[String] = ["res://data/jobs/knight.tres", "res://data/jobs/boxer.tres",
	"res://data/jobs/gladiator.tres", "res://data/jobs/mercenary.tres", "res://data/jobs/champion.tres",
	"res://data/jobs/duelist.tres", "res://data/jobs/bard_tree.tres", "res://data/jobs/explorer_tree.tres",
	"res://data/jobs/entertainer_tree.tres"]

## Type graphs a Trickster can be created with (auto points per level).
const TRICKSTER_GRAPHS := {
	"Power / Charm": {"power": 0.5, "charm": 0.3, "sense": 0.1, "magic": 0.1},
	"Magic / Sense": {"magic": 0.5, "sense": 0.3, "power": 0.1, "charm": 0.1},
	"Sense / Power": {"sense": 0.45, "power": 0.35, "charm": 0.1, "magic": 0.1},
	"Charm / Magic": {"charm": 0.45, "magic": 0.35, "power": 0.1, "sense": 0.1},
	"Balanced": {"power": 0.25, "magic": 0.25, "sense": 0.25, "charm": 0.25},
}


## The custom class opens once a 3rd job has been cleared with two characters.
func trickster_unlocked() -> bool:
	var s := Profile.stats
	var buffalo := int(s.get("clears_gladiator", 0)) + int(s.get("clears_mercenary", 0))
	var bunny := int(s.get("clears_champion", 0)) + int(s.get("clears_duelist", 0))
	return buffalo > 0 and bunny > 0


func trickster_trees() -> Array[JobData]:
	var out: Array[JobData] = []
	for p in TRICKSTER_TREES:
		var j: JobData = load(p)
		out.append(j)
		for c in j.cards:
			Run.deck.registry[c.id] = c
	return out


## Builds the Trickster from Profile.custom: {"kit", "graph", "trees"}.
func build_trickster() -> ClassData:
	var spec: Dictionary = Profile.custom
	var fists: bool = spec.get("kit", "sword") == "fists"
	var c := ClassData.new()
	c.id = &"trickster"
	c.display_name = "Trickster"
	c.actor = "bunny" if fists else "buffalo"
	c.base = {}
	for k in Stats.KEYS:
		c.base[k] = int((int(Run.classes[0].base.get(k, 0)) + int(Run.classes[1].base.get(k, 0))) / 2)
	c.graph = TRICKSTER_GRAPHS.get(spec.get("graph", "Balanced"), TRICKSTER_GRAPHS.Balanced)
	c.start_weapon = Run.classes[0].start_weapon
	c.combo = Run.classes[1].combo if fists else null
	c.armed = not fists
	var j := JobData.new()
	j.id = &"trickster"
	j.display_name = "Trickster"
	j.tier = 3
	j.starter = Run.hub.trickster_starter
	j.passive = &"data_bleed"
	j.passive_name = "Data Bleed"
	j.passive_text = "Skill card rewards offer one more choice."
	j.passive_mods = {"card_choices": 1.0}
	var pool: Array[CardData] = []
	for c2 in Run.classes[0].start_job.cards:
		pool.append(c2)
	for t in trickster_trees():
		if String(t.id) in spec.get("trees", []):
			for c2 in t.cards:
				if not c2 in pool:
					pool.append(c2)
	j.cards = pool
	c.start_job = j
	return c


## Wears the loadout: each slot's item from its warehouse shelf, at full strength (decided
## with the user, 2026-10-21: no level sync, no level or weight gate).
func carry_loadout() -> void:
	if Profile.legacy_heirloom >= 0:
		var old := from_shelf(Profile.legacy_heirloom)
		if old and Profile.worn_in(Profile.legacy_heirloom) == "":
			Profile.wear_stored(Profile.legacy_heirloom, Run.gear.slot_keys_for(old.data)[0])
		Profile.legacy_heirloom = -1
	for key: String in Profile.loadout:
		var g := from_shelf(int(Profile.loadout[key]))
		if g and Run.gear.can_equip(g):
			Run.gear.equip(g, key)


## Puts the loadout on afresh after it changes in the city: the class's own weapon, then the
## loadout over it (without starting a new run, which would spend the run's seed).
func rewear_loadout() -> void:
	Run.gear.equipment = {"weapon": GearItem.make(Run.cls.start_weapon)}
	carry_loadout()
	Run.stats_changed()


## The item on warehouse shelf `index`, ready to wear: its shelf noted, so its progress
## can be saved back. Null if unknown.
func from_shelf(index: int) -> GearItem:
	if index < 0 or index >= Profile.warehouse.size():
		return null
	var g := GearItem.from_dict(Profile.warehouse[index], Run.gear.item_by_id)
	if g:
		g.stored = index
	return g


## Whether the item on shelf `index` is being worn in this run.
func worn_from_shelf(index: int) -> bool:
	return Run.gear.equipment.values().any(func(g: GearItem) -> bool: return g.stored == index)


## A rest stop's swap: puts on the item from shelf `index` and banks what it replaces
## (and a shield a gun puts away). False if it's already worn, can't go on, or a found
## item it replaces would have no free shelf.
func swap_from_shelf(index: int) -> bool:
	var g := from_shelf(index)
	if g == null or worn_from_shelf(index) or not Run.gear.can_equip(g):
		return false
	var keys := Run.gear.slot_keys_for(g.data)
	var key: String = keys[0]
	for k in keys:
		if Run.gear.equipped(k) == null:
			key = k
			break
	var old := Run.gear.equipped(key)
	var outgoing: Array[GearItem] = []
	if old:
		outgoing.append(old)
	var shield := Run.gear.equipped("shield")
	if g.data.family == "gun" and Run.deck.holds_tag(&"carries_guns") and shield:
		outgoing.append(shield)
	var needed := 0
	for item: GearItem in outgoing:
		if item.stored < 0:
			needed += 1
	if needed > Profile.warehouse_size() - Profile.warehouse.size():
		return false
	return _apply_shelf_swap(g, key, outgoing)


## Commit a preflighted swap synchronously; retain the old inventory if any bank rejects it.
func _apply_shelf_swap(g: GearItem, key: String, outgoing: Array[GearItem]) -> bool:
	var equipment: Dictionary = Run.gear.equipment.duplicate()
	var displaced: Array[GearItem] = Run.gear.displaced.duplicate()
	var shelves: Array = Profile.warehouse.duplicate(true)
	var flags: Dictionary = Profile.flags.duplicate()
	var identities: Array[int] = []
	for item: GearItem in outgoing:
		identities.append(item.stored)
	var hp: int = Run.hp
	var mp: int = Run.mp
	var blocked: bool = Events.is_blocking_signals()
	Events.set_block_signals(true)
	Run.gear.equip(g, key)
	var success := true
	for item: GearItem in outgoing:
		if not bank(item):
			success = false
			break
	if not success:
		Profile.warehouse = shelves
		Profile.flags = flags
		for i: int in outgoing.size():
			outgoing[i].stored = identities[i]
		Run.gear.equipment = equipment
		Run.gear.displaced = displaced
		Run.hp = hp
		Run.mp = mp
		Run.stats_changed()
		Profile.save()
	Events.set_block_signals(blocked)
	Events.player_hp_changed.emit()
	return success


## Sends a worn item home at a Port or rest stop: it's safe on a shelf (a stored one keeps its
## progress), and you stop wearing it for the rest of the run. Decided with the user, 2026-10-21:
## banking costs you the item's power, so carrying it stays a risk. False if the warehouse is full.
func bank(g: GearItem) -> bool:
	if g.stored >= 0:
		Profile.update_item(g.stored, g.to_dict())
	elif not save_point(g):
		return false
	Run.gear.take_off(g)
	return true


## Ours: a death saves worn pieces up to WT / SAVE_WT_DIVISOR in weight (the old equip load's ratio:
## a level-1 Buffalo's WT 300 saves 75, a ring or two; a Knight Shield alone weighs 130).
const SAVE_WT_DIVISOR := 4


## The weight of worn pieces a death saves (decided with the user, 2026-10-22: WT is what you carry,
## out of a fall too).
func save_capacity() -> int:
	return Run.stat("WT") / SAVE_WT_DIVISOR


## What a death does with each worn piece but the class's own weapon: the lightest go home while
## they fit under save_capacity(), the rest (the heaviest first) go into the bag, at least one always.
## Returns {"home": Array[GearItem], "bag": Array[GearItem]}.
func split_at_death() -> Dictionary:
	var worn: Array[GearItem] = []
	for g: GearItem in Run.gear.equipment.values():
		if not (g.stored < 0 and g.data == Run.cls.start_weapon):
			worn.append(g)
	worn.sort_custom(func(a: GearItem, b: GearItem) -> bool: return a.data.weight < b.data.weight)
	var home: Array[GearItem] = []
	var bag: Array[GearItem] = []
	var room := save_capacity()
	for g in worn:
		if home.size() < worn.size() - 1 and g.data.weight <= room:
			home.append(g)
			room -= g.data.weight
		else:
			bag.append(g)
	return {"home": home, "bag": bag}


## The lost bag (decided with the user, 2026-10-21; the original's death costs EXP, not items): on a
## death the worn pieces split_at_death() doesn't save go into a bag where you fell, stored ones off
## their shelves, progress and all; the saved ones go home with theirs (a found one onto a free shelf,
## or into the bag when the shelves are full). A new death with something to lose replaces the old bag.
## Returns {"home": names saved, "bag": names lost in the bag}.
func drop_bag(at: Vector2) -> Dictionary:
	var split := split_at_death()
	var items: Array = []
	var bagged: Array[String] = []
	var saved: Array[String] = []
	var shelves: Array[int] = []
	for g: GearItem in split.home:
		if g.stored >= 0:
			Profile.update_item(g.stored, g.to_dict())
			saved.append(g.title())
		elif Profile.store_item(g.to_dict()) >= 0:
			saved.append(g.title())
		else:
			split.bag.append(g)
	for g: GearItem in split.bag:
		items.append(g.to_dict())
		bagged.append(g.title())
		if g.stored >= 0:
			shelves.append(g.stored)
	shelves.sort()
	shelves.reverse()
	for i in shelves:
		Profile.discard_item(i)
	if not items.is_empty():
		Profile.lost_bag = {"region": Run.route.region_index(), "room": Run.route.local_depth(),
			"x": at.x, "y": at.y, "items": items}
	Profile.save()
	return {"home": saved, "bag": bagged}


## Whether the lost bag lies in the current room.
func bag_here() -> bool:
	var b := Profile.lost_bag
	return not b.is_empty() and int(b.region) == Run.route.region_index() and int(b.room) == Run.route.local_depth() \
		and Run.route.current_room().rest == null


## Picks the lost bag up: its items go back on the shelves while there's room (the rest stay in it).
## Returns the names put away.
func pick_up_bag() -> Array[String]:
	var names: Array[String] = []
	var left: Array = []
	for d: Dictionary in Profile.lost_bag.get("items", []):
		var g := GearItem.from_dict(d, Run.gear.item_by_id)
		if g and Profile.store_item(d) >= 0:
			names.append(g.title())
		else:
			left.append(d)
	if left.is_empty():
		Profile.lost_bag = {}
	else:
		Profile.lost_bag.items = left
	Profile.save()
	return names


## A clear brings home everything you wear (decided with the user, 2026-10-22): stored pieces with
## their progress, finds onto free shelves. Returns the finds that didn't fit.
func bring_home() -> Array[GearItem]:
	var left: Array[GearItem] = []
	for g: GearItem in Run.gear.equipment.values():
		if g.stored >= 0:
			Profile.update_item(g.stored, g.to_dict())
		elif g.data != Run.cls.start_weapon and not save_point(g):
			left.append(g)
	return left


## Portable Port: saves every stored item's progress, and sends `item` home
## (if given). Returns false if the warehouse is full.
func save_point(item: GearItem = null) -> bool:
	for g: GearItem in Run.gear.equipment.values():
		if g.stored >= 0:
			Profile.update_item(g.stored, g.to_dict())
	if item == null:
		return true
	var index := Profile.store_item(item.to_dict())
	if index < 0:
		return false
	Profile.set_flag("stored_any")
	item.stored = index
	return true


## Permanent bonuses from the city's restorations (Profile).
func apply_restorations() -> void:
	if Run.hub == null:
		return
	for r in Run.hub.restorations:
		var lvl := Profile.level(r.id)
		if lvl <= 0:
			continue
		match r.effect:
			"max_hp":
				Run.bonus_hp += roundi(r.per_level * lvl)
			"revive":
				Run.revives += lvl
			"second_skill":
				var pool: Array[StringName] = []
				for c in Run.deck.card_pool():
					if c.is_skill() and Run.deck.can_learn(c):
						pool.append(c.id)
				if pool.size() > 0:
					Run.deck.add_card(pool[Run.rng.randi() % pool.size()])


## Whether a city restoration has switched a system on (smithing, jobs,
## compounding, warehouse).
func system_on(id: StringName) -> bool:
	if Run.hub == null:
		return true
	for r in Run.hub.restorations:
		if r.effect == "system" and r.system == id:
			return Profile.level(r.id) > 0
	return true


## Extra MP recovered on entering a room, from restorations.
func room_mp_bonus() -> int:
	if Run.hub == null:
		return 0
	var bonus := 0
	for r in Run.hub.restorations:
		if r.effect == "room_mp":
			bonus += roundi(r.per_level * Profile.level(r.id))
	return bonus


## Banks the finished run into the profile and remembers it for the hub.
## Heat adds TM; clearing at a new best Heat pays a shard per new level.
func finish(p_won: bool) -> void:
	var reached := Run.route.depth + (1 if p_won else 0)
	var heat := ServerSettings.heat()
	Run.purse.tm += int(Run.purse.tm * heat * ServerSettings.TM_PER_HEAT)
	var bounty := 0
	if p_won and heat > Profile.best_heat:
		bounty = heat - maxi(Profile.best_heat, 0)
		Run.purse.shards += bounty
		Profile.best_heat = heat
	Run.last_result = {"won": p_won, "depth": reached, "tm": Run.purse.tm, "shards": Run.purse.shards, "heat": heat, "bounty": bounty}
	Profile.bank_run(p_won, reached, Run.purse.tm, Run.purse.shards, String(Run.job.id))
	Run.last_result.opened = p_won and Profile.clear_chunk(String(Run.cls.id), Run.route.chunk)
	Run.last_result.kept = Profile.bank_leftovers(p_won, Run.purse.galder, Run.purse.ore, Run.purse.materials)
