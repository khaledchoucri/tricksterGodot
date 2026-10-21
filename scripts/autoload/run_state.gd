extends Node
## Everything that belongs to the current run (autoloaded as `Run`): the
## class and its current job, levels and type points, the twelve stats they
## produce with gear, skill cards, equipment and run materials. A rollback
## (death) or a cleared run resets it; the Profile banks what carries over.

signal leveled_up(new_level: int)

## The run's route (Run.route): the regions it crosses, the planned rooms and how deep you are.
var route := RunRoute.new()

## What the run carries (Run.purse): Galder, ore, TM, shards and monster materials.
var purse := RunPurse.new()

## Your gear (Run.gear): what's equipped, refining and compounding it, its weight, guns and the shop.
var gear := RunGear.new()

## Your cards (Run.deck): every card the game knows, the ones you hold, offers and talents.
var deck := RunDeck.new()

## The run's numbers (Run.formulas): your damage, defence, speed, guns and crits against the
var formulas := RunFormulas.new()

const HUB_PATH := "res://data/megalopolis/hub.tres"
const CLASS_PATHS: Array[String] = ["res://data/classes/buffalo.tres", "res://data/classes/bunny.tres",
	"res://data/classes/sheep.tres", "res://data/classes/dragon.tres",
	"res://data/classes/fox.tres", "res://data/classes/lion.tres",
	"res://data/classes/cat.tres", "res://data/classes/raccoon.tres"]
const ITEMS_DIR := "res://data/items/"
const MONSTERS_PATH := "res://original_assets/data/monsters.json"
## Guard (1107): blocks left, and when the next spent one returns.
var guard_blocks := 0
var guard_back_at := 0.0
## Shield of Heaven (2218): the barrier's HP, and when a broken one returns.
var barrier := 0
var barrier_back_at := 0.0
## Revival (2221): when it can bring you back again.
var revival_ready_at := 0.0
## Echoes of other classes that can haunt elite rooms after the first clear.
const ECHO_PATHS: Array[String] = ["res://data/echoes/echo_bard.tres", "res://data/echoes/echo_explorer.tres",
	"res://data/echoes/echo_entertainer.tres"]

var hub: HubData
var cls: ClassData
var classes: Array[ClassData] = []
var items: Array[ItemData] = []
var monster_data: Dictionary = {}  # original stats by monster id (generated, may be empty)

## The run's gameplay randomness (rolls, drops, offers, the room plan, AI), seeded by
## new_run() so a seed reproduces a run. Effects that are only visual or audible use
## the global RNG instead, so they can't change a fight.
var rng := RandomNumberGenerator.new()
## The seed the current run started from.
var run_seed := 0
## When 0 or more, the next new_run() uses this seed (for the bots and tests); it's
## then cleared.
var next_seed := -1

var level := 1
var xp := 0
var hp := 100
var mp := 100
var job: JobData
var jobs: Array[JobData] = []
## Type points the player chose (count toward traits).
var type_points := {"power": 0, "magic": 0, "sense": 0, "charm": 0}
var echoes: Array[EnemyData] = []
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
## The level-1 stats this run's numbers are tuned against (Run.formulas compares with them).
var ref_stats: Dictionary = {}
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


func _ready() -> void:
	for p in route.REGION_PATHS:
		route.regions.append(load(p))
	hub = load(HUB_PATH)
	for p in CLASS_PATHS:
		classes.append(load(p))
	cls = classes[0]
	deck.index_cards()
	_load_items()
	for p in ECHO_PATHS:
		var e: EnemyData = load(p)
		echoes.append(e)
		for c in e.runes:
			deck.registry[c.id] = c
	if FileAccess.file_exists(MONSTERS_PATH):
		monster_data = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))
	for c: CardData in deck.registry.values():
		for key: String in c.mods:
			if not Mod.is_key(key):
				push_error("%s: unknown mod key %s (see scripts/data/mod.gd)" % [c.resource_path, key])


## An enemy from any region (or an Echo).
func enemy(id: StringName) -> EnemyData:
	for r in route.regions:
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
			deck.registry[c.id] = c
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
	j.starter = hub.trickster_starter
	j.passive = &"data_bleed"
	j.passive_name = "Data Bleed"
	j.passive_text = "Skill card rewards offer one more choice."
	j.passive_mods = {"card_choices": 1.0}
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


