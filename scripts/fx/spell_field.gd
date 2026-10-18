class_name SpellField
extends Node2D
## A spell that lingers on the ground (Tesla Field, Scorching Earth, Deadly
## Fen, Whirlwind, the Soul Master's Gardens): every `tick` seconds it calls
## on_tick(enemies inside) until its life runs out or `ended` is set.

var radius := 90.0        # ground-plane radius
var life := 4.0
var tick := 0.5
var color := Color(0.6, 0.85, 1.0)
## Called with the enemies inside, closest first.
var on_tick: Callable
## When true the field fades out at once (Whirlwind when its caster moves).
var ended := false
var room: Room
## Only a faint outline (an original effect shows the field).
var quiet := false

var _t := 0.0
var _next := 0.0


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	if ended:
		life = minf(life, _t + 0.2)
	if _t >= life:
		queue_free()
		return
	if _t >= _next:
		_next = _t + tick
		var inside: Array[Enemy] = []
		for e in room.enemies:
			if e.is_hittable() and Combat.in_circle(global_position, e.global_position, radius, e.body_radius):
				inside.append(e)
		inside.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
		if on_tick.is_valid():
			on_tick.call(inside)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((life - _t) / 0.4, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
	var pulse := 0.85 + 0.15 * sin(_t * 9.0)
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(Combat.screen(Vector2.from_angle(TAU * i / 32.0) * radius))
	if quiet:
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(color, 0.35 * fade), 1.5)
		return
	draw_colored_polygon(pts, Color(color, 0.18 * fade))
	var ring := pts.duplicate()
	ring.append(pts[0])  # outlines close the loop; the fill must not repeat a point
	draw_polyline(ring, Color(color, 0.8 * fade * pulse), 2.5)
	var inner := PackedVector2Array()
	for p in ring:
		inner.append(p * (0.55 + 0.1 * sin(_t * 5.0)))
	draw_polyline(inner, Color(color, 0.4 * fade), 1.5)
