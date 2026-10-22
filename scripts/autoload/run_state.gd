extends Node
## The current run (autoloaded as `Run`): the character (class, job, level, HP and MP, form,
## type points, the twelve stats and the mods that shape them) and the modules that hold the
## rest. A rollback (death) or a cleared run resets it; the Profile banks what carries over.
##
## The modules (callers name them: Run.deck.card_level(id), never a forwarding function):
##  - route: the regions, the room plan and how deep you are
##  - deck: every card the game knows and the ones you hold, the loadout, offers, talents
##  - gear: equipment, refining, compounding, weight, guns, the shop and the item list
##  - purse: Galder, ore, TM, shards, materials, and what kills and digs bring
##  - formulas: your damage, defence, speed and crits, and the monster curve
##  - city: what the run takes from Megalopolis and gives back

signal leveled_up(new_level: int)

const HUB_PATH := "res://data/megalopolis/hub.tres"
const CLASS_PATHS: Array[String] = ["res://data/classes/buffalo.tres", "res://data/classes/bunny.tres",
	"res://data/classes/sheep.tres", "res://data/classes/dragon.tres",
	"res://data/classes/fox.tres", "res://data/classes/lion.tres",
	"res://data/classes/cat.tres", "res://data/classes/raccoon.tres"]
const MONSTERS_PATH := Assets.MONSTERS
## Echoes of other classes that can haunt elite rooms after the first clear.
const ECHO_PATHS: Array[String] = ["res://data/echoes/echo_bard.tres", "res://data/echoes/echo_explorer.tres",
	"res://data/echoes/echo_entertainer.tres"]

var route := RunRoute.new()
var deck := RunDeck.new()
var gear := RunGear.new()
var purse := RunPurse.new()
var formulas := RunFormulas.new()
var city := RunCity.new()

## Guard (1107): blocks left, and when the next spent one returns.
var guard_blocks := 0
var guard_back_at := 0.0
## Shield of Heaven (2218): the barrier's HP, and when a broken one returns.
var barrier := 0
var barrier_back_at := 0.0
## Revival (2221): when it can bring you back again.
var revival_ready_at := 0.0
var hub: HubData
var cls: ClassData
var classes: Array[ClassData] = []
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

## Max HP from the city's restorations (Run.city.apply_restorations()).
var bonus_hp := 0
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
	gear.load_items()
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


## The class chosen in the Profile (falls back to the first).
func chosen_class() -> ClassData:
	if Profile.class_id == "trickster" and city.trickster_unlocked() and not Profile.custom.is_empty():
		return city.build_trickster()
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
	bonus_hp = 0
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
	deck.carry_start_skill()
	city.carry_loadout()
	city.apply_restorations()
	stats_changed()
	hp = max_hp
	mp = max_mp
	route.plan = route.plan_rooms()


## What the last death left in the lost bag, and what it carried out (WT), for the results.
var last_bag: Array[String] = []
var last_saved: Array[String] = []


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


# ---------------------------------------------------------------- monster curve


static func raw_ehp(s: Dictionary) -> float:
	return float(s.get("HP", 100)) * (100.0 + float(s.get("DP", 0))) / 100.0


static func raw_hit(s: Dictionary) -> float:
	return 6.0 + float(s.get("AP", 4)) * 0.25


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
	s.HP += bonus_hp
	for w: WardrobeData in ([] if _baseline else worn_pieces()):
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


# ---------------------------------------------------------------- materials and compounding


# ---------------------------------------------------------------- shop

