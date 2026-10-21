class_name RegionData
extends Resource
## One expedition area: its rooms, monsters, cards and audio.

@export var display_name := ""
@export var rooms: Array[RoomData] = []
@export var boss_room: RoomData
## The rest stop on the way in, after the region before it (none for the first).
@export var gate: RestStopData
@export var enemies: Array[EnemyData] = []
@export var cards: Array[CardData] = []
## Combat rooms before the boss.
@export var run_length := 9
@export var elite_depths: Array[int] = [3, 7]
## Ours: the item levels its rooms offer, from the first room (x) to the boss (y). Each region
## follows on from the one before, whatever the run's length.
@export var gear_levels := Vector2i(1, 22)
## Depth of the room whose clear brings the job change (the trial).
@export var job_change_depth := 3
## Level sync: the highest refine an heirloom counts as here.
@export var refine_cap := 3
## Scales on the original monsters' HP and damage, so a region's numbers
## follow on from the one before.
@export var hp_scale := 1.0
@export var damage_scale := 1.0
## Scales on the TM and Galder monsters give (later regions' originals are
## much larger than a roguelite's economy wants).
@export var tm_scale := 1.0
@export var galder_scale := 1.0
@export var field_music := ""
@export var boss_music := ""
@export var field_ambience := ""
@export var boss_ambience := ""


func enemy(id: StringName) -> EnemyData:
	for e in enemies:
		if e.id == id:
			return e
	return null


func card(id: StringName) -> CardData:
	for c in cards:
		if c.id == id:
			return c
	return null
