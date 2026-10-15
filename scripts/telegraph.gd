class_name Telegraph
extends Node2D
## Ground warning for an enemy attack. Fills from the inside out over
## `duration`, flashes when the attack lands, then removes itself.
## Shapes: "circle" (radius), "wedge" (radius, arc), "lane" (length, width).

const HOSTILE := Color(0.88, 0.25, 0.22)
const SPAWN := Color(0.3, 0.75, 0.8)

var shape := "circle"
var radius := 60.0
var arc := deg_to_rad(90.0)
var length := 140.0
var width := 34.0
var dir := Vector2.RIGHT
var duration := 0.7
var color := HOSTILE

var _t := 0.0
var _flash := -1.0


static func make(p_shape: String, p_duration: float, opts := {}) -> Telegraph:
	var t := Telegraph.new()
	t.shape = p_shape
	t.duration = maxf(p_duration, 0.01)
	for k in opts:
		t.set(k, opts[k])
	t.z_index = -1
	return t


func trigger() -> void:
	_flash = 0.12


func _process(delta: float) -> void:
	if _flash >= 0.0:
		_flash -= delta
		if _flash < 0.0:
			queue_free()
	else:
		_t = minf(_t + delta, duration)
	queue_redraw()


func _draw() -> void:
	var p := _t / duration
	var fill := Color(color, 0.18 + 0.22 * p)
	var edge := Color(color, 0.9)
	if _flash >= 0.0:
		fill = Color(1, 0.95, 0.85, 0.55)
		p = 1.0
	match shape:
		"circle":
			_iso_ellipse(radius, Color(color, 0.12))
			_iso_ellipse(radius * p, fill)
			_iso_ring(radius, edge)
		"wedge":
			_wedge(radius, Color(color, 0.12))
			_wedge(radius * p, fill)
			_wedge_outline(radius, edge)
		"lane":
			_lane(length, Color(color, 0.12))
			_lane(length * p, fill)
			_lane_outline(length, edge)


# Ground shapes are squashed 2:1 so they read as lying on the isometric floor.
func _iso(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 0.5)


func _iso_ellipse(r: float, c: Color) -> void:
	if r <= 0.5:
		return
	var pts := PackedVector2Array()
	for i in 40:
		pts.append(_iso(Vector2.from_angle(TAU * i / 40.0) * r))
	draw_colored_polygon(pts, c)


func _iso_ring(r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		pts.append(_iso(Vector2.from_angle(TAU * i / 40.0) * r))
	draw_polyline(pts, c, 1.5, true)


func _wedge_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var a0 := dir.angle() - arc / 2.0
	for i in 17:
		pts.append(_iso(Vector2.from_angle(a0 + arc * i / 16.0) * r))
	return pts


func _wedge(r: float, c: Color) -> void:
	if r > 0.5:
		draw_colored_polygon(_wedge_points(r), c)


func _wedge_outline(r: float, c: Color) -> void:
	var pts := _wedge_points(r)
	pts.append(Vector2.ZERO)
	draw_polyline(pts, c, 1.5, true)


func _lane_points(l: float) -> PackedVector2Array:
	var n := dir.orthogonal() * width / 2.0
	return PackedVector2Array([_iso(n), _iso(n + dir * l), _iso(-n + dir * l), _iso(-n)])


func _lane(l: float, c: Color) -> void:
	if l > 0.5:
		draw_colored_polygon(_lane_points(l), c)


func _lane_outline(l: float, c: Color) -> void:
	var pts := _lane_points(l)
	pts.append(pts[0])
	draw_polyline(pts, c, 1.5, true)
