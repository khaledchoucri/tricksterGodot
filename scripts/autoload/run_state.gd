extends Node
## Everything that belongs to the current run (autoloaded as `Run`): the
## class and its current job, levels and type points, the twelve stats they
## produce with gear, skill cards, equipment and run materials. A rollback
## (death) or a cleared run resets it; the Profile banks what carries over.

signal leveled_up(new_level: int)

const REGION_PATH := "res://data/coral_beach/region.tres"
const HUB_PATH := "res://data/megalopolis/hub.tres"
const CLASS_PATH := "res://data/classes/buffalo.tres"
const ITEMS_DIR := "res://data/items/"
const MONSTERS_PATH := "res://original_assets/data/monsters.json"
const MAX_CARD_LEVEL := 5
const SLOTS := 3
## Equipment slots: the six core run-gear slots.
const EQUIP_SLOTS: Array[String] = ["weapon", "hat", "shield", "innerwear", "acc1", "acc2"]
const ORE_NAME := "Bronze Fragment"
## Offsets that soften stat ratios (a stat twice the starting value is not
## twice the effect).
const AP_SOFT := 40.0
const MA_SOFT := 50.0
const DX_SOFT := 60.0
const DEF_SOFT := 100.0

var region: RegionData
var hub: HubData
var cls: ClassData
var items: Array[ItemData] = []
var monster_data: Dictionary = {}  # original stats by monster id (generated, may be empty)

var depth := 0
var plan: Array[RoomPlan] = []
var level := 1
var xp := 0
var hp := 100
var mp := 100
var job: JobData
var jobs: Array[JobData] = []
## Type points the player chose (count toward traits).
var type_points := {"power": 0, "magic": 0, "sense": 0, "charm": 0}
var cards: Dictionary = {}  # StringName card id -> level
## Skill card ids in slots 1-3 (RMB, Q, E); &"" is an empty slot.
var loadout: Array[StringName] = [&"", &"", &""]
## EQUIP_SLOTS key -> GearItem.
var equipment: Dictionary = {}
var ore := 0
## Monster materials carried: MaterialData id -> count, and the data by id.
var materials: Dictionary = {}
var material_info: Dictionary = {}
var galder := 0
var tm := 0
var shards := 0
var kills := 0
var time := 0.0
var won := false
var pending_levels := 0
var revives := 0
var second_wind_used := false
## How the last run ended, for the hub to report: {"won", "depth", "tm", "shards"}.
var last_result: Dictionary = {}

var max_hp: int:
	get:
		return stat("HP")
var max_mp: int:
	get:
		return stat("MP")

var _bonus_hp := 0          # from restorations
var _stats: Dictionary = {}  # cache of stat totals
var _ref: Dictionary = {}    # level-1 stats this run's numbers are tuned against


## A room in this run's plan: which room, and how it's modified.
class RoomPlan:
	var data: RoomData
	var elite := false
	var boss := false
	## Monster the room's waves lean on (chosen with the door), or &"".
	var feature: StringName

	func _init(p_data: RoomData, p_elite := false, p_boss := false) -> void:
		data = p_data
		elite = p_elite
		boss = p_boss


func _ready() -> void:
	region = load(REGION_PATH)
	hub = load(HUB_PATH)
	cls = load(CLASS_PATH)
	_load_items()
	if FileAccess.file_exists(MONSTERS_PATH):
		monster_data = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))


