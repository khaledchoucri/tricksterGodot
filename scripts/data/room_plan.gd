class_name RoomPlan
extends RefCounted
## A room in this run's plan: which room, and how it's modified.

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
