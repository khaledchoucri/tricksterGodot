class_name EnergyWave
extends Node2D
## A crescent of energy that flies straight along the ground, passing
## through enemies and obstacles and hitting each enemy once.

var direction := Vector2.RIGHT   # screen space, normalized
var speed := 430.0
var life := 0.8
var half_width := 46.0           # ground-plane half width of the crescent
var color := Color(0.55, 0.9, 1.0)
## Called once per enemy touched: on_hit(enemy).
var on_hit: Callable
var room: Room

var _t := 0.0
var _hit: Array[Enemy] = []
var _trail: PackedVector2Array = []


func _ready() -> void:
	z_index = 14


func _physics_process(delta: float) -> void:
	_t += delta
	position += direction * speed * delta
	_trail.append(position)
	if _trail.size() > 7:
		_trail.remove_at(0)
	if _t >= life or not room.is_inside(global_position):
		queue_free()
		return
	var g := Combat.ground(direction).normalized()
	# on_hit can kill and remove enemies; keep this damage pass stable.
	for e: Enemy in room.enemies.duplicate():
		if e in _hit or not e.is_hittable():
			continue
		if Combat.in_lane(global_position - Combat.screen(g) * 18.0, e.global_position, g, 36.0, half_width * 2.0, e.body_radius):
			_hit.append(e)
			on_hit.call(e)
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - clampf((_t - life * 0.7) / (life * 0.3), 0.0, 1.0)
	var g := Combat.ground(direction).normalized()
	var side := g.orthogonal()
	# Afterimages along the path.
	for i in _trail.size():
		var k := float(i + 1) / _trail.size()
		_crescent(_trail[i] - position, g, side, half_width * (0.5 + 0.5 * k), Color(color, 0.18 * k * fade))
	_crescent(Vector2.ZERO - Combat.screen(g) * 4.0, g, side, half_width * 1.15, Color(color, 0.35 * fade))
	_crescent(Vector2.ZERO, g, side, half_width, Color(color, 0.9 * fade))
	_crescent(Vector2.ZERO + Combat.screen(g) * 3.0, g, side, half_width * 0.7, Color(1, 1, 1, 0.9 * fade))


func _crescent(at: Vector2, g: Vector2, side: Vector2, w: float, c: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 13:
		var f := float(i) / 12.0 * 2.0 - 1.0   # -1..1 across the width
		var bulge := (1.0 - f * f) * 24.0
		outer.append(at + Combat.screen(side * f * w + g * bulge))
		inner.append(at + Combat.screen(side * f * w * 0.92 + g * bulge * 0.35))
	inner.reverse()
	draw_colored_polygon(outer + inner, c)
