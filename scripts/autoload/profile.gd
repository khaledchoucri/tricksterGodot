extends Node
## The player's saved progress across runs (autoloaded as `Profile`): banked
## Time Marks and Harkon Shards, run statistics, story flags, the city's
## restorations, and the warehouse of items sent home (its loadout is worn
## in every run). Saved as JSON in user://profile.json after
## every change.

## Save schema 3 adds persistent warehouse identities (shelf positions remain UI indices).
const VERSION := 3
## The warehouse is the original's grid (WareHouseUI.ucf: 8 wide, 3 rows shown, up to 10 rows).
const WAREHOUSE_ROW := 8
const WAREHOUSE_ROWS_START := 3
const WAREHOUSE_ROWS_MAX := 10
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
## Items sent home (GearItem.to_dict()).
## Rows of shelves bought so far (Keeper Julio sells more for Harkon Shards).
var warehouse_rows := WAREHOUSE_ROWS_START
var warehouse: Array = []
## Monotonic identity allocator; never reuse an ID after a discard or lost bag.
var next_item_uid := 0
## What is worn from the warehouse in every run: gear slot key -> shelf index.
var loadout: Dictionary = {}
## The lost bag (empty: none): {"region", "room" (its depth in the region), "x", "y", "items"
## (GearItem.to_dict())}. Run.city drops and picks it up.
var lost_bag: Dictionary = {}
## A save from before the loadout carried one heirloom (its shelf, or -1): Run.city wears it.
var legacy_heirloom := -1
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
## The mastered skill each character starts runs with (class id -> card id).
var start_skills: Dictionary = {}
## The highest chunk each character has cleared (class id -> chunk number). Deviation (user,
## 2026-10-22): a chunk is played in one job tier, and clearing it opens the next chunk for
## that character in its next job (the original's job change at Lv 50 in Relics Town, after
## chunk 1's last region).
var chunks: Dictionary = {}
## The chunk each character sets out into (class id -> chunk number; chunk 1 when unset or closed).
var chunk_choice: Dictionary = {}
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
	next_item_uid = 0
	legacy_heirloom = -1
	warehouse_rows = WAREHOUSE_ROWS_START
	loadout = {}
	lost_bag = {}
	server_settings = {}
	best_heat = -1
	cards = {}
	wardrobe = []
	worn = {}
	mastery = {}
	start_skills = {}
	chunks = {}
	chunk_choice = {}
	class_id = "buffalo"
	drills = []
	drill = ""
	custom = {}
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
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
	for k: String in data.get("loadout", {}):
		loadout[k] = int(data.loadout[k])
	legacy_heirloom = int(data.get("heirloom", -1))
	warehouse_rows = clampi(int(data.get("warehouse_rows", WAREHOUSE_ROWS_START)), WAREHOUSE_ROWS_START, WAREHOUSE_ROWS_MAX)
	lost_bag = data.get("lost_bag", {})
	next_item_uid = int(data.get("next_item_uid", 0))
	_migrate_item_ids(data)
	if data.has("heirloom_uid"):
		legacy_heirloom = item_index(int(data.heirloom_uid))
	for k: String in data.get("server_settings", {}):
		server_settings[k] = int(data.server_settings[k])
	best_heat = int(data.get("best_heat", -1))
	for k: String in data.get("cards", {}):
		cards[k] = int(data.cards[k])
	wardrobe = data.get("wardrobe", [])
	worn = data.get("worn", {})
	for k: String in data.get("mastery", {}):
		mastery[k] = int(data.mastery[k])
	start_skills = data.get("start_skills", {})
	for k: String in data.get("chunks", {}):
		chunks[k] = int(data.chunks[k])
	for k: String in data.get("chunk_choice", {}):
		chunk_choice[k] = int(data.chunk_choice[k])
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
		"flags": flags, "restorations": restorations, "warehouse": warehouse, "warehouse_rows": warehouse_rows, "loadout_ids": _loadout_ids(), "lost_bag": lost_bag,
		"next_item_uid": next_item_uid, "heirloom_uid": item_uid(legacy_heirloom),
		"server_settings": server_settings, "best_heat": best_heat, "cards": cards, "wardrobe": wardrobe,
		"worn": worn, "mastery": mastery, "start_skills": start_skills, "chunks": chunks, "chunk_choice": chunk_choice, "class_id": class_id, "drills": drills, "drill": drill,
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


## The highest chunk `cls_id` has cleared (0: none yet).
func chunk_cleared(cls_id: String) -> int:
	return int(chunks.get(cls_id, 0))


## Records a clear of chunk `n` by `cls_id`. Returns whether it opened the next chunk.
func clear_chunk(cls_id: String, n: int) -> bool:
	if n <= chunk_cleared(cls_id):
		return false
	chunks[cls_id] = n
	save()
	return true


