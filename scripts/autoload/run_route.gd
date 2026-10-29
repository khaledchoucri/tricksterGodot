class_name RunRoute
extends RefCounted
## The run's route (Run.route): the chunk it plays, its regions, the planned rooms and how deep
## you are.

## Every chunk, in order (a run is one chunk of three regions).
const CHUNK_PATHS: Array[String] = ["res://data/chunks/chunk_1.tres", "res://data/chunks/chunk_2.tres"]
var chunks: Array[ChunkData] = []
## The chunk being played (its defaults are chunk 1's until use_chunk()).
var chunk := ChunkData.new()
## The chunk's regions, in order; the last one's boss ends the run.
var regions: Array[RegionData] = []

## The region of the room the run is in.
var region: RegionData:
	get:
		return plan[depth].region if depth < plan.size() else regions[0]

## Rooms cleared so far: the index of the current room in `plan`.
var depth := 0
## Every room of the run, region by region, each region ending in its boss, with a rest stop
## between regions.
var plan: Array[RoomPlan] = []


func load_chunks() -> void:
	for p in CHUNK_PATHS:
		chunks.append(load(p))


## Plays chunk `c`: its regions become the route's.
func use_chunk(c: ChunkData) -> void:
	chunk = c
	regions.assign(c.regions)


## The chunk numbered `n`, or null.
func chunk_numbered(n: int) -> ChunkData:
	for c in chunks:
		if c.number == n:
			return c
	return null


## Every region of every chunk (the card registry and city crafting know them all).
func all_regions() -> Array[RegionData]:
	var out: Array[RegionData] = []
	for c in chunks:
		for r in c.regions:
			if not r in out:
				out.append(r)
	for r in regions:
		if not r in out:
			out.append(r)
	return out


## A fresh plan: each region's rest stop on the way in (after the first), its rooms
## shuffled (the run's RNG) with its elite depths marked, then its boss room.
func plan_rooms() -> Array[RoomPlan]:
	var out: Array[RoomPlan] = []
	for r in regions:
		if r.gate and not out.is_empty():
			var stop := RoomPlan.new(r.gate.room, r, -1)
			stop.rest = r.gate
			out.append(stop)
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
