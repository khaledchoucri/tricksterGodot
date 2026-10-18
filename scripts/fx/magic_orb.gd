class_name MagicOrb
extends Node2D
## A spell projectile: flies from the caster toward a target (homing on it
## when one is given, else straight along `direction`) and hits the first
## enemy it touches, or bursts where it runs out of range.

const FLY_HEIGHT := 22.0  # drawn this far above the ground

var direction := Vector2.RIGHT  # screen space, normalized
var target: Enemy
var speed := 520.0
var range_left := 220.0
var radius := 10.0
var color := Color(0.6, 0.85, 1.0)
## Called with the enemy hit (or null when it fizzles at the end of its range).
var on_hit: Callable
var room: Room
## Drawn by an original flight effect riding on it instead of its own glow.
var quiet := false

var _trail: PackedVector2Array = []
var _done := false


func _ready() -> void:
	z_index = 15


func _physics_process(delta: float) -> void:
	if _done:
		return
	if is_instance_valid(target) and target.is_hittable():
		direction = (target.global_position - global_position).normalized()
	var step := direction * speed * delta
	global_position += step
	range_left -= step.length()
	_trail.append(global_position)
	if _trail.size() > 8:
		_trail.remove_at(0)
	for e in room.enemies:
		if e.is_hittable() and Combat.in_circle(global_position, e.global_position, radius, e.body_radius):
			_finish(e)
			return
	if range_left <= 0.0 or not room.is_inside(global_position):
		_finish(null)
		return
	queue_redraw()


func _finish(e: Enemy) -> void:
	_done = true
	if on_hit.is_valid():
		on_hit.call(e)
	Sparks.burst(room, global_position + Vector2(0, -FLY_HEIGHT), color, 10, 140.0)
	queue_free()


func _draw() -> void:
	if quiet:
		return
	var up := Vector2(0, -FLY_HEIGHT)
	for i in _trail.size():
		var k := float(i + 1) / _trail.size()
		draw_circle(_trail[i] - global_position + up, radius * 0.7 * k, Color(color, 0.25 * k))
	draw_circle(up, radius * 1.4, Color(color, 0.35))
	draw_circle(up, radius, Color(color, 0.9))
	draw_circle(up, radius * 0.5, Color(1, 1, 1, 0.95))
