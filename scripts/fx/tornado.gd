class_name Tornado
extends Node2D
## Tornado Bomb: a whirlwind that drifts along the aim, dragging nearby
## enemies into its centre and cutting them repeatedly.

var direction := Vector2.RIGHT  # screen space, normalized
var speed := 85.0
var life := 2.2
var radius := 46.0              # ground-plane hit radius
var pull_radius := 110.0
var pull := 260.0               # pull speed at the edge, px/s
var tick := 0.28
var on_hit: Callable
var room: Room

var _t := 0.0
var _next_tick := 0.0


func _ready() -> void:
	z_index = 14


func _physics_process(delta: float) -> void:
	_t += delta
	var next := global_position + direction * speed * delta
	if room.is_inside(next):
		global_position = next
	if _t >= life:
		queue_free()
		return
	for e in room.enemies:
		if not e.is_hittable():
			continue
		var to := global_position - e.global_position
		var d := Combat.ground(to).length()
		if d < pull_radius and d > 6.0:
			e.nudge(to.normalized() * pull * (0.35 if e.is_boss else 1.0))
	if _t >= _next_tick:
		_next_tick = _t + tick
		for e in room.enemies:
			if e.is_hittable() and Combat.in_circle(global_position, e.global_position, radius, e.body_radius):
				on_hit.call(e)
		Sparks.burst(room, global_position + Vector2(0, -20), Color(0.85, 1.0, 0.95, 0.8), 6, 90.0, 0.35, 2.0)
	queue_redraw()


func _draw() -> void:
	var fade := minf(1.0, minf(_t / 0.15, (life - _t) / 0.3))
	# Stacked spinning rings, wider toward the top.
	for i in 7:
		var h := float(i) / 6.0
		var r := 14.0 + h * 42.0
		var y := -h * 80.0
		var spin := _t * (9.0 + i) + i * 0.7
		var pts := PackedVector2Array()
		for k in 25:
			var a := spin + TAU * k / 24.0
			pts.append(Vector2(cos(a) * r + sin(_t * 5.0 + i) * 4.0, y + sin(a) * r * 0.3))
		draw_polyline(pts, Color(0.55, 0.85, 0.8, (0.35 + 0.35 * (1.0 - h)) * fade), 6.0 + (1.0 - h) * 3.0, true)
		draw_polyline(pts, Color(0.92, 1.0, 0.97, (0.55 + 0.4 * (1.0 - h)) * fade), 2.0 + (1.0 - h) * 2.0, true)
	# Ground swirl.
	var g := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		g.append(Vector2(cos(a) * radius, sin(a) * radius * 0.5))
	draw_colored_polygon(g, Color(0.75, 0.95, 0.9, 0.12 * fade))
	draw_polyline(g, Color(0.8, 1.0, 0.95, 0.6 * fade), 2.0, true)
