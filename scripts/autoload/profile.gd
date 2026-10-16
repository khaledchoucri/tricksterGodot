extends Node
## The player's saved progress across runs (autoloaded as `Profile`): banked
## Time Marks and Harkon Shards, run statistics, story flags and the city's
## restorations. Saved as JSON in user://profile.json after every change.

const VERSION := 1
const DEFAULT_PATH := "user://profile.json"

var path := DEFAULT_PATH

var tm := 0
var shards := 0
## Lifetime totals and counters, used by story conditions.
var stats := {"runs": 0, "deaths": 0, "clears": 0, "best_depth": 0, "shards_found": 0, "tm_earned": 0}
var flags: Dictionary = {}         # String -> true
var restorations: Dictionary = {}  # restoration id -> level


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
	stats = {"runs": 0, "deaths": 0, "clears": 0, "best_depth": 0, "shards_found": 0, "tm_earned": 0}
	flags = {}
	restorations = {}
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Profile at %s is unreadable; starting fresh" % path)
		return
	tm = int(data.get("tm", 0))
	shards = int(data.get("shards", 0))
	for k: String in data.get("stats", {}):
		stats[k] = int(data.stats[k])
	flags = data.get("flags", {})
	for k: String in data.get("restorations", {}):
		restorations[k] = int(data.restorations[k])


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't save the profile to %s" % path)
		return
	f.store_string(JSON.stringify({"version": VERSION, "tm": tm, "shards": shards, "stats": stats,
		"flags": flags, "restorations": restorations}, "  "))


func is_new() -> bool:
	return stats.runs == 0 and flags.is_empty()


# ---------------------------------------------------------------- runs

## Banks what a finished run carried home.
func bank_run(won: bool, depth: int, run_tm: int, run_shards: int) -> void:
	stats.runs += 1
	if won:
		stats.clears += 1
	else:
		stats.deaths += 1
	stats.best_depth = maxi(stats.best_depth, depth)
	stats.shards_found += run_shards
	stats.tm_earned += run_tm
	tm += run_tm
	shards += run_shards
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
