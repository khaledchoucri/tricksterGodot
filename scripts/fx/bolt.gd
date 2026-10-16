class_name Bolt
extends Node2D
## A lightning bolt from the sky to a point on the ground, with a flash.

var height := 300.0
var life := 0.28
var color := Color(0.65, 0.8, 1.0)

var _t := 0.0
var _paths: Array[PackedVector2Array] = []


static func strike(parent: Node, at: Vector2) -> Bolt:
	var b := Bolt.new()
	b.z_index = 18
	parent.add_child(b)
	b.global_position = at
	return b


func _ready() -> void:
	for i in 3:
		_paths.append(_jagged())
	Ring.spawn(get_parent(), global_position, 46.0, 0.3, Color(0.75, 0.85, 1.0, 0.9))
	Sparks.burst(get_parent(), global_position, Color(0.8, 0.9, 1.0), 16, 160.0, 0.35, 2.5)


func _jagged() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(randf_range(-30, 30), -height)])
	var steps := 9
	for i in range(1, steps):
		var k := float(i) / steps
		pts.append(Vector2(randf_range(-16, 16) * (1.0 - k * 0.6), -height * (1.0 - k)))
	pts.append(Vector2.ZERO)
	return pts


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	elif int(_t * 40.0) % 3 == 0:
		_paths[randi() % _paths.size()] = _jagged()  # flicker
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t / life
	draw_circle(Vector2.ZERO, 26.0 * fade + 6.0, Color(color, 0.4 * fade))
	for i in _paths.size():
		var w := 7.0 if i == 0 else 3.0
		draw_polyline(_paths[i], Color(color, 0.45 * fade), w + 4.0, true)
		draw_polyline(_paths[i], Color(1, 1, 1, fade), w * 0.5, true)
