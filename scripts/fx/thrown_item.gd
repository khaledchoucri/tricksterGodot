class_name ThrownItem
extends Node2D
## A thrown hidden weapon in flight, as the client's WeaponThrow_Actor flies
## it (Trickster.bin 0x4478a0, 0x4484a0): a fixed flight time (the throw's
## 300 ms) from the hand to the target, the item turning a step every 100 ms
## instead of spinning smoothly. It follows the target if it moves.

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

var _from := Vector2.ZERO
var _t := 0.0
var _angle := 0.0


func _ready() -> void:
	z_index = 15
	_from = global_position
	_angle = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta
	if is_instance_valid(target) and target.is_hittable():
		target_point = target.global_position
	var k := clampf(_t / FLIGHT, 0.0, 1.0)
	global_position = _from.lerp(target_point, k)
	_angle = floorf(_t / STEP) * STEP_ANGLE
	queue_redraw()
	if k >= 1.0:
		if on_hit.is_valid():
			on_hit.call(target if is_instance_valid(target) and target.is_hittable() else null)
		queue_free()


func _draw() -> void:
	var h := lerpf(START_HEIGHT, END_HEIGHT, clampf(_t / FLIGHT, 0.0, 1.0))
	draw_set_transform(Vector2(0, -h), _angle)
	if icon:
		draw_texture(icon, -icon.get_size() / 2.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(0, -6), Vector2(6, 0), Vector2(0, 6)]),
			Color(0.85, 0.9, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0)
