class_name Ring
extends Node2D
## Expanding ring on the ground, used for Shockwave, dash puffs and dust.

var max_radius := 90.0
var life := 0.35
var color := Color(1.0, 0.95, 0.8, 0.9)

var _t := 0.0


static func spawn(parent: Node, at: Vector2, radius: float, p_life := 0.35, p_color := Color(1.0, 0.95, 0.8, 0.9)) -> Ring:
	var r := Ring.new()
	r.max_radius = radius
	r.life = p_life
	r.color = p_color
	parent.add_child(r)
	r.global_position = at
	return r


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := _t / life
	var r := max_radius * (0.3 + 0.7 * p)
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, Color(color, color.a * (1.0 - p)), 3.0 * (1.0 - p) + 1.0, true)
