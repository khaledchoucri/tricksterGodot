class_name RestorationData
extends Resource
## A part of the city the player can restore between runs with Time Marks
## and Harkon Shards. Each level gives a permanent bonus to every run.

@export var id: StringName
@export var display_name := ""
## What it does; "{v}" is replaced by the bonus at the shown level.
@export_multiline var text := ""
@export var max_level := 1
## Bonus per level (meaning depends on `effect`).
@export var per_level := 1.0
@export_enum("max_hp", "room_mp", "revive", "second_skill") var effect := "max_hp"
## Cost of each level: index 0 is level 1.
@export var tm_costs: Array[int] = []
@export var shard_costs: Array[int] = []


func tm_cost(lvl: int) -> int:
	return tm_costs[lvl - 1] if lvl - 1 < tm_costs.size() else 0


func shard_cost(lvl: int) -> int:
	return shard_costs[lvl - 1] if lvl - 1 < shard_costs.size() else 0


func describe(lvl: int) -> String:
	return text.replace("{v}", str(snappedf(per_level * maxi(lvl, 1), 0.1)).trim_suffix(".0"))
