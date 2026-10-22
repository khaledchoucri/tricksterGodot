class_name ThrownItem
extends Node2D
## A thrown hidden weapon in flight, as the client's WeaponThrow_Actor flies
## it (Trickster.bin 0x4478a0, 0x4484a0): a fixed flight time (the throw's
## 300 ms) from the hand to the target, the item turning a step every 100 ms
## instead of spinning smoothly. It follows the target if it moves, unless
## told to keep to its line (`homing`).
## Given a `cake` (an original effect, e.g. the client's flying card
## eft_skl_c_301_sut), it flies as that effect instead of the icon.

const FLIGHT := 0.3
const STEP := 0.1
const STEP_ANGLE := PI / 2.0
const START_HEIGHT := 40.0
const END_HEIGHT := 22.0

var room: Room
var target: Enemy
var target_point := Vector2.ZERO
var icon: Texture2D
var on_hit: Callable  # called with the enemy (or null) on arrival
## The original effect it flies as, when exported ("" draws `icon`).
var cake := ""
## Whether it follows the target if it moves (a fanned card keeps to its line).
var homing := true

var _from := Vector2.INF  # taken on the first frame: callers place it after add_child()
var _t := 0.0
var _angle := 0.0
var _lift: Node2D  # where a flying cake sits: the item's height above its ground spot


func _ready() -> void:
	z_index = 15
	_angle = randf() * TAU
	if cake != "" and Cake.has(cake):
		_lift = Node2D.new()
		_lift.position = Vector2(0, -START_HEIGHT)
		add_child(_lift)
		Cake.play(_lift, cake, _lift.global_position, {"hold": 0.0})  # it lands with the item


func _physics_process(delta: float) -> void:
	if _from == Vector2.INF:
		_from = global_position
	_t += delta
	if homing and is_instance_valid(target) and target.is_hittable():
		target_point = target.global_position
	var k := clampf(_t / FLIGHT, 0.0, 1.0)
	global_position = _from.lerp(target_point, k)
	_angle = floorf(_t / STEP) * STEP_ANGLE
	if _lift:
		_lift.position = Vector2(0, -_height())
	else:
		queue_redraw()
	if k >= 1.0:
		if on_hit.is_valid():
			on_hit.call(target if is_instance_valid(target) and target.is_hittable() else null)
		queue_free()


func _height() -> float:
	return lerpf(START_HEIGHT, END_HEIGHT, clampf(_t / FLIGHT, 0.0, 1.0))


func _draw() -> void:
	if _lift:
		return  # the cake is the item
	draw_set_transform(Vector2(0, -_height()), _angle)
	if icon:
		draw_texture(icon, -icon.get_size() / 2.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(0, -6), Vector2(6, 0), Vector2(0, 6)]),
			Color(0.85, 0.9, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0)
