class_name MaterialData
extends Resource
## A monster's signature drop. At a Compounder, `need` of them go into a
## gear compound slot and roll `stat` between `min_value` and `max_value`
## (the original Maturing_Compound ranges, or ours where the original drop
## couldn't be compounded).

## Elements a material can add attack in (Trickster's attributes).
const ELEMENTS: Array[String] = ["Fire", "Water", "Wind", "Earth", "Elec", "Light", "Dark"]

@export var id: StringName
@export var display_name := ""
## Row ID in the ItemParam tables (icon).
@export var item_id := 0
## A Stats key (AP, DP...) or an element from ELEMENTS (elemental attack).
@export var stat := "HP"
@export var min_value := 1
@export var max_value := 5
## How many one compound uses.
@export var need := 3


func icon() -> Texture2D:
	var path := Assets.item_icon(item_id)
	return load(path) if ResourceLoader.exists(path) else null


func is_element() -> bool:
	return stat in ELEMENTS


func describe() -> String:
	return "%s %d–%d" % [stat + (" attack" if is_element() else ""), min_value, max_value]
