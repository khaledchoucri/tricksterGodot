class_name RegionData
extends Resource
## One expedition area: its rooms, monsters, cards and audio.

@export var display_name := ""
@export var rooms: Array[RoomData] = []
@export var boss_room: RoomData
@export var enemies: Array[EnemyData] = []
@export var cards: Array[CardData] = []
## Combat rooms before the boss.
@export var run_length := 7
@export var elite_depths: Array[int] = [3, 6]
## Depth of the room whose clear brings the job change (the trial).
@export var job_change_depth := 3
## Level sync: the highest refine an heirloom counts as here.
@export var refine_cap := 3
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
