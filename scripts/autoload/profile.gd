extends Node
## The player's saved progress across runs (autoloaded as `Profile`): banked
## Time Marks and Harkon Shards, run statistics, story flags, the city's
## restorations, and the warehouse of items sent home (one can be carried
## into runs as an heirloom). Saved as JSON in user://profile.json after
## every change.

const VERSION := 2
const WAREHOUSE_SIZE := 20
const DEFAULT_PATH := "user://profile.json"

var path := DEFAULT_PATH

var tm := 0
var shards := 0
## Run leftovers kept in the city for crafting on stored items.
var galder := 0
var ore := 0
var materials: Dictionary = {}  # MaterialData id (String) -> count
## Lifetime totals and counters, used by story conditions.
var stats := {"runs": 0, "deaths": 0, "clears": 0, "best_depth": 0, "shards_found": 0, "tm_earned": 0}
var flags: Dictionary = {}         # String -> true
var restorations: Dictionary = {}  # restoration id -> level
## Items sent home (GearItem.to_dict()), and which one runs carry (-1: none).
var warehouse: Array = []
var heirloom := -1
## GM console ranks (ServerSettings ids -> rank) and the best Heat cleared.
var server_settings: Dictionary = {}
var best_heat := -1
## Monster cards collected (EnemyData id -> count), wardrobe pieces owned and
## what's worn in each wardrobe slot.
var cards: Dictionary = {}
var wardrobe: Array = []
var worn: Dictionary = {}
## Master levels per skill card (card id -> 0..3): each raises its cap by one.
var mastery: Dictionary = {}
## The class played (ClassData id).
var class_id := "buffalo"
## The custom Trickster: {"kit": sword/hammer/fists, "graph": preset name,
## "trees": [JobData ids]}.
var custom: Dictionary = {}
## Drills owned and the one carried (DrillData ids).
var drills: Array = []
var drill := ""


func _ready() -> void:
	load_profile()


## Points the profile at another file (tests use a throwaway one) and loads it.
func use_path(p_path: String, wipe := false) -> void:
	path = p_path
	if wipe and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	load_profile()


func load_profile() -> void:
	tm = 0
	shards = 0
	galder = 0
	ore = 0
	materials = {}
	stats = {"runs": 0, "deaths": 0, "clears": 0, "best_depth": 0, "shards_found": 0, "tm_earned": 0}
	flags = {}
	restorations = {}
	warehouse = []
	heirloom = -1
	server_settings = {}
	best_heat = -1
	cards = {}
	wardrobe = []
	worn = {}
	mastery = {}
	class_id = "buffalo"
	drills = []
	drill = ""
	custom = {}
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Profile at %s is unreadable; starting fresh" % path)
		return
	tm = int(data.get("tm", 0))
	shards = int(data.get("shards", 0))
	galder = int(data.get("galder", 0))
	ore = int(data.get("ore", 0))
	for k: String in data.get("materials", {}):
		materials[k] = int(data.materials[k])
	for k: String in data.get("stats", {}):
		stats[k] = int(data.stats[k])
	flags = data.get("flags", {})
	for k: String in data.get("restorations", {}):
		restorations[k] = int(data.restorations[k])
	warehouse = data.get("warehouse", [])
	heirloom = int(data.get("heirloom", -1))
	for k: String in data.get("server_settings", {}):
		server_settings[k] = int(data.server_settings[k])
	best_heat = int(data.get("best_heat", -1))
	for k: String in data.get("cards", {}):
		cards[k] = int(data.cards[k])
	wardrobe = data.get("wardrobe", [])
	worn = data.get("worn", {})
	for k: String in data.get("mastery", {}):
		mastery[k] = int(data.mastery[k])
	class_id = data.get("class_id", "buffalo")
	drills = data.get("drills", [])
	custom = data.get("custom", {})
	drill = data.get("drill", "")


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't save the profile to %s" % path)
		return
	f.store_string(JSON.stringify({"version": VERSION, "tm": tm, "shards": shards, "galder": galder, "ore": ore,
		"materials": materials, "stats": stats,
		"flags": flags, "restorations": restorations, "warehouse": warehouse, "heirloom": heirloom,
		"server_settings": server_settings, "best_heat": best_heat, "cards": cards, "wardrobe": wardrobe,
		"worn": worn, "mastery": mastery, "class_id": class_id, "drills": drills, "drill": drill,
		"custom": custom}, "  "))