## Shuffles an array in place with the run's RNG (Array.shuffle() uses the global one).
func shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = a[i]
		a[i] = a[j]
		a[j] = held


## A random element of an array, with the run's RNG; null when it's empty.
func pick(a: Array) -> Variant:
	return null if a.is_empty() else a[rng.randi_range(0, a.size() - 1)]


## Starts a fresh run. A seed of 0 or more (or next_seed) makes it reproducible.
func new_run(with_seed := -1) -> void:
	run_seed = with_seed if with_seed >= 0 else next_seed if next_seed >= 0 else randi()  # the global RNG picks a seed
	next_seed = -1
	rng.seed = run_seed
	deck.clear_talents()
	hidden = false
	hidden_until = 0.0
	bunker_until = 0.0
	bunker_hp = 0
	cls = chosen_class()
	route.depth = 0
	level = 1
	xp = 0
	type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	deck.cards = {}
	deck.loadout = [&"", &"", &""]
	jobs.clear()
	gear.equipment = {"weapon": GearItem.make(cls.start_weapon)}
	purse.ore = 0
	deck.rune = null
	deck.rune_level = 0
	purse.materials = {}
	purse.galder = 0
	purse.tm = 0
	purse.shards = 0
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
	ref_stats = {}
	_baseline = true  # numbers are tuned against the bare level-1 character
	for k in Stats.KEYS:
		ref_stats[k] = stat(k)
	_baseline = false
	_stats.clear()
	start_job(cls.start_job)
	for id in cls.start_cards:
		if deck.card_level(id) == 0:
			deck.add_card(id)
	_carry_heirloom()
	_apply_restorations()
	stats_changed()
	hp = max_hp
	mp = max_mp
	route.plan = route.plan_rooms()


## Equips the heirloom chosen in the warehouse, level-synced to the region.
func _carry_heirloom() -> void:
	if not system_on(&"warehouse") or Profile.heirloom < 0 or Profile.heirloom >= Profile.warehouse.size():
		return
	var g := GearItem.from_dict(Profile.warehouse[Profile.heirloom], item_by_id)
	if g == null:
		return
	g.stored = Profile.heirloom
	g.refine_cap = route.regions[0].refine_cap
	g.sync_level = sync_level()
	gear.equip(g, "acc1" if g.data.slot == ItemData.Slot.ACCESSORY else "")


## The item level gear is synced to at this depth (drops use the same scale).
func sync_level() -> int:
	return 3 + 3 * route.depth


## Re-syncs carried heirlooms to the current depth and region (on entering a room).
func sync_heirlooms() -> void:
	for g: GearItem in gear.equipment.values():
		if g.sync_level >= 0:
			g.sync_level = sync_level()
			g.refine_cap = route.region.refine_cap
	stats_changed()


func item_by_id(id: StringName) -> ItemData:
	for it in items:
		if it.id == id:
			return it
	return null


## Portable Port: saves every stored item's progress, and sends `item` home
## (if given). Returns false if the warehouse is full.
func save_point(item: GearItem = null) -> bool:
	for g: GearItem in gear.equipment.values():
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
	for g: GearItem in gear.equipment.values():
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
				for c in deck.card_pool():
					if c.is_skill() and deck.can_learn(c):
						pool.append(c.id)
				if pool.size() > 0:
					deck.add_card(pool[rng.randi() % pool.size()])


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
	for t in deck.talents():
		if t.revive():  # Revival: light brings you back, on its own cooldown
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
	var reached := route.depth + (1 if p_won else 0)
	var heat := ServerSettings.heat()
	purse.tm += int(purse.tm * heat * ServerSettings.TM_PER_HEAT)
	var bounty := 0
	if p_won and heat > Profile.best_heat:
		bounty = heat - maxi(Profile.best_heat, 0)
		purse.shards += bounty
		Profile.best_heat = heat
	last_result = {"won": p_won, "depth": reached, "tm": purse.tm, "shards": purse.shards, "heat": heat, "bounty": bounty}
	Profile.bank_run(p_won, reached, purse.tm, purse.shards, String(job.id))
	if system_on(&"warehouse"):
		last_result.kept = Profile.bank_leftovers(p_won, purse.galder, purse.ore, purse.materials)


# ---------------------------------------------------------------- monster curve


