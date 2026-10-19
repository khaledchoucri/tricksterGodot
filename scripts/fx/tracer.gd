class_name Tracer
extends Node2D
## A gun shot's streak from the muzzle to where it stopped, gone in a blink.

const LIFE := 0.09

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0


static func spawn(room: Node, p_from: Vector2, p_to: Vector2) -> Tracer:
	var t := Tracer.new()
	t.from = p_from
	t.to = p_to
	t.z_index = 16
	room.add_child(t)
	return t


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - _t / LIFE
	draw_line(from, to, Color(1.0, 0.95, 0.75, 0.85 * k), 2.0)
	draw_line(from, from.lerp(to, 0.12), Color(1.0, 1.0, 1.0, k), 3.0)