func _load_items() -> void:
	items.clear()
	for f in DirAccess.get_files_at(ITEMS_DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			items.append(load(ITEMS_DIR + f))


func new_run() -> void:
	depth = 0
	level = 1
	xp = 0
	type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	cards = {}
	loadout = [&"", &"", &""]
	jobs.clear()
	equipment = {"weapon": GearItem.make(cls.start_weapon)}
	ore = 0
	materials = {}
	galder = 0
	tm = 0
	shards = 0
	kills = 0
	time = 0.0
	won = false
	pending_levels = 0
	revives = 0
	second_wind_used = false
	_bonus_hp = 0
	_stats.clear()
	_ref = {}
	for k in Stats.KEYS:
		_ref[k] = stat(k)
	start_job(cls.start_job)
	_apply_restorations()
	stats_changed()
	hp = max_hp
	mp = max_mp
	plan = _plan_rooms()


## Permanent bonuses from the city's restorations (Profile).
func _apply_restorations() -> void:
	if hub == null:
		return
	for r in hub.restorations:
		var lvl := Profile.level(r.id)
		if lvl <= 0:
			continue
		match r.effect:
			"max_hp":
				_bonus_hp += roundi(r.per_level * lvl)
			"revive":
				revives += lvl
			"second_skill":
				var pool: Array[StringName] = []
				for card in card_pool():
					if card.is_skill() and card_level(card.id) == 0 and requirements_met(card):
						pool.append(card.id)
				if pool.size() > 0:
					add_card(pool[randi() % pool.size()])


## Extra MP recovered on entering a room, from restorations.
func room_mp_bonus() -> int:
	if hub == null:
		return 0
	var bonus := 0
	for r in hub.restorations:
		if r.effect == "room_mp":
			bonus += roundi(r.per_level * Profile.level(r.id))
	return bonus


## Survives a fatal blow if a revive (Rollback Cache) or Second Wind is left.
func try_revive() -> bool:
	if revives > 0:
		revives -= 1
	elif has_trait(&"second_wind") and not second_wind_used:
		second_wind_used = true
	else:
		return false
	hp = maxi(1, int(max_hp * 0.3))
	Events.player_hp_changed.emit()
	return true


## Banks the finished run into the profile and remembers it for the hub.
func finish(p_won: bool) -> void:
	var reached := depth + (1 if p_won else 0)
	last_result = {"won": p_won, "depth": reached, "tm": tm, "shards": shards}
	Profile.bank_run(p_won, reached, tm, shards)


func _plan_rooms() -> Array[RoomPlan]:
	var pool := region.rooms.duplicate()
	pool.shuffle()
	var out: Array[RoomPlan] = []
	for i in region.run_length:
		out.append(RoomPlan.new(pool[i % pool.size()], i in region.elite_depths))
	out.append(RoomPlan.new(region.boss_room, false, true))
	return out


func current_room() -> RoomPlan:
	return plan[depth]


func monster_stats(enemy: EnemyData) -> Dictionary:
	return monster_data.get(enemy.monster_id, {})


# ---------------------------------------------------------------- stats

## A stat's total: class base, automatic growth along the class's type
## graph, chosen type points, gear, restorations.
func stat(key: String) -> int:
	if _stats.is_empty():
		_compute_stats()
	return _stats.get(key, 0)


func _compute_stats() -> void:
	var s := {}
	for k in Stats.KEYS:
		s[k] = float(cls.base.get(k, 0))
	for t: String in Stats.TYPE_ORDER:
		var pts: float = type_points[t] + float(cls.graph.get(t, 0.0)) * (level - 1)
		var gain: Dictionary = Stats.TYPES[t].gain
		for k: String in gain:
			s[k] += gain[k] * pts
	for g: GearItem in equipment.values():
		var gs := g.stats()
		for k: String in gs:
			s[k] = s.get(k, 0.0) + gs[k]
	s.HP += _bonus_hp
	for k: String in s:
		_stats[k] = maxi(0, floori(s[k]))


## Call after anything that changes stats (gear, points, levels).
func stats_changed() -> void:
	_stats.clear()
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)
	Events.player_hp_changed.emit()


## Spends a chosen type point. Returns the trait it unlocked, or {}.
func apply_type(type: String) -> Dictionary:
	var before := max_hp
	type_points[type] += 1
	stats_changed()
	heal(max_hp - before)
	var n := Stats.THRESHOLDS.find(type_points[type])
	return Stats.trait_at(type, n) if n >= 0 else {}


## How many of a type's traits are unlocked.
func trait_count(type: String) -> int:
	var n := 0
	for t in Stats.THRESHOLDS:
		if type_points[type] >= t:
			n += 1
	return n


