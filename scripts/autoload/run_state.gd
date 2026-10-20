extends Node
## Everything that belongs to the current run (autoloaded as `Run`): the
## class and its current job, levels and type points, the twelve stats they
## produce with gear, skill cards, equipment and run materials. A rollback
## (death) or a cleared run resets it; the Profile banks what carries over.

signal leveled_up(new_level: int)

## Regions a run passes through, in order; the last one's boss ends it.
const REGION_PATHS: Array[String] = ["res://data/coral_beach/region.tres", "res://data/desert_beach/region.tres"]
const HUB_PATH := "res://data/megalopolis/hub.tres"
const CLASS_PATHS: Array[String] = ["res://data/classes/buffalo.tres", "res://data/classes/bunny.tres",
	"res://data/classes/sheep.tres", "res://data/classes/dragon.tres",
	"res://data/classes/fox.tres", "res://data/classes/lion.tres",
	"res://data/classes/cat.tres", "res://data/classes/raccoon.tres"]
const ITEMS_DIR := "res://data/items/"
const MONSTERS_PATH := "res://original_assets/data/monsters.json"
const MAX_CARD_LEVEL := 5
## Master Louis raises a card's cap this many times at most.
const MAX_MASTERY := 3
const SLOTS := 3
## Guard (1107): blocks left, and when the next spent one returns.
var guard_blocks := 0
var guard_back_at := 0.0
## Shield of Heaven (2218): the barrier's HP, and when a broken one returns.
var barrier := 0
var barrier_back_at := 0.0
## Revival (2221): when it can bring you back again.
var revival_ready_at := 0.0
## Equipment slots: the six core run-gear slots.
const EQUIP_SLOTS: Array[String] = ["weapon", "hat", "shield", "innerwear", "acc1", "acc2"]
## Echoes of other classes that can haunt elite rooms after the first clear.
const ECHO_PATHS: Array[String] = ["res://data/echoes/echo_bard.tres", "res://data/echoes/echo_explorer.tres",
	"res://data/echoes/echo_entertainer.tres"]
const ORE_NAME := "Bronze Fragment"
## Offsets that soften stat ratios (a stat twice the starting value is not
## twice the effect).
const AP_SOFT := 40.0
const MA_SOFT := 50.0
const DX_SOFT := 60.0
const DEF_SOFT := 100.0

var regions: Array[RegionData] = []
## The region of the room the run is in.
var region: RegionData:
	get:
		return plan[depth].region if depth < plan.size() else regions[0]
var hub: HubData
var cls: ClassData
var classes: Array[ClassData] = []
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
## The sky-blue rune's borrowed skill (slot 4, key F) and its level.
var rune: CardData
var rune_level := 0
var echoes: Array[EnemyData] = []
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
## Hide (Thief Master): monsters lose you until it ends.
var hidden := false
## The beast form Evolution or Metamorphosis turned you into (&"" when none),
## and Beast's Instinct on top of Evolution (the player times it). Both
## forms are talents: learned, one is your form for the rest of the run.
var form: StringName = &""
var instinct := false
var hidden_until := 0.0
## Bunker (Scientist): dug in until this time or until its HP runs out.
var bunker_until := 0.0
var bunker_hp := 0
var _baseline := false


## A room in this run's plan: which room, and how it's modified.
class RoomPlan:
	var data: RoomData
	var region: RegionData
	## Depth within its region (elites, the trial and monster unlocks use it).
	var local_depth := 0
	var elite := false
	var boss := false
	## Monster the room's waves lean on (chosen with the door), or &"".
	var feature: StringName

	func _init(p_data: RoomData, p_region: RegionData, p_local := 0, p_elite := false, p_boss := false) -> void:
		data = p_data
		region = p_region
		local_depth = p_local
		elite = p_elite
		boss = p_boss


func _ready() -> void:
	for p in REGION_PATHS:
		regions.append(load(p))
	hub = load(HUB_PATH)
	for p in CLASS_PATHS:
		classes.append(load(p))
	cls = classes[0]
	_index_cards()
	_load_items()
	for p in ECHO_PATHS:
		var e: EnemyData = load(p)
		echoes.append(e)
		for c in e.runes:
			_cards[c.id] = c
	if FileAccess.file_exists(MONSTERS_PATH):
		monster_data = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))


var _cards: Dictionary = {}  # card id -> CardData, from every region and job


func _index_cards() -> void:
	for r in regions:
		for c in r.cards:
			_cards[c.id] = c
	var jobs_left: Array[JobData] = []
	for c in classes:
		jobs_left.append(c.start_job)
	while not jobs_left.is_empty():
		var j: JobData = jobs_left.pop_back()
		for c in j.cards:
			_cards[c.id] = c
		if j.starter:
			_cards[j.starter.id] = j.starter
		jobs_left.append_array(j.next_jobs)


func card(id: StringName) -> CardData:
	return _cards.get(id)


## An enemy from any region (or an Echo).
func enemy(id: StringName) -> EnemyData:
	for r in regions:
		var e := r.enemy(id)
		if e:
			return e
	for e in echoes:
		if e.id == id:
			return e
	return null


