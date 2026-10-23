class_name FallingRock
extends Node2D
## A rock falling from the ceiling onto a spot, landing after `fall` seconds (Tombeth's slam
## brings them down). Only the look: whoever drops it decides what the landing hits.

## How high above its spot it starts (screen pixels) and its size. Ours.
const HEIGHT := 360.0
const SIZE := 11.0
const COLOR := Color(0.55, 0.48, 0.42)

var fall := 0.9
var _t := 0.0
var _spin := 0.0


static func drop(parent: Node, at: Vector2, p_fall: float) -> FallingRock:
	var r := FallingRock.new()
	r.fall = maxf(p_fall, 0.05)
	r.z_index = 20
	r._spin = randf_range(-6.0, 6.0)  # visual only
	parent.add_child(r)
	r.global_position = at
	return r


func _process(delta: float) -> void:
	_t += delta
	if _t >= fall:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / fall, 0.0, 1.0)
	var y := -HEIGHT * (1.0 - p * p)  # falls faster as it comes
	var pts := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 7.0 + _t * _spin
		var k := 0.75 + 0.25 * float((i * 5) % 3) / 2.0
		pts.append(Vector2(0, y) + Vector2(cos(a), sin(a)) * SIZE * k)
	draw_colored_polygon(pts, COLOR)
	pts.append(pts[0])
	draw_polyline(pts, COLOR.darkened(0.45), 1.5, true)
