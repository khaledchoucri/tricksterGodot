class_name Slash
extends Node2D
## Crescent trail left by a sword swing. Sweeps from one side of the arc to
## the other on the ground plane, then fades. Drawn above actors.

var radius := 58.0
var arc := deg_to_rad(140.0)
var dir := Vector2.RIGHT      # ground-plane aim
var clockwise := true
var sweep_time := 0.08
var life := 0.22
var width := 14.0
var color := Color(1.0, 0.97, 0.88)

var _t := 0.0


static func spawn(parent: Node, at: Vector2, opts := {}) -> Slash:
	var s := Slash.new()
	for k: String in opts:
		s.set(k, opts[k])
	s.z_index = 15
	parent.add_child(s)
	s.global_position = at
	return s


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var head := clampf(_t / sweep_time, 0.0, 1.0)            # leading edge, 0..1 along the arc
	var tail := clampf((_t - sweep_time * 0.5) / (life - sweep_time * 0.5), 0.0, 1.0)  # trailing edge
	if head <= tail:
		return
	var fade := 1.0 - clampf((_t - sweep_time) / (life - sweep_time), 0.0, 1.0)
	var a0 := dir.angle() + (-arc / 2.0 if clockwise else arc / 2.0)
	var span := arc if clockwise else -arc
	var steps := 18
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var f := lerpf(tail, head, float(i) / steps)
		var a := a0 + span * f
		# Thickest near the leading edge, tapering to nothing at the tail.
		var w := maxf(1.0, width * pow(float(i) / steps, 0.7))
		outer.append(_iso(Vector2.from_angle(a) * radius))
		inner.append(_iso(Vector2.from_angle(a) * (radius - w)))
	inner.reverse()
	var poly := outer + inner
	draw_colored_polygon(poly, Color(color, 0.85 * fade))
	draw_polyline(outer, Color(1, 1, 1, fade), 1.5, true)


func _iso(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 0.5)
