class_name NpcData
extends Resource
## A character standing in the hub. Their conversations are in the story
## file under `id`.

@export var id: StringName
@export var display_name := ""
## Exported actor sprite name (original_assets/actors/<actor>).
@export var actor := ""
## Dialogue portrait (original_assets/portraits/<portrait>.png); empty for none.
@export var portrait := ""
## Position in the hub map, in world pixels.
@export var position := Vector2.ZERO
@export var facing := Vector2(-1, 1)
## Objects (signs, plaques) are read rather than talked to.
@export var is_object := false
