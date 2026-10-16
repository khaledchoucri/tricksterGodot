class_name RoomData
extends Resource
## A combat room cut from an original Trickster map.

@export var id: StringName
@export var display_name := ""
## Exported map folder under original_assets/maps.
@export var map := ""
## Room bounds in map pixels.
@export var rect := Rect2i()
