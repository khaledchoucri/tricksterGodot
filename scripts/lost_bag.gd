class_name LostBag
extends Node2D
## The lost bag lying where a run fell (Profile.lost_bag): walking onto it picks it up, and
## Run.city puts its items back on the warehouse shelves.

signal picked_up(names: Array[String])

## How close the player walks to pick it up (ground distance).
const PICK_RANGE := 26.0
const BOB := 3.0

var room: Room
## Armed once the player has stood clear of it, so a bag left where the room spawns you is
## found by walking onto it, not grabbed the moment you arrive.
var _armed := false
var _t := 0.0
var _icon: Sprite2D


func _ready() -> void:
	_icon = Sprite2D.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var items: Array = Profile.lost_bag.get("items", [])
	var first := GearItem.from_dict(items[0], Run.gear.item_by_id) if items.size() else null
	_icon.texture = first.data.icon() if first else null
	add_child(_icon)
	var label := Label.new()
	label.text = "Lost bag · %d item%s" % [items.size(), "" if items.size() == 1 else "s"]
	label.add_theme_color_override("font_color", Color("f0c070"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-48, -40)
	label.size = Vector2(96, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func _process(delta: float) -> void:
	_t += delta
	_icon.position.y = sin(_t * 3.0) * BOB  # purely visual


func _physics_process(_delta: float) -> void:
	if room == null or not is_instance_valid(room.player) or room.player.state == Player.State.DEAD:
		return
	var near := Combat.ground(room.player.global_position - global_position).length() <= PICK_RANGE
	if not near:
		_armed = true
	elif _armed:
		var names := Run.city.pick_up_bag()
		picked_up.emit(names)
		queue_free()