func has_trait(id: StringName) -> bool:
	for type: String in Stats.TYPE_ORDER:
		for i in trait_count(type):
			if Stats.trait_at(type, i).get("id") == id:
				return true
	return false


func active_traits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for type: String in Stats.TYPE_ORDER:
		for i in trait_count(type):
			var t := Stats.trait_at(type, i)
			if not t.is_empty():
				out.append(t)
	return out


# ---------------------------------------------------------------- growth

func exp_to_next() -> int:
	return 300 + 250 * level


func gain_exp(amount: int) -> void:
	xp += amount
	while xp >= exp_to_next():
		xp -= exp_to_next()
		var before := max_hp
		level += 1
		pending_levels += 1
		stats_changed()
		heal(max_hp - before)
		leveled_up.emit(level)


func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	Events.player_hp_changed.emit()


# ---------------------------------------------------------------- jobs and cards

func start_job(j: JobData) -> void:
	job = j
	jobs.append(j)
	if j.starter and card_level(j.starter.id) == 0:
		add_card(j.starter.id)


## Whether the run has reached its job change and the job has somewhere to go.
func job_change_due() -> bool:
	return depth == region.job_change_depth and job.next_jobs.size() > 0


func has_passive(id: StringName) -> bool:
	for j in jobs:
		if j.passive == id:
			return true
	return false


## Cards the jobs taken so far can offer.
func card_pool() -> Array[CardData]:
	var out: Array[CardData] = []
	for j in jobs:
		for c in j.cards:
			if not c in out:
				out.append(c)
	return out


func requirements_met(card: CardData) -> bool:
	for id: StringName in card.requires:
		if card_level(id) < int(card.requires[id]):
			return false
	return true


## Learns a card or raises its level. A new skill goes in the first free
## slot, or in `slot` when given (replacing what was there).
func add_card(id: StringName, slot := -1) -> void:
	var is_new := card_level(id) == 0
	cards[id] = mini(card_level(id) + 1, MAX_CARD_LEVEL)
	var card := region.card(id)
	if not is_new or not card.is_skill():
		return
	if slot < 0:
		slot = loadout.find(&"")
	if slot >= 0:
		var old := loadout[slot]
		if old != &"":
			cards.erase(old)
		loadout[slot] = id


func free_slot() -> int:
	return loadout.find(&"")


func card_level(id: StringName) -> int:
	return cards.get(id, 0)


func card_value(id: StringName) -> float:
	var card := region.card(id)
	return card.value_at(card_level(id)) if card else 0.0


## Up to `n` card offers from the current jobs' trees (or only `from_job`'s):
## new cards whose prerequisites are met, or upgrades of owned ones when
## `upgrade` is true. New-card offers lean on skills: at least two of three
## while there are skills left to learn.
func card_offers(n: int, upgrade: bool, from_job: JobData = null) -> Array[CardData]:
	var skills: Array[CardData] = []
	var talents: Array[CardData] = []
	for card in (from_job.cards if from_job else card_pool()):
		var lvl := card_level(card.id)
		if (upgrade and lvl > 0 and lvl < MAX_CARD_LEVEL) or (not upgrade and lvl == 0 and requirements_met(card)):
			(skills if card.is_skill() else talents).append(card)
	skills.shuffle()
	talents.shuffle()
	var out: Array[CardData] = []
	if upgrade:
		out.append_array(skills + talents)
		out.shuffle()
		return out.slice(0, n)
	var want_skills := mini(skills.size(), maxi(n - 1, 0) if talents.size() > 0 else n)
	out.append_array(skills.slice(0, want_skills))
	out.append_array(talents.slice(0, n - out.size()))
	out.append_array(skills.slice(want_skills, want_skills + n - out.size()))
	out.shuffle()
	return out


# ---------------------------------------------------------------- equipment

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