func _load_items() -> void:
	items.clear()
	for f in DirAccess.get_files_at(ITEMS_DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			items.append(load(ITEMS_DIR + f))


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
			_cards[c.id] = c
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
		c.base[k] = int((int(classes[0].base.get(k, 0)) + int(classes[1].base.get(k, 0))) / 2)
	c.graph = TRICKSTER_GRAPHS.get(spec.get("graph", "Balanced"), TRICKSTER_GRAPHS.Balanced)
	c.start_weapon = classes[0].start_weapon
	c.combo = classes[1].combo if fists else null
	c.armed = not fists
	var j := JobData.new()
	j.id = &"trickster"
	j.display_name = "Trickster"
	j.tier = 3
	j.starter = card(&"shockwave")
	j.passive = &"data_bleed"
	j.passive_name = "Data Bleed"
	j.passive_text = "Skill card rewards offer one more choice."
	var pool: Array[CardData] = []
	for c2 in classes[0].start_job.cards:
		pool.append(c2)
	for t in trickster_trees():
		if String(t.id) in spec.get("trees", []):
			for c2 in t.cards:
				if not c2 in pool:
					pool.append(c2)
	j.cards = pool
	c.start_job = j
	return c


## The class chosen in the Profile (falls back to the first).
func chosen_class() -> ClassData:
	if Profile.class_id == "trickster" and trickster_unlocked() and not Profile.custom.is_empty():
		return build_trickster()
	for c in classes:
		if String(c.id) == Profile.class_id and c.unlocked():
			return c
	return classes[0]


func new_run() -> void:
	hidden = false
	hidden_until = 0.0
	bunker_until = 0.0
	bunker_hp = 0
	cls = chosen_class()
	depth = 0
	level = 1
	xp = 0
	type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	cards = {}
	loadout = [&"", &"", &""]
	jobs.clear()
	equipment = {"weapon": GearItem.make(cls.start_weapon)}
	ore = 0
	rune = null
	rune_level = 0
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
	guard_blocks = 0
	guard_back_at = 0.0
	barrier = 0
	barrier_back_at = 0.0
	revival_ready_at = 0.0
	_bonus_hp = 0
	form = &""
	instinct = false
	_stats.clear()
	_ref = {}
	_baseline = true  # numbers are tuned against the bare level-1 character
	for k in Stats.KEYS:
		_ref[k] = stat(k)
	_baseline = false
	_stats.clear()
	start_job(cls.start_job)
	for id in cls.start_cards:
		if card_level(id) == 0:
			add_card(id)
	_carry_heirloom()
	_apply_restorations()
	stats_changed()
	hp = max_hp
	mp = max_mp
	plan = _plan_rooms()


## Equips the heirloom chosen in the warehouse, level-synced to the region.
func _carry_heirloom() -> void:
	if not system_on(&"warehouse") or Profile.heirloom < 0 or Profile.heirloom >= Profile.warehouse.size():
		return
	var g := GearItem.from_dict(Profile.warehouse[Profile.heirloom], item_by_id)
	if g == null:
		return
	g.stored = Profile.heirloom
	g.refine_cap = regions[0].refine_cap
	g.sync_level = sync_level()
	equip(g, "acc1" if g.data.slot == ItemData.Slot.ACCESSORY else "")


## The item level gear is synced to at this depth (drops use the same scale).
func sync_level() -> int:
	return 3 + 3 * depth


## Re-syncs carried heirlooms to the current depth and region (on entering a room).
func sync_heirlooms() -> void:
	for g: GearItem in equipment.values():
		if g.sync_level >= 0:
			g.sync_level = sync_level()
			g.refine_cap = region.refine_cap
	stats_changed()


func item_by_id(id: StringName) -> ItemData:
	for it in items:
		if it.id == id:
			return it
	return null


## Portable Port: saves every stored item's progress, and sends `item` home
## (if given). Returns false if the warehouse is full.
func save_point(item: GearItem = null) -> bool:
	for g: GearItem in equipment.values():
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


## Stored items changed since the last save (what a rollback would undo).
func unsaved_changes() -> Array[String]:
	var out: Array[String] = []
	for g: GearItem in equipment.values():
		if g.stored < 0 or g.stored >= Profile.warehouse.size():
			continue
		var saved := GearItem.from_dict(Profile.warehouse[g.stored], item_by_id)
		if saved == null or JSON.stringify(saved.to_dict()) != JSON.stringify(g.to_dict()):
			out.append(g.title())
	return out


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
				for c in card_pool():
					if c.is_skill() and can_learn(c):
						pool.append(c.id)
				if pool.size() > 0:
					add_card(pool[randi() % pool.size()])


## Whether a city restoration has switched a system on (smithing, jobs,
## compounding, warehouse).
func system_on(id: StringName) -> bool:
	if hub == null:
		return true
	for r in hub.restorations:
		if r.effect == "system" and r.system == id:
			return Profile.level(r.id) > 0
	return true


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
	if ServerSettings.hardcore():
		return false
	# Revival (Priest line): light brings you back, on its own cooldown.
	if card_level(&"revival") > 0 and Events.time >= revival_ready_at:
		revival_ready_at = Events.time + card(&"revival").param("cooldown", 1)
		hp = maxi(1, roundi(max_hp * card_value(&"revival") / 100.0))
		Events.player_hp_changed.emit()
		return true
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
## Heat adds TM; clearing at a new best Heat pays a shard per new level.
func finish(p_won: bool) -> void:
	var reached := depth + (1 if p_won else 0)
	var heat := ServerSettings.heat()
	tm += int(tm * heat * ServerSettings.TM_PER_HEAT)
	var bounty := 0
	if p_won and heat > Profile.best_heat:
		bounty = heat - maxi(Profile.best_heat, 0)
		shards += bounty
		Profile.best_heat = heat
	last_result = {"won": p_won, "depth": reached, "tm": tm, "shards": shards, "heat": heat, "bounty": bounty}
	Profile.bank_run(p_won, reached, tm, shards, String(job.id))
	if system_on(&"warehouse"):
		last_result.kept = Profile.bank_leftovers(p_won, galder, ore, materials)


func _plan_rooms() -> Array[RoomPlan]:
	var out: Array[RoomPlan] = []
	for r in regions:
		var pool := r.rooms.duplicate()
		pool.shuffle()
		for i in r.run_length:
			out.append(RoomPlan.new(pool[i % pool.size()], r, i, i in r.elite_depths))
		out.append(RoomPlan.new(r.boss_room, r, r.run_length, false, true))
	return out


func current_room() -> RoomPlan:
	return plan[depth]


func local_depth() -> int:
	return plan[depth].local_depth if depth < plan.size() else depth


func region_index() -> int:
	return regions.find(region)


## Whether the current room's boss ends the run (the last region's).
func final_boss() -> bool:
	return current_room().boss and region == regions[regions.size() - 1]


# ---------------------------------------------------------------- monster curve

## A normal monster at the median of its region, in room 1: effective HP
## (what it takes to kill through its DP) and damage per hit. The sword's
## first three hits (130 at x1.0) kill it; it lands 6% of a starting HP bar.
const MOB_EHP := 128.0
const MOB_HIT := 12.5
## Per room of depth: effective HP and damage growth. A par build's damage
## grows faster than this (about x4 by room 16 against x2.8), so gear and
## builds shorten fights instead of only keeping pace.
const DEPTH_EHP := 0.12
const DEPTH_HIT := 0.07
## How much of a monster's original toughness and hit strength (relative to
## its region's median) survives: 1 keeps the spread, 0 flattens it.
const SPREAD_EHP := 0.7
const SPREAD_HIT := 0.6
const MAX_HIT_SPREAD := 2.5

var _norms := {}


static func raw_ehp(s: Dictionary) -> float:
	return float(s.get("HP", 100)) * (100.0 + float(s.get("DP", 0))) / 100.0


static func raw_hit(s: Dictionary) -> float:
	return 6.0 + float(s.get("AP", 4)) * 0.25


## The median effective HP and hit of a region's regular monsters.
func region_norm(r: RegionData) -> Dictionary:
	if _norms.has(r):
		return _norms[r]
	var ehp: Array[float] = []
	var hit: Array[float] = []
	var dp: Array[float] = []
	var md: Array[float] = []
	for e in r.enemies:
		if e.is_boss or e.echo or e.min_depth >= 99:
			continue
		var s := Stats.from_monster(monster_stats(e).get("stats", {}))
		ehp.append(raw_ehp(s))
		hit.append(raw_hit(s))
		dp.append(float(s.get("DP", 0)))
		md.append(float(s.get("MD", 0)))
	for a: Array[float] in [ehp, hit, dp, md]:
		a.sort()
	_norms[r] = {"ehp": ehp[ehp.size() / 2] if ehp.size() else 250.0, "hit": hit[hit.size() / 2] if hit.size() else 11.0,
		"DP": dp[dp.size() / 2] if dp.size() else 0.0, "MD": md[md.size() / 2] if md.size() else 0.0}
	return _norms[r]


## Effective HP of a monster with original stats `s` in region `r` at `depth`
## under the old depth curve (kept for Echoes and balance probes).
func mob_ehp(s: Dictionary, r: RegionData, at_depth: int) -> float:
	var rel := raw_ehp(s) / float(region_norm(r).ehp)
	return MOB_EHP * r.hp_scale * pow(rel, SPREAD_EHP) * (1.0 + DEPTH_EHP * at_depth)


## Original HP times this is a monster's HP here. Monsters are as tough as
## their original level makes them, not as deep as the room is: deeper rooms
## bring the region's higher-level monsters (as the original maps do), and a
## growing character outgrows them.
const MOB_HP_SCALE := 0.55


## HP of a monster with original stats `s` in region `r`.
func mob_hp(s: Dictionary, r: RegionData) -> float:
	return float(s.get("HP", 100)) * MOB_HP_SCALE * r.hp_scale


## A monster's hit, from its original AP (raw_hit) like its HP: the same in
## every room, so HP and DP gained along the way are felt. Bosses' original
## AP is far above their region's, so a hit is capped at MAX_HIT_SPREAD
## times the region's median.
const MOB_HIT_SCALE := 1.15


func mob_hit(s: Dictionary, r: RegionData) -> int:
	var raw := minf(raw_hit(s), float(region_norm(r).hit) * MAX_HIT_SPREAD)
	return maxi(1, roundi(MOB_HIT_SCALE * r.damage_scale * raw))


func monster_name(enemy: EnemyData) -> String:
	if enemy == null:
		return ""
	if enemy.display_name != "":
		return enemy.display_name
	return monster_stats(enemy).get("name", String(enemy.id).capitalize())


func monster_stats(enemy: EnemyData) -> Dictionary:
	if enemy == null:
		return {}
	if not enemy.stats_override.is_empty():
		return enemy.stats_override
	return monster_data.get(enemy.monster_id, {})


## Whether an Echo joins this elite room (after the first clear).
func echo_here() -> EnemyData:
	if not current_room().elite or int(Profile.stats.get("clears", 0)) < 1 or randf() > 0.45:
		return null
	return echoes[randi() % echoes.size()]


## Takes a sky-blue rune: its skill goes in slot 4, stronger in later regions.
func take_rune(c: CardData) -> void:
	rune = c
	rune_level = 1 + 2 * region_index()
	for e in echoes:
		if c in e.runes:
			Profile.stats["runes_" + String(e.id)] = int(Profile.stats.get("runes_" + String(e.id), 0)) + 1
			Profile.save()


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
		var pts: float = type_points[t] + auto_points(t)
		var gain: Dictionary = Stats.TYPES[t].gain
		for k: String in gain:
			s[k] += gain[k] * pts
	for g: GearItem in equipment.values():
		var gs := g.stats()
		for k: String in gs:
			s[k] = s.get(k, 0.0) + gs[k]
	s.HP += _bonus_hp
	for w in ([] if _baseline else worn_pieces()):
		for k: String in w.stats:
			s[k] = s.get(k, 0.0) + w.stats[k]
	# Buffs, always on (Trickster's are timed casts).
	s.AP *= 1.0 + (card_value(&"pumping_heart") + card_value(&"adrenaline")) / 100.0
	s.AC *= 1.0 + (card_value(&"bulls_eye") + card_value(&"eagle_eye")) / 100.0
	s.MA *= 1.0 + (card_value(&"mist_of_mana") + card_value(&"blood_testament")) / 100.0
	s.DA *= 1.0 + card_value(&"sixth_sense") / 100.0
	s.LK *= 1.0 + (card_value(&"lucky_seven") + card_value(&"aura_of_luck")) / 100.0
	s.WT += card_value(&"heavy_carrier")
	s.HV *= 1.0 + card_value(&"dodge_master") / 100.0
	s.DP *= 1.0 + (card_value(&"shield_all") + card_value(&"sturdy_shield")) / 100.0
	s.HP += card_value(&"physical_training")
	_form_stats(s)
	var guard := card(&"light_shield").param("guard", card_level(&"light_shield")) if card(&"light_shield") else 0.0
	s.MD *= 1.0 + (card_value(&"mana_shield") + guard) / 100.0
	s.DP *= 1.0 + guard / 100.0
	s.MP += card_value(&"bottle_of_mana")
	for k: String in s:
		_stats[k] = maxi(0, floori(s[k]))


## The beast forms' stat changes (ESAction_WildMutation, _Change, _Beast):
## Evolution multiplies AP and takes DP, HV and LK away; Metamorphosis the
## reverse; Beast's Instinct sharpens Evolution further. DX is attack speed.
func _form_stats(s: Dictionary) -> void:
	if form == &"":
		return
	var c := card(form)
	var lvl := maxi(card_level(form), 1)
	var gain := c.value_at(lvl) / 100.0
	var loss := c.param("loss", lvl) / 100.0
	if form == &"evolution":
		var ap := 1.0 + gain
		if instinct and card(&"beasts_instinct"):
			var il := maxi(card_level(&"beasts_instinct"), 1)
			ap = 1.0 + card(&"beasts_instinct").value_at(il) / 100.0
			loss = card(&"beasts_instinct").param("loss", il) / 100.0
		s.AP *= ap
		s.DP *= 1.0 - loss
		s.HV *= 1.0 - loss
		s.LK *= 1.0 - loss
	else:
		s.DP *= 1.0 + gain
		s.HV *= 1.0 + gain
		s.AP *= 1.0 - loss
		s.LK *= 1.0 - loss


## Attack speed in a beast form: the table's DX change, 8% a point (the
## Hyper Beat reading).
func form_speed_mult() -> float:
	if form == &"":
		return 1.0
	var dx := card(form).param("dx", maxi(card_level(form), 1))
	if instinct and card(&"beasts_instinct"):
		dx = card(&"beasts_instinct").param("dx", maxi(card_level(&"beasts_instinct"), 1))
	return maxf(0.5, 1.0 + 0.08 * dx)


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

## Starts a job. As in Trickster, a job change brings the job's character
## and its skill tree, nothing else.
func start_job(j: JobData) -> void:
	job = j
	jobs.append(j)
	if jobs.size() > 1 and quirk(&"job_cloak"):
		pending_levels += 1  # a free type point
	if j.starter and card_level(j.starter.id) == 0:
		add_card(j.starter.id)
	stats_changed()


## The character on screen: the latest job's (a job change replaces the
## character), else the class's.
## The beast bodies (the client's ESAWildMutation loads trs001,
## ESAWildChange trs002).
const FORM_ACTORS := {&"evolution": "beast_evolution", &"metamorphosis": "beast_metamorphosis"}


## Whether skill `id` works in your form: in a beast, only the skills either
## form can use or that form's own (SkillCaster.FORM_NEEDED).
func form_allows(id: StringName, as_form := form) -> bool:
	if as_form == &"":
		return true
	return SkillCaster.FORM_NEEDED.get(id, &"none") in [&"", as_form]


## Why a slotted skill can't be used in your current shape ("" when it can):
## a beast skill outside its form, or another skill in a beast.
func form_block(id: StringName) -> String:
	if not form_allows(id):
		return "Not in %s" % card(form).display_name
	if SkillCaster.FORM_NEEDED.has(id):
		var need: StringName = SkillCaster.FORM_NEEDED[id]
		if form == &"" or (need != &"" and form != need):
			return "Beast form only"
	return ""


func actor() -> String:
	if form != &"":
		return FORM_ACTORS[form]
	for i in range(jobs.size() - 1, -1, -1):
		if jobs[i].actor != "":
			return jobs[i].actor
	return cls.actor if cls else "buffalo"


## Points a type has gained by itself with levels, along the class's graph.
func auto_points(t: String) -> float:
	return float(cls.graph.get(t, 0.0)) * (level - 1)


## Whether the run has reached its job change and the job has somewhere to go.
func job_change_due() -> bool:
	return local_depth() == region.job_change_depth and job.next_jobs.size() > 0 and system_on(&"jobs")


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


## Prerequisites count a skill as known at its level while you have it, or
## an advanced form of it (Tempest Strike still counts as Lacerator).
func requirements_met(card: CardData) -> bool:
	for id: StringName in card.requires:
		# A class can stand its own basic spell in for another (Sheep's Mana
		# Ring where the original asks for Mana Arrow).
		var need: StringName = cls.swap_requires.get(id, id) if cls else id
		if known_level(need) < int(card.requires[id]):
			return false
	return true


## A card's level, or that of the advanced form that replaced it.
func known_level(id: StringName) -> int:
	if card_level(id) > 0:
		return card_level(id)
	for owned: StringName in cards:
		var c := card(owned)
		var base := c.upgrades if c else &""
		while base != &"":
			if base == id:
				return cards[owned]
			base = card(base).upgrades if card(base) else &""
	return 0


## Whether a card can be offered as new: not known, prerequisites met, and
## for an advanced form, its base skill is in hand.
func can_learn(c: CardData) -> bool:
	if card_level(c.id) > 0 or not requirements_met(c):
		return false
	if cls and c.id in cls.excluded_cards:
		return false
	# A beast is offered only the skills it can use.
	if c.is_skill() and not form_allows(c.id):
		return false
	if not c.jobs.is_empty() and job and job.id != &"trickster" and not job.id in c.jobs:
		return false
	for other: StringName in c.excludes:
		if card_level(other) > 0:
			return false
	return c.upgrades == &"" or card_level(c.upgrades) > 0


## Learns a card or raises its level. A new skill goes in the first free
## slot, or in `slot` when given (replacing what was there). An advanced form
## replaces its base skill: it takes the base's slot and level, and the base
## is forgotten (in Trickster both are kept, the new one from Lv 1; with a
## single slot to fill here, a Lv 1 upgrade would be a step down).
func add_card(id: StringName, slot := -1) -> void:
	var is_new := card_level(id) == 0
	var c := card(id)
	if is_new and c.upgrades != &"" and card_level(c.upgrades) > 0:
		var at := loadout.find(c.upgrades)
		var base_level := card_level(c.upgrades)
		cards.erase(c.upgrades)
		cards[id] = mini(base_level, card_cap(id))
		if at >= 0:
			loadout[at] = id
		stats_changed()
		return
	cards[id] = mini(card_level(id) + 1, card_cap(id))
	if id in FORM_ACTORS:
		form = id
		instinct = false
	stats_changed()
	if not is_new or not c.is_skill() or is_basic(id):
		return
	if slot < 0:
		slot = loadout.find(&"")
	if slot >= 0:
		var old := loadout[slot]
		if old != &"":
			cards.erase(old)
		loadout[slot] = id


## Whether a card is the class's basic spell (cast from the attack button,
## never put in a slot).
func is_basic(id: StringName) -> bool:
	return cls != null and cls.basic_skill != null and cls.basic_skill.id == id


func free_slot() -> int:
	return loadout.find(&"")


## A card's level cap: 5 (or the original's cap when lower), plus its
## master levels.
func card_cap(id: StringName) -> int:
	var c := card(id)
	if c and c.max_level > 0:
		return c.max_level
	return MAX_CARD_LEVEL + int(Profile.mastery.get(String(id), 0))


## What the next master level of a card costs: materials and Galder.
func mastery_cost(c: CardData) -> Dictionary:
	var lvl := int(Profile.mastery.get(String(c.id), 0)) + 1
	return {"material": c.master_material, "count": 6 * lvl, "galder": 500 * lvl}


func can_master(c: CardData) -> bool:
	if c.master_material == null or c.max_level > 0 or int(Profile.mastery.get(String(c.id), 0)) >= MAX_MASTERY:
		return false
	var cost := mastery_cost(c)
	return int(Profile.materials.get(String(cost.material.id), 0)) >= cost.count and Profile.galder >= cost.galder


func master_card(c: CardData) -> void:
	var cost := mastery_cost(c)
	Profile.materials[String(cost.material.id)] = int(Profile.materials.get(String(cost.material.id), 0)) - cost.count
	Profile.galder -= cost.galder
	Profile.mastery[String(c.id)] = int(Profile.mastery.get(String(c.id), 0)) + 1
	Profile.save()


## Every card in the game (for the Skill Master's list).
func all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for c: CardData in _cards.values():
		out.append(c)
	out.sort_custom(func(a: CardData, b: CardData) -> bool: return a.display_name < b.display_name)
	return out


func card_level(id: StringName) -> int:
	if rune and id == rune.id:
		return rune_level
	return cards.get(id, 0)


func card_value(id: StringName) -> float:
	var c := card(id)
	return c.value_at(card_level(id)) if c else 0.0


## Up to `n` card offers from the current jobs' trees (or only `from_job`'s):
## new cards whose prerequisites are met, or upgrades of owned ones when
## `upgrade` is true. New-card offers lean on skills: at least two of three
## while there are skills left to learn.
func card_offers(n: int, upgrade: bool, from_job: JobData = null) -> Array[CardData]:
	var skills: Array[CardData] = []
	var talents: Array[CardData] = []
	for c in (from_job.cards if from_job else card_pool()):
		var lvl := card_level(c.id)
		# Training can also teach what grows the basic spell (Arrow Rush).
		if (upgrade and lvl > 0 and lvl < card_cap(c.id)) or ((not upgrade or _grows_basic(c)) and can_learn(c)):
			(skills if c.is_skill() else talents).append(c)
	skills.shuffle()
	talents.shuffle()
	var out: Array[CardData] = []
	# A mage's basic spell is its main weapon: its level-ups and the cards that
	# grow it (Arrow Rush, Mana Ring Booster) are always among the offers.
	for c: CardData in skills + talents:
		if out.size() < n and _grows_basic(c):
			out.append(c)
			skills.erase(c)
			talents.erase(c)
	if upgrade:
		var rest := skills + talents
		rest.shuffle()
		out.append_array(rest.slice(0, n - out.size()))
		out.shuffle()
		return out
	var want_skills := mini(skills.size(), maxi(n - 1 - out.size(), 0) if talents.size() > 0 else n - out.size())
	out.append_array(skills.slice(0, want_skills))
	out.append_array(talents.slice(0, n - out.size()))
	out.append_array(skills.slice(want_skills, want_skills + n - out.size()))
	out.shuffle()
	return out


## The class's basic spell, or a talent that improves it.
## The gun's own talents: they grow a gunner's basic shot, so they are offered
## like the cards that build on a basic skill.
const GUN_GROWERS: Array[StringName] = [&"overcharge", &"invincible_reload", &"quick_reload", &"gun_booster",
	&"keen_sense", &"sharp_sense", &"speedloader", &"gun_overdrive"]


func _grows_basic(c: CardData) -> bool:
	if cls == null or cls.basic_skill == null:
		return false
	if cls.basic_skill.id == &"gun_shot" and c.id in GUN_GROWERS:
		return true
	return c.id == cls.basic_skill.id or (not c.is_skill() and c.requires.has(cls.basic_skill.id))


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
## What the last equip() put away besides the item it replaced: a shield, when
## a gun is taken up ("a loaded gun can't share your hands with a shield").
var displaced: Array[GearItem] = []


## Whether `item` can go on now: no shield while a gun is carried.
func can_equip(item: GearItem) -> bool:
	return not (item.data.slot == ItemData.Slot.SHIELD and carries_gun())


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
	var before := max_hp
	equipment[slot_key] = item
	if carries_gun() and equipment.has("shield"):
		displaced.append(equipment["shield"])
		equipment.erase("shield")
	stats_changed()
	if max_hp > before:
		heal(max_hp - before)
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
	if (randf() if roll < 0.0 else roll) < g.refine_chance():
		g.refine += 1
		result = "success"
	elif g.refine >= 4 and randf() < 0.5:
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


## Wardrobe pieces worn (from the Profile).
func worn_pieces() -> Array[WardrobeData]:
	var out: Array[WardrobeData] = []
	if hub == null:
		return out
	for w in hub.wardrobe:
		if Profile.worn.get(w.slot, "") == String(w.id):
			out.append(w)
	return out


## Whether a worn wardrobe piece has this quirk.
func quirk(id: StringName) -> bool:
	for w in worn_pieces():
		if w.quirk == id:
			return true
	return false


## Monster card drop for a kill (rare; elites and bosses more often).
func roll_card(enemy_id: StringName, elite: bool, boss: bool) -> bool:
	if not system_on(&"cards"):
		return false
	var chance := 0.5 if boss else (0.15 if elite else 0.02 + stat("DA") / 1000.0)
	return randf() < chance


## The drill carried (the first one once the Drill Shop is restored).
func drill() -> DrillData:
	if hub == null or hub.drills.is_empty() or not system_on(&"drilling"):
		return null
	for d in hub.drills:
		if String(d.id) == Profile.drill and String(d.id) in Profile.drills:
			return d
	return hub.drills[0]


## What a dig to `depth` brings up: ore, then the region's materials, then
## gear, then a Harkon Shard.
func dig_rewards(depth_reached: int) -> Dictionary:
	var out := {"ore": 0, "material": null, "count": 0, "gear": null, "shard": 0}
	if depth_reached >= 5:
		out.ore = 1 + depth_reached / 10
	if depth_reached >= 15:
		var mats: Array[MaterialData] = []
		for e in region.enemies:
			if e.material and not e.is_boss:
				mats.append(e.material)
		if not mats.is_empty():
			out.material = mats[randi() % mats.size()]
			out.count = 2 + depth_reached / 20
	if depth_reached >= 40:
		var offers := gear_offers(1)
		if not offers.is_empty():
			out.gear = offers[0]
	if depth_reached >= 70:
		out.shard = 1
	return out


## Every material the run can drop, by id (for city crafting).
func material_by_id(id: StringName) -> MaterialData:
	for r in regions:
		for e in r.enemies:
			if e.material and e.material.id == id:
				return e.material
	return null


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
	return stat("WT") / 4


func overweight() -> bool:
	return equip_load() > load_limit()


## Up to `n` different items that can drop at this depth, rolled with DA.
## Whether this class can use a weapon: guns need Gun Carrier; a gunner
## (Lion, who starts with one) fights with guns only.
func can_use(it: ItemData) -> bool:
	var gunner := cls.start_weapon != null and cls.start_weapon.family == "gun"
	if it.slot == ItemData.Slot.SHIELD:
		return not gunner and not carries_gun()  # a gun needs both hands
	if it.slot != ItemData.Slot.WEAPON:
		return true
	if it.family == "gun":
		return card_level(&"gun_carrier") > 0
	return not gunner


func gear_offers(n: int) -> Array[GearItem]:
	var pool: Array[ItemData] = []
	var top := 1 + 3 * depth
	for it in items:
		if it.level <= top and it.level >= top - 24 and not it.legend and it != cls.start_weapon and can_use(it):
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

## Berserker's rage, and Desperate Rally below its HP line (stronger the
## lower HP gets, up to double at 0).
func _berserk_mult() -> float:
	var m := 1.0 + card_value(&"berserker") / 100.0
	var line := card(&"desperate_rally").param("hp", card_level(&"desperate_rally")) / 100.0 if card_level(&"desperate_rally") > 0 else 0.0
	var frac := hp / float(maxi(max_hp, 1))
	if line > 0.0 and frac < line:
		m *= 1.0 + card_value(&"desperate_rally") / 100.0 * (1.0 + (line - frac) / line)
	return m


func _ratio(key: String, soft: float) -> float:
	return (stat(key) + soft) / (float(_ref.get(key, 0)) + soft)


## Damage scales with its stat as in Trickster (damage = stat x skill %):
## the stat against the starting character's, so twice the MA is twice the
## damage and one early point is worth several percent.
func _linear(key: String) -> float:
	return stat(key) / maxf(float(_ref.get(key, 0)), 1.0)


## Damage multiplier for the basic combo.
func attack_mult() -> float:
	var m := _linear("AP") * _berserk_mult()
	if has_passive(&"sword_mastery") and weapon_family() == "sword" and cls.armed:
		m *= 1.15
	if has_passive(&"boxers_footwork") and not cls.armed:
		m *= 1.15
	return m


## Damage multiplier for a skill, from the stat it scales with.
func skill_mult(c: CardData = null) -> float:
	var scaling := c.scaling if c else "AP"
	# AP, MA and DA work as in Trickster (linear). A GUN skill's value is a %
	# of a gun shot (its table Ratio). The runes' DP skills keep a damped curve.
	var m := 1.0
	if scaling == "GUN":
		return gun_shot_mult() * GUN_SHOT / 100.0
	elif scaling in ["AP", "MA", "DA", "HV"]:
		m = _linear(scaling)
	elif _is_expression(scaling):
		m = attack_power(scaling) / maxf(attack_power(scaling, true), 1.0)
	else:
		m = _ratio(scaling, {"DP": 60.0}.get(scaling, AP_SOFT))
	if c and c.id in THROWN:
		m *= 1.0 + card_value(&"precise_pitch") / 100.0
	if has_passive(&"arena_champion"):
		m *= 1.15
	if has_passive(&"duelists_edge"):
		m *= 1.1
	return m * _berserk_mult()


## A skill's attack as the server computes it (tools/re/README.md): a sum
## of weighted stats such as "AP+16HV" (Volley Kick), "0.1HPNOW+0.5DP"
## (Siren Song) or "AP+0.1LOST" (Final Blow). HPNOW is your current HP,
## LOST the HP you're missing. `ref`: the same for the level-1 character
## at full health, that a card's numbers are tuned against.
func attack_power(expr: String, ref := false) -> float:
	var total := 0.0
	for term in expr.split("+"):
		var i := 0
		while i < term.length() and (term[i] == "." or term[i].is_valid_int()):
			i += 1
		var w := float(term.substr(0, i)) if i > 0 else 1.0
		total += w * _attack_stat(term.substr(i), ref)
	return total


func _is_expression(scaling: String) -> bool:
	return scaling.contains("+") or scaling.contains("HPNOW") or scaling.contains("LOST") or \
		(scaling.length() > 0 and (scaling[0] == "." or scaling[0].is_valid_int()))


func _attack_stat(key: String, ref: bool) -> float:
	match key:
		"HPNOW":
			return float(_ref.get("HP", 0)) if ref else float(hp)
		"LOST":
			return 0.0 if ref else float(maxi(max_hp - hp, 0))
	return float(_ref.get(key, 0)) if ref else float(stat(key))


## Galder skills spend the run's Galder (Galder Thrower's 100 is 20 here: a
## fifth of the original's prices). False, and nothing spent, when short.
func spend_galder(amount: int) -> bool:
	if galder < amount:
		return false
	galder -= amount
	return true


func in_bunker(now: float) -> bool:
	return now < bunker_until and bunker_hp > 0


## Whether the equipped weapon is a gun you can use: Gun Carrier (Lion
## starts with it; Fox can learn it), as the client's "Gun_NotEquippable".
func carries_gun() -> bool:
	var w := equipped("weapon")
	return w != null and w.data.family == "gun" and card_level(&"gun_carrier") > 0


## Thrown-weapon skills Precise Pitch strengthens.
const THROWN: Array[StringName] = [&"shuriken_master", &"fan_of_knives", &"chain_of_knives", &"rain_of_knives",
	&"poison_assault"]


## AP + DA against the starting character's: a gun hits harder with a better
## gun (its AP) and with Sense points (DA).
## The server's gun damage (GameServer.exe 0x59d440, GunAttackStrategy):
## 20 x (AC - 49) + Gun AP + 20 - 30 x the target's HV. AC is the gun's
## stat, worth 20 Gun AP a point; translated linearly against level 1 as the
## other lines are, with the target's HV as its defence (Enemy.gun_defense_mult).
const GUN_AP_PER_AC := 20.0


## A gun shot's base damage (gun_shot.tres), which the gun skills' % refer to.
const GUN_SHOT := 87.0


## Gun Overdrive (CustomizingGun) multiplies the gun's Gun AP by its Ratio;
## Gun Booster (PriMarksmanship) adds its AP to the shot's.
func gun_attack() -> float:
	var ap := gun_ap() * (1.0 + card_value(&"gun_overdrive") / 100.0) + card_value(&"gun_booster")
	return stat("AC") + ap / GUN_AP_PER_AC


## The equipped gun's Gun AP (its table AP, raised by refining).
func gun_ap() -> float:
	var w := equipped("weapon")
	return float(w.stats().get("AP", 0)) if w and w.data.family == "gun" else 0.0


func gun_stat_mult() -> float:
	return gun_attack() / maxf(float(_ref.get("AC", 0)), 1.0)


## Damage multiplier for a gun shot. The gun skills are multiples of it, so
## they always outhit the basic shot (Gun Booster and Gun Overdrive included,
## though the original keeps Overdrive to the basic shot).
func gun_shot_mult() -> float:
	return gun_stat_mult() * _berserk_mult()


## Extra power-shot damage, %: Keen Sense, or Sharp Sense on top of a mastered
## Keen Sense. The card text's "gun critical" is the power shot: the server's
## ESASharpSense sets the factor its power-shot formula multiplies (+0x428).
func power_shot_bonus() -> float:
	if card_level(&"sharp_sense") > 0:
		var keen := card(&"keen_sense")
		var top: float = keen.value_at(MAX_CARD_LEVEL) if keen else 0.0
		return (100.0 + top) * (1.0 + card_value(&"sharp_sense") / 100.0) - 100.0
	return card_value(&"keen_sense")


## A reload's time against the gun's own. Speedloader sets the client's fill
## rate to 2 - Ratio/100 (Trickster.bin 0x4c04e0), its value being 100 - Ratio.
func reload_mult() -> float:
	return 1.0 / (1.0 + card_value(&"speedloader") / 100.0)


## Cooldowns are the original's; only Refreshing Dew shortens them.
func skill_cooldown_mult() -> float:
	return 1.0 - card_value(&"refreshing_dew") / 100.0


## The elemental Shields and the Blessings that upgrade them (2117-2121, 2306-2310).
const SHIELDS := {&"water_shield": "Water", &"thunder_shield": "Elec", &"fire_shield": "Fire",
	&"earth_shield": "Earth", &"wind_shield": "Wind"}
const BLESSINGS := {&"undines_blessing": &"water_shield", &"raions_blessing": &"thunder_shield",
	&"salamanders_blessing": &"fire_shield", &"gnomes_blessing": &"earth_shield", &"sylphs_blessing": &"wind_shield"}


## Your resistance to an element, in %.
func resist(element: String) -> float:
	var r := 0.0
	for id: StringName in SHIELDS:
		if SHIELDS[id] == element:
			r += card_value(id)
	for id: StringName in BLESSINGS:
		# A Blessing keeps the resistance of the Shield it replaced, at its level.
		if card_level(id) > 0 and SHIELDS[BLESSINGS[id]] == element:
			r += card(BLESSINGS[id]).value_at(card_level(id))
	if element == "Elec":
		r += card_value(&"lightning_rod")
	if element == "Light":
		r += card_value(&"light_shield")
	if element == "Dark":
		r += card_value(&"dark_barrier")
	return minf(r, 80.0)


## Extra damage % for spells of an element (Elemental Boost, Dark Assimilation).
func element_boost(element: String) -> float:
	match element:
		"Fire", "Water", "Wind", "Earth", "Elec":
			return card_value(&"elemental_boost")
		"Dark":
			return card_value(&"dark_assimilation")
	return 0.0


func attack_speed_mult() -> float:
	return _ratio("DX", DX_SOFT) * (1.0 + (card_value(&"hyper_beat") + card_value(&"aura_of_haste")) / 100.0) * form_speed_mult()


func speed_mult() -> float:
	var m := 0.85 if overweight() else 1.0
	if quirk(&"swift"):
		m *= 1.08
	if quirk(&"swift_feet"):
		m *= 1.1
	return m


func dash_cooldown_mult() -> float:
	var m := (1.3 if overweight() else 1.0) * (0.8 if quirk(&"quick_dash") else 1.0)
	return m * (0.8 if not cls.armed else 1.0)  # fighting bare-handed keeps you light on your feet


## Debuffs your hits carry from the breaker talents ({key: [value, seconds]},
## see Enemy.debuffs).
const BREAKERS := {&"armor_breaker": "dp", &"shockvibe": "ac", &"sense_breaker": "perception", &"luck_breaker": "luck",
	&"armor_destructor": "dp", &"sticky_foot": "slow", &"lock_on": "hv",
	&"magic_meltdown": "ma", &"magic_def_breaker": "md"}


func hit_debuffs() -> Dictionary:
	var out := {}
	for id: StringName in BREAKERS:
		if card_level(id) > 0:
			out[BREAKERS[id]] = [card_value(id), card(id).param("seconds", card_level(id))]
	if card_level(&"suffocate") > 0:
		out["pinned"] = [1.0, card_value(&"suffocate")]
	if card_level(&"entrancing_wink") > 0:
		out["silence"] = [1.0, card_value(&"entrancing_wink")]  # no magic while entranced
	return out


## Critical chance, against `e` when given (Luck Breaker makes cursed
## monsters easier to crit).
func crit_chance(e: Enemy = null) -> float:
	var c := 0.03 + stat("LK") / 250.0
	return c * (1.0 + e.debuff("luck") / 100.0) if e else c


## Damage taken: DP against physical hits, MD against magic.
## `element`: the attacker's (an elemental Shield resists it).
func damage_taken_mult(magic := false, element := "") -> float:
	var key := "MD" if magic else "DP"
	var m := (float(_ref.get(key, 0)) + DEF_SOFT) / (stat(key) + DEF_SOFT)
	if has_passive(&"hired_blade"):
		m *= 0.9
	m *= 1.0 - card_value(&"sumo_suit") / 100.0
	if magic:
		m *= 1.0 - card_value(&"mana_reflector") / 100.0  # the part it turns back
	if element != "":
		m *= 1.0 - resist(element) / 100.0
	return m


## Chance to evade an attack from a monster with accuracy `ac`.
func evade_chance(ac: int) -> float:
	var hv := stat("HV")
	var c := hv / float(hv + ac + 150)
	if has_trait(&"light_feet"):
		c += 0.08
	if quirk(&"catlike"):
		c += 0.06
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
	galder += int(galder_amount * (1.0 + stat("LK") / 100.0) * (1.2 if quirk(&"thrifty") else 1.0))
	var found := 0
	if boss:
		found = 3
	elif elite or randf() < (0.12 + stat("DA") / 400.0) * ServerSettings.drop_mult():
		found = 1
	ore += found
	var count := 0
	if mat and system_on(&"compounding"):
		if boss:
			count = 3
		elif elite:
			count = 2
		elif randf() < (mat_chance + stat("DA") / 200.0 + (0.1 if quirk(&"sly") else 0.0)) * ServerSettings.drop_mult():
			count = 1
		add_material(mat, count)
	if quirk(&"mana_tail"):
		gain_mp(3)
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
	var c := g.compound(mat, clampf(stat("DA") / 60.0 * (1.0 + card_value(&"compound_master") / 100.0), 0.0, 1.0))
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
	var cut := 0.8 if quirk(&"masked") else 1.0
	for g in gear_offers(2):
		out.append({"kind": "gear", "item": g, "price": int((160 + 24 * g.data.level + 50 * g.slots) * cut)})
	out.append({"kind": "ore", "count": 3, "price": int(180 * cut)})
	var mats: Array[MaterialData] = []
	for e in region.enemies:
		if e.material and local_depth() >= e.min_depth and not e.is_boss:
			mats.append(e.material)
	if mats.size() > 0:
		var m: MaterialData = mats[randi() % mats.size()]
		out.append({"kind": "material", "material": m, "count": m.need, "price": int(70 * m.need * cut)})
	out.append({"kind": "potion", "heal": 0.4, "price": int(160 * cut)})
	return out
