class_name RestStopData
extends Resource
## A rest stop between two regions: the original's field gate on the way in (Gate of
## Desert Beach, Gate of Caballa Relics). Deviation (user, 2026-10-21): a Hades-like
## rest room, with no encounter, a story point, a free heal and the warehouse. Keeper
## Julio stands at both gates in the original (NpcTalk_Beach / NpcTalk_Relics, NPC 1045).

@export var room: RoomData
## Who stands here: their conversations are in `story` under their ids.
@export var npcs: Array[NpcData] = []
@export_file("*.json") var story := ""
## The gate's MapSound rows (BGM and ambience).
@export var music := ""
@export var ambience := ""
## Deviation (user, 2026-10-21): share of max HP and MP restored on arrival.
@export var heal_share := 0.5