static func raw_ehp(s: Dictionary) -> float:
	return float(s.get("HP", 100)) * (100.0 + float(s.get("DP", 0))) / 100.0


static func raw_hit(s: Dictionary) -> float:
	return 6.0 + float(s.get("AP", 4)) * 0.25


## Whether an Echo joins this elite room (after the first clear).
func echo_here() -> EnemyData:
	if not route.current_room().elite or int(Profile.stats.get("clears", 0)) < 1 or rng.randf() > 0.45:
		return null
	return echoes[rng.randi() % echoes.size()]


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
	for g: GearItem in gear.equipment.values():
		var gs := g.stats()
		for k: String in gs:
			s[k] = s.get(k, 0.0) + gs[k]
	s.HP += _bonus_hp
	for w in ([] if _baseline else worn_pieces()):
		for k: String in w.stats:
			s[k] = s.get(k, 0.0) + w.stats[k]
	# Buffs, always on (Trickster's are timed casts): every held card's stat mods.
	for key: String in Mod.STAT_PERCENT:
		s[key.trim_suffix("%")] *= 1.0 + mod(key) / 100.0
	for key: String in Mod.STAT_FLAT:
		s[key] += mod(key)
	_form_stats(s)
	for k: String in s:
		_stats[k] = maxi(0, floori(s[k]))


## The beast forms' stat changes (ESAction_WildMutation, _Change, _Beast):
## Evolution multiplies AP and takes DP, HV and LK away; Metamorphosis the
## reverse; Beast's Instinct sharpens Evolution further. DX is attack speed.
func _form_stats(s: Dictionary) -> void:
	if form == &"":
		return
	var shape := deck.card(form)
	var c := _form_rows()
	var lvl := maxi(deck.card_level(c.id), 1)
	var gain := c.value_at(lvl) / 100.0
	var loss := c.param("loss", lvl) / 100.0
	for k: String in shape.form_gains:
		s[k] *= 1.0 + gain
	for k: String in shape.form_losses:
		s[k] *= 1.0 - loss


## The card whose rows the form uses now: an active instinct of that form (Beast's
## Instinct sharpens Evolution), else the form card itself.
func _form_rows() -> CardData:
	if instinct:
		for c in deck.held_cards():
			if c.has_tag(&"instinct") and c.form == form:
				return c
	return deck.card(form)


## Attack speed in a beast form: the table's DX change, 8% a point (the
## Hyper Beat reading).
func form_speed_mult() -> float:
	if form == &"":
		return 1.0
	var c := _form_rows()
	var dx := c.param("dx", maxi(deck.card_level(c.id), 1))
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
	if jobs.size() > 1:
		pending_levels += int(mod("job_change_points"))  # the Job Cloak's free type point
	if j.starter and deck.card_level(j.starter.id) == 0:
		deck.add_card(j.starter.id)
	stats_changed()


## The character on screen: the latest job's (a job change replaces the
## character), else the class's.
## Whether skill `id` works in your form: in a beast, only the skills either
## form can use (`form` &"beast") or that form's own.
func form_allows(id: StringName, as_form := form) -> bool:
	if as_form == &"":
		return true
	var need: StringName = deck.card(id).form if deck.card(id) else &""
	return need == &"beast" or (need != &"" and need == as_form)


## Why a slotted skill can't be used in your current shape ("" when it can):
## a beast skill outside its form, or another skill in a beast.
func form_block(id: StringName) -> String:
	if not form_allows(id):
		return "Not in %s" % deck.card(form).display_name
	var need: StringName = deck.card(id).form if deck.card(id) else &""
	if need != &"" and (form == &"" or (need != &"beast" and form != need)):
		return "Beast form only"
	return ""


func actor() -> String:
	if form != &"":
		return deck.card(form).form_actor  # the client's ESAWildMutation loads trs001, ESAWildChange trs002
	for i in range(jobs.size() - 1, -1, -1):
		if jobs[i].actor != "":
			return jobs[i].actor
	return cls.actor if cls else "buffalo"


## Points a type has gained by itself with levels, along the class's graph.
func auto_points(t: String) -> float:
	return float(cls.graph.get(t, 0.0)) * (level - 1)


## Whether the run has reached its job change and the job has somewhere to go.
func job_change_due() -> bool:
	return route.local_depth() == route.region.job_change_depth and job.next_jobs.size() > 0 and system_on(&"jobs")