## Puts an item on (in the first free fitting slot unless `slot_key` is
## given) and returns what it replaced, or null.
func equip(item: GearItem, slot_key := "") -> GearItem:
	if slot_key == "":
		var keys := slot_keys_for(item.data)
		slot_key = keys[0]
		for k in keys:
			if not equipment.has(k):
				slot_key = k
				break
	var old: GearItem = equipment.get(slot_key)
	var before := max_hp
	equipment[slot_key] = item
	stats_changed()
	if max_hp > before:
		heal(max_hp - before)
	return old


func weapon_family() -> String:
	var w := equipped("weapon")
	return w.data.family if w else "sword"


func equip_load() -> int:
	var total := 0
	for g: GearItem in equipment.values():
		total += g.data.weight
	return total


func load_limit() -> int:
	return stat("WT") / 4


func overweight() -> bool:
	return equip_load() > load_limit()


## Up to `n` different items that can drop at this depth, rolled with DA.
func gear_offers(n: int) -> Array[GearItem]:
	var pool: Array[ItemData] = []
	for it in items:
		if it.level <= 1 + 3 * depth and it != cls.start_weapon:
			pool.append(it)
	pool.shuffle()
	var out: Array[GearItem] = []
	var quality := clampf(stat("DA") / 60.0, 0.0, 1.0)
	for it in pool.slice(0, n):
		out.append(GearItem.roll(it, quality))
	return out


func refine_chance(g: GearItem) -> float:
	var c := g.refine_chance() + stat("LK") / 1000.0
	if has_trait(&"smiths_eye"):
		c += 0.1
	return clampf(c, 0.0, 0.99)


func can_afford_refine(g: GearItem) -> bool:
	var cost := g.refine_cost()
	return g.can_refine() and ore >= cost.ore and galder >= cost.galder


## One refine attempt: "success", "fail" or "drop" (failed from +4 or more
## and lost a level). Pays the cost either way.
func try_refine(g: GearItem, roll := -1.0) -> String:
	var cost := g.refine_cost()
	ore -= cost.ore
	galder -= cost.galder
	if roll < 0.0:
		roll = randf()
	var result := "fail"
	if roll < refine_chance(g):
		g.refine += 1
		result = "success"
	elif g.refine >= 4 and randf() < 0.5:
		g.refine -= 1
		result = "drop"
	stats_changed()
	return result


# ---------------------------------------------------------------- combat numbers

func _berserk_mult() -> float:
	return 1.0 + card_value(&"berserker") / 100.0 if hp * 2 < max_hp else 1.0


func _ratio(key: String, soft: float) -> float:
	return (stat(key) + soft) / (float(_ref.get(key, 0)) + soft)


## Damage multiplier for the basic combo.
func attack_mult() -> float:
	var m := _ratio("AP", AP_SOFT) * _berserk_mult()
	if has_passive(&"sword_mastery") and weapon_family() == "sword":
		m *= 1.15
	return m


## Damage multiplier for a skill, from the stat it scales with.
func skill_mult(card: CardData = null) -> float:
	var scaling := card.scaling if card else "AP"
	var m := _ratio(scaling, AP_SOFT if scaling == "AP" else MA_SOFT)
	return m * _berserk_mult()


func skill_cooldown_mult() -> float:
	return 1.0 / _ratio("MA", MA_SOFT)


func attack_speed_mult() -> float:
	return _ratio("DX", DX_SOFT) * (1.0 + card_value(&"hyper_beat") / 100.0)


func speed_mult() -> float:
	return 0.85 if overweight() else 1.0


func dash_cooldown_mult() -> float:
	return 1.3 if overweight() else 1.0


func crit_chance() -> float:
	return 0.03 + stat("LK") / 250.0 + card_value(&"bulls_eye") / 100.0


## Damage taken: DP against physical hits, MD against magic.
func damage_taken_mult(magic := false) -> float:
	var key := "MD" if magic else "DP"
	var m := (float(_ref.get(key, 0)) + DEF_SOFT) / (stat(key) + DEF_SOFT)
	return m * (1.0 - card_value(&"guard") / 100.0)


