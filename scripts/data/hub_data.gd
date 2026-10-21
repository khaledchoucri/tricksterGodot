class_name HubData
extends Resource
## The town between runs: its room, people, restorations and story file.

@export var display_name := ""
@export var room: RoomData
@export var npcs: Array[NpcData] = []
@export var restorations: Array[RestorationData] = []
## Where the expedition gate stands, in world pixels.
@export var gate_position := Vector2.ZERO
## JSON file with every NPC's conversations (see scripts/story/story.gd).
@export_file("*.json") var story := ""
@export var music := ""
## Wardrobe pieces in the game, and the Card Hunter's bestiary sets.
@export var wardrobe: Array[WardrobeData] = []
@export var card_sets: Array[CardSetData] = []
## Drills Driller Marky sells (the first comes free with the Drill Shop).
@export var drills: Array[DrillData] = []
@export var ambience := ""
## The custom Trickster's starting skill (its job's starter).
@export var trickster_starter: CardData