func has_passive(id: StringName) -> bool:
	for j in jobs:
		if j.passive == id:
			return true
	return false


## The sum of `key` (a Mod key) over everything held: cards at their level, then job
## passives, unlocked traits and worn wardrobe pieces.
func mod(key: String) -> float:
	var total := 0.0
	for v: float in _mod_values(key):
		total += v
	return total


## `start` multiplied by each source's 1 + v / 100 in turn (1 - v / 100 when `cut`), for
## effects that multiply rather than add: two pieces that each move you faster compound.
func mod_factor(key: String, cut := false, start := 1.0) -> float:
	var f := start
	for v: float in _mod_values(key):
		f *= 1.0 - v / 100.0 if cut else 1.0 + v / 100.0
	return f


## What card `c` adds to `key` at `level`. The source "base" is the value of the card it
## upgrades, at its own level (a Blessing keeps its Shield's resistance).
func _card_mod(c: CardData, key: String, level: int) -> float:
	if c.mods[key] == "base":
		return deck.card(c.upgrades).value_at(level)
	return c.mod_at(key, level)


## Every held source's amount for `key`, in the order mod() documents.
func _mod_values(key: String) -> Array[float]:
	assert(Mod.is_key(key), "not a Mod key: " + key)
	var out: Array[float] = []
	for id: StringName in deck.cards:
		var c := deck.card(id)
		if c and c.mods.has(key):
			out.append(_card_mod(c, key, deck.card_level(id)))
	if deck.rune and not deck.cards.has(deck.rune.id) and deck.rune.mods.has(key):
		out.append(_card_mod(deck.rune, key, deck.rune_level))
	for j in jobs:
		if j.passive_mods.has(key):
			out.append(j.passive_mods[key])
	for type: String in Stats.TYPE_ORDER:
		for i in trait_count(type):
			var t: Dictionary = Stats.trait_at(type, i).get("mods", {})
			if t.has(key):
				out.append(t[key])
	for w in ([] as Array[WardrobeData] if _baseline else worn_pieces()):
		if w.mods.has(key):
			out.append(w.mods[key])
	return out


# ---------------------------------------------------------------- equipment


## Wardrobe pieces worn (from the Profile).
func worn_pieces() -> Array[WardrobeData]:
	var out: Array[WardrobeData] = []
	if hub == null:
		return out
	for w in hub.wardrobe:
		if Profile.worn.get(w.slot, "") == String(w.id):
			out.append(w)
	return out


## Monster card drop for a kill (rare; elites and bosses more often).
func roll_card(enemy_id: StringName, elite: bool, boss: bool) -> bool:
	if not system_on(&"cards"):
		return false
	var chance := 0.5 if boss else (0.15 if elite else 0.02 + stat("DA") / 1000.0)
	return rng.randf() < chance


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
		for e in route.region.enemies:
			if e.material and not e.is_boss:
				mats.append(e.material)
		if not mats.is_empty():
			out.material = mats[rng.randi() % mats.size()]
			out.count = 2 + depth_reached / 20
	if depth_reached >= 40:
		var offers := gear.gear_offers(1)
		if not offers.is_empty():
			out.gear = offers[0]
	if depth_reached >= 70:
		out.shard = 1
	return out


# ---------------------------------------------------------------- combat numbers


func in_bunker(now: float) -> bool:
	return now < bunker_until and bunker_hp > 0


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
	purse.tm += tm_amount
	purse.galder += int(galder_amount * (1.0 + stat("LK") / 100.0) * mod_factor("galder%"))
	var found := 0
	if boss:
		found = 3
	elif elite or rng.randf() < (0.12 + stat("DA") / 400.0) * ServerSettings.drop_mult():
		found = 1
	purse.ore += found
	var count := 0
	if mat and system_on(&"compounding"):
		if boss:
			count = 3
		elif elite:
			count = 2
		elif rng.randf() < (mat_chance + stat("DA") / 200.0 + mod("material_drop")) * ServerSettings.drop_mult():
			count = 1
		purse.add_material(mat, count)
	if mod("kill_mp") > 0.0:
		gain_mp(int(mod("kill_mp")))
	gain_exp(exp_amount)
	return {"ore": found, "material": mat if count > 0 else null, "count": count}


# ---------------------------------------------------------------- materials and compounding


# ---------------------------------------------------------------- shop