## Chance to evade an attack from a monster with accuracy `ac`.
func evade_chance(ac: int) -> float:
	var hv := stat("HV")
	var c := hv / float(hv + ac + 150)
	if has_trait(&"light_feet"):
		c += 0.08
	return minf(c, 0.6)


func mp_per_hit() -> int:
	return 8 if has_trait(&"mana_flow") else 5


func gain_mp(amount: int) -> void:
	mp = mini(mp + amount, max_mp)


## Pays for a skill. With Overcast, missing MP is paid in HP (never fatal).
func spend_mp(amount: int) -> bool:
	if mp >= amount:
		mp -= amount
		return true
	var hp_cost := (amount - mp) * 2
	if has_trait(&"overcast") and hp > hp_cost:
		mp = 0
		take_damage(hp_cost)
		return true
	return false


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	Events.player_hp_changed.emit()


## Rewards for a kill. Returns what dropped: {"ore": n, "material":
## MaterialData or null, "count": n}.
func add_kill(exp_amount: int, tm_amount: int, galder_amount: int, elite := false, boss := false,
		mat: MaterialData = null, mat_chance := 0.0) -> Dictionary:
	kills += 1
	tm += tm_amount
	galder += int(galder_amount * (1.0 + stat("LK") / 100.0))
	var found := 0
	if boss:
		found = 3
	elif elite or randf() < 0.12 + stat("DA") / 400.0:
		found = 1
	ore += found
	var count := 0
	if mat:
		if boss:
			count = 3
		elif elite:
			count = 2
		elif randf() < mat_chance + stat("DA") / 200.0:
			count = 1
		add_material(mat, count)
	if card_level(&"adrenaline") > 0:
		heal(int(card_value(&"adrenaline")))
	gain_exp(exp_amount)
	return {"ore": found, "material": mat if count > 0 else null, "count": count}


# ---------------------------------------------------------------- materials and compounding

func add_material(mat: MaterialData, count: int) -> void:
	if count <= 0:
		return
	material_info[mat.id] = mat
	materials[mat.id] = materials.get(mat.id, 0) + count


func material_count(mat: MaterialData) -> int:
	return materials.get(mat.id, 0)


## Materials carried with enough for one compound.
func compoundable_materials() -> Array[MaterialData]:
	var out: Array[MaterialData] = []
	for id: StringName in materials:
		var m: MaterialData = material_info[id]
		if materials[id] >= m.need:
			out.append(m)
	return out


## Equipped items with a free compound slot (slot keys).
func compound_targets() -> Array[String]:
	var out: Array[String] = []
	for k in EQUIP_SLOTS:
		var g := equipped(k)
		if g and g.free_slots() > 0:
			out.append(k)
	return out


func compound(g: GearItem, mat: MaterialData) -> Dictionary:
	materials[mat.id] -= mat.need
	var c := g.compound(mat, clampf(stat("DA") / 60.0, 0.0, 1.0))
	stats_changed()
	return c


## Elemental attack from all equipped gear: element -> value.
func element_attack() -> Dictionary:
	var out := {}
	for g: GearItem in equipment.values():
		var el := g.elements()
		for k: String in el:
			out[k] = out.get(k, 0) + el[k]
	return out


# ---------------------------------------------------------------- shop

## What a shop sells this visit: {"kind", "price", ...}.
func shop_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in gear_offers(2):
		out.append({"kind": "gear", "item": g, "price": 160 + 24 * g.data.level + 50 * g.slots})
	out.append({"kind": "ore", "count": 3, "price": 180})
	var mats: Array[MaterialData] = []
	for e in region.enemies:
		if e.material and depth >= e.min_depth and not e.is_boss:
			mats.append(e.material)
	if mats.size() > 0:
		var m: MaterialData = mats[randi() % mats.size()]
		out.append({"kind": "material", "material": m, "count": m.need, "price": 70 * m.need})
	out.append({"kind": "potion", "heal": 0.4, "price": 160})
	return out
