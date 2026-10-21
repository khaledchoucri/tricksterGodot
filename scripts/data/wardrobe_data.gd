class_name WardrobeData
extends Resource
## A wardrobe piece: one of the slow, persistent slots (ear, tail, head,
## face, cape, speed) worn between runs. Small stats and a quirk, its `mods`
## (summed with the rest by Run.mod()). Earned from card sets or bought from the
## Card Hunter with TM and shards.

const SLOTS: Array[String] = ["ear", "tail", "head", "face", "cape", "speed"]
const SLOT_NAMES := {"ear": "Ear", "tail": "Tail", "head": "Head", "face": "Face", "cape": "Cape", "speed": "Speed"}

@export var id: StringName
@export var display_name := ""
## Row ID in the ItemParam tables (icon).
@export var item_id := 0
@export_enum("ear", "tail", "head", "face", "cape", "speed") var slot := "ear"
## Stat key (Stats.KEYS) -> value.
@export var stats: Dictionary = {}
## The quirk: Mod key -> amount (see scripts/data/mod.gd).
@export var mods: Dictionary[String, float] = {}
@export_multiline var text := ""
## Card Hunter prices; 0 TM means it can only be earned from a card set.
@export var price_tm := 0
@export var price_shards := 0


func icon() -> Texture2D:
	var path := Assets.item_icon(item_id)
	return load(path) if ResourceLoader.exists(path) else null


func describe() -> String:
	var parts: PackedStringArray = []
	for k in Stats.KEYS:
		if stats.has(k):
			parts.append("%s +%d" % [k, stats[k]])
	return ("  ·  ".join(parts) + "\n" if parts.size() else "") + text


## The sprite worn on the character ("" for sprints, which aren't seen).
func worn_sprite() -> String:
	return ItemData.worn_sprite_for(item_id)