## Banks a run's leftover Galder, ore and materials (all of it on a clear,
## half after a rollback). Returns what was kept.
func bank_leftovers(won: bool, run_galder: int, run_ore: int, run_materials: Dictionary) -> Dictionary:
	var share := 1.0 if won else 0.5
	var kept := {"galder": int(run_galder * share), "ore": int(run_ore * share), "materials": 0}
	galder += kept.galder
	ore += kept.ore
	for id: StringName in run_materials:
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


## The persistent identity at a shelf index, or -1 if it no longer exists.
func item_uid(index: int) -> int:
	return int(warehouse[index].get("uid", -1)) if index >= 0 and index < warehouse.size() else -1


## Finds an identity's current shelf; live gear must never retain this index.
func item_index(uid: int) -> int:
	if uid >= 0:
		for i: int in warehouse.size():
			if item_uid(i) == uid:
				return i
	return -1


## Updates the same stored item even after lower shelves have been removed.
func update_item_id(uid: int, item: Dictionary) -> bool:
	var index := item_index(uid)
	if index < 0:
		return false
	update_item(index, item)
	return true


func _new_item_uid() -> int:
	var uid := next_item_uid
	next_item_uid += 1
	return uid


func _loadout_ids() -> Dictionary:
	var ids: Dictionary = {}
	for key: String in loadout:
		var uid := item_uid(int(loadout[key]))
		if uid >= 0:
			ids[key] = uid
	return ids


## Version 1/2 loadouts use indices; version 3 persists IDs and resolves indices only for UI.
## Preserve every item, including unknown item definitions and legacy lost-bag entries.
func _migrate_item_ids(data: Dictionary) -> void:
	var entries: Array = warehouse + lost_bag.get("items", [])
	for entry: Dictionary in entries:
		next_item_uid = maxi(next_item_uid, int(entry.get("uid", -1)) + 1)
	var seen: Dictionary[int, bool] = {}
	for entry: Dictionary in entries:
		var uid := int(entry.get("uid", -1))
		if uid < 0 or seen.has(uid):
			uid = _new_item_uid()
		entry["uid"] = uid
		seen[uid] = true
	if data.has("loadout_ids"):
		loadout = {}
		for key: String in data.loadout_ids:
			var index := item_index(int(data.loadout_ids[key]))
			if index >= 0:
				loadout[key] = index


# ---------------------------------------------------------------- warehouse

## Stores an item sent home; returns its index, or -1 if the warehouse is full.
func store_item(item: Dictionary) -> int:
	if warehouse_full():
		return -1
	var entry := item.duplicate(true)
	if int(entry.get("uid", -1)) < 0 or item_index(int(entry.uid)) >= 0:
		entry["uid"] = _new_item_uid()
	else:
		next_item_uid = maxi(next_item_uid, int(entry.uid) + 1)
	warehouse.append(entry)
	save()
	return warehouse.size() - 1


## Saves a stored item's new state (worn and improved during a run).
func update_item(index: int, item: Dictionary) -> void:
	if index >= 0 and index < warehouse.size():
		var entry := item.duplicate(true)
		entry["uid"] = item_uid(index)
		warehouse[index] = entry
		save()


## How many items the warehouse holds: a row of 8 per row bought.
func warehouse_size() -> int:
	return WAREHOUSE_ROW * warehouse_rows


func warehouse_full() -> bool:
	return warehouse.size() >= warehouse_size()


## Ours: Harkon Shards for the next row (row 4 costs 1, each after it one more: 28 for all ten),
## or 0 when every row is bought.
func row_price() -> int:
	return 0 if warehouse_rows >= WAREHOUSE_ROWS_MAX else warehouse_rows - WAREHOUSE_ROWS_START + 1


## Buys the next row of shelves; false if it's the last row already or the shards are short.
func buy_row() -> bool:
	var price := row_price()
	if price <= 0 or shards < price:
		return false
	shards -= price
	warehouse_rows += 1
	save()
	return true


## Wears shelf `index` in gear slot `key` in every run (replacing what was there).
func wear_stored(index: int, key: String) -> void:
	if index < 0 or index >= warehouse.size():
		return
	for k: String in loadout.keys():
		if int(loadout[k]) == index:
			loadout.erase(k)
	loadout[key] = index
	save()


## Takes off what slot `key` wears from the shelves.
func take_off(key: String) -> void:
	loadout.erase(key)
	save()


## The gear slot shelf `index` is worn in, or "".
func worn_in(index: int) -> String:
	for k: String in loadout:
		if int(loadout[k]) == index:
			return k
	return ""


func discard_item(index: int) -> void:
	if index < 0 or index >= warehouse.size():
		return
	warehouse.remove_at(index)
	if legacy_heirloom == index:
		legacy_heirloom = -1
	elif legacy_heirloom > index:
		legacy_heirloom -= 1
	for k: String in loadout.keys():
		var i := int(loadout[k])
		if i == index:
			loadout.erase(k)
		elif i > index:
			loadout[k] = i - 1
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
