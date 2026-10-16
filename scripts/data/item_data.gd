class_name ItemData
extends Resource
## A piece of run gear: one of the six core slots (weapon, hat, shield,
## innerwear, two accessories). Stats, weight and level are the original
## item's (ItemParam tables); drops roll a GearItem from it.

enum Slot { WEAPON, HAT, SHIELD, INNERWEAR, ACCESSORY }

const SLOT_NAMES: Array[String] = ["Weapon", "Hat", "Shield", "Innerwear", "Accessory"]

@export var id: StringName
@export var display_name := ""
## Row ID in the ItemParam tables (icon and held sprite).
@export var item_id := 0
@export var slot := Slot.WEAPON
## Weapons only: the fighting style it brings, "sword" or "hammer" (a
## ComboData in data/combos/).
@export var family := ""
## Earliest point in a run it can drop: compared with 1 + 3 × depth.
@export var level := 1
@export var weight := 10
## Stat key (Stats.KEYS) -> value.
@export var stats: Dictionary = {}
## The stat refining raises (AP, DP, MA or MD); empty if it can't be refined.
@export var refine_stat := ""


func slot_name() -> String:
	return SLOT_NAMES[slot]


func icon() -> Texture2D:
	var path := "res://original_assets/icons/items/%d.png" % item_id
	return load(path) if ResourceLoader.exists(path) else null


## Name of the held sprite exported by tools/export_items.py.
func weapon_sprite() -> String:
	return "item_%d" % item_id