func is_new() -> bool:
	return stats.runs == 0 and flags.is_empty()


# ---------------------------------------------------------------- runs

## Banks what a finished run carried home. `job` is the job it ended in
## (clears per job unlock branches like the Mercenary).
func bank_run(won: bool, depth: int, run_tm: int, run_shards: int, job := "") -> void:
	stats.runs += 1
	if won:
		stats.clears += 1
		if job != "":
			stats["clears_" + job] = int(stats.get("clears_" + job, 0)) + 1
	else:
		stats.deaths += 1
	stats.best_depth = maxi(stats.best_depth, depth)
	stats.shards_found += run_shards
	stats.tm_earned += run_tm
	tm += run_tm
	shards += run_shards
	save()


## Banks a run's leftover Galder, ore and materials (all of it on a clear,
## half after a rollback). Returns what was kept.
func bank_leftovers(won: bool, run_galder: int, run_ore: int, run_materials: Dictionary) -> Dictionary:
	var share := 1.0 if won else 0.5
	var kept := {"galder": int(run_galder * share), "ore": int(run_ore * share), "materials": 0}
	galder += kept.galder
	ore += kept.ore
	for id in run_materials:
		var n := int(run_materials[id] * share)
		if n > 0:
			materials[String(id)] = int(materials.get(String(id), 0)) + n
			kept.materials += n
	save()
	return kept


## Registers a monster card. Returns true the first time.
func add_card(enemy_id: StringName) -> bool:
	var k := String(enemy_id)
	var first := not cards.has(k)
	cards[k] = int(cards.get(k, 0)) + 1
	save()
	return first


func owns(piece: StringName) -> bool:
	return String(piece) in wardrobe


func give_wardrobe(piece: StringName) -> void:
	if not owns(piece):
		wardrobe.append(String(piece))
		save()


## Wears a piece in its slot (or takes it off when `piece` is empty).
func wear(slot: String, piece: StringName) -> void:
	if piece == &"":
		worn.erase(slot)
	else:
		worn[slot] = String(piece)
	save()


# ---------------------------------------------------------------- warehouse

## Stores an item sent home; returns its index, or -1 if the warehouse is full.
func store_item(item: Dictionary) -> int:
	if warehouse.size() >= WAREHOUSE_SIZE:
		return -1
	warehouse.append(item)
	save()
	return warehouse.size() - 1


## Saves a stored item's new state (an heirloom improved during a run).
func update_item(index: int, item: Dictionary) -> void:
	if index >= 0 and index < warehouse.size():
		warehouse[index] = item
		save()


func set_heirloom(index: int) -> void:
	heirloom = index if index >= 0 and index < warehouse.size() else -1
	save()


func discard_item(index: int) -> void:
	if index < 0 or index >= warehouse.size():
		return
	warehouse.remove_at(index)
	if heirloom == index:
		heirloom = -1
	elif heirloom > index:
		heirloom -= 1
	save()


# ---------------------------------------------------------------- story

func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String) -> void:
	if not flags.has(flag):
		flags[flag] = true
		save()


# ---------------------------------------------------------------- restorations

func level(id: StringName) -> int:
	return restorations.get(String(id), 0)


func can_buy(r: RestorationData) -> bool:
	var lvl := level(r.id)
	return lvl < r.max_level and tm >= r.tm_cost(lvl + 1) and shards >= r.shard_cost(lvl + 1)


func buy(r: RestorationData) -> bool:
	if not can_buy(r):
		return false
	var next := level(r.id) + 1
	tm -= r.tm_cost(next)
	shards -= r.shard_cost(next)
	restorations[String(r.id)] = next
	save()
	return true
