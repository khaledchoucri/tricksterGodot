class_name DrillData
extends Resource
## A drill, the persistent digging tool sold by Driller Marky. Numbers follow
## the original Item_DrillParam: how deep it can dig, how wide the timing
## bar's sweet spot is, how fast the marker moves, and how much each good
## strike digs.

@export var id: StringName
@export var display_name := ""
## Row ID in the ItemParam tables (icon).
@export var item_id := 0
## Deepest it can go (original DigDepth).
@export var depth := 20
## Sweet spot width as a share of the bar (original BarEffArea / 1000).
@export var zone := 0.14
## Marker sweeps per second (original BarSpeed / 100).
@export var speed := 0.6
## Depth per good strike (original ScoopMass x 10).
@export var scoop := 10
@export var strikes := 5
@export var price_tm := 0
@export var price_shards := 0


func icon() -> Texture2D:
	var path := Assets.item_icon(item_id)
	return load(path) if ResourceLoader.exists(path) else null


func describe() -> String:
	return "Digs up to %d deep  ·  sweet spot %d%%  ·  %d strikes" % [depth, roundi(zone * 100), strikes]
