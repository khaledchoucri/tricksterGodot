class_name RunRoute
extends RefCounted
## The run's route (Run.route): the regions it crosses, the planned rooms and how deep you are.

## Regions a run passes through, in order; the last one's boss ends it.
const REGION_PATHS: Array[String] = ["res://data/coral_beach/region.tres", "res://data/desert_beach/region.tres",
	"res://data/caballa_relics/region.tres"]
var regions: Array[RegionData] = []

## The region of the room the run is in.
var region: RegionData:
	get:
		return plan[depth].region if depth < plan.size() else regions[0]

## Rooms cleared so far: the index of the current room in `plan`.
var depth := 0
## Every room of the run, region by region, each region ending in its boss.
var plan: Array[RoomPlan] = []


## A fresh plan: each region's rooms shuffled (the run's RNG), its elite depths marked,
## then its boss room.
func plan_rooms() -> Array[RoomPlan]:
	var out: Array[RoomPlan] = []
	for r in regions:
		var pool := r.rooms.duplicate()
		Run.shuffle(pool)
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


## An enemy from any region (or an Echo).
func enemy(id: StringName) -> EnemyData:
	for r in regions:
		var e := r.enemy(id)
		if e:
			return e
	for e in Run.echoes:
		if e.id == id:
			return e
	return null
