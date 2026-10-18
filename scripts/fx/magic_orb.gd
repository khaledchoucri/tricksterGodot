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
## An original sprite to draw instead of the glow (Cake texture name, e.g.
## Mana Arrow's "magic arrow"), its afterimage, and how it turns: "aim"
## points it along the flight (the sprite points up), "spin" spins it.
## Original sprites are light, drawn additively (their black is transparent),
## whenever the sprite is set, before or after the orb enters the room.
var sprite := "":
	set(value):
		sprite = value
		material = Cake._material("ADD") if value != "" else null
var trail_sprite := ""
var sprite_scale := 1.0
var turn := "aim"

var _spin := 0.0

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
	_spin += delta * 9.0
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
	if sprite != "":
		_draw_sprite(up)
		return
	for i in _trail.size():
		var k := float(i + 1) / _trail.size()
		draw_circle(_trail[i] - global_position + up, radius * 0.7 * k, Color(color, 0.25 * k))
	draw_circle(up, radius * 1.4, Color(color, 0.35))
	draw_circle(up, radius, Color(color, 0.9))
	draw_circle(up, radius * 0.5, Color(1, 1, 1, 0.95))


## The original sprite, with its afterimage along the last few positions.
func _draw_sprite(up: Vector2) -> void:
	var angle := direction.angle() + PI / 2.0 if turn == "aim" else _spin
	var after := Cake._texture(trail_sprite) if trail_sprite != "" else {}
	if not after.is_empty():
		for i in _trail.size() - 1:
			var k := float(i + 1) / _trail.size()
			_blit(after, i % after.frames.size(), _trail[i] - global_position + up, angle, sprite_scale * (0.6 + 0.4 * k), k * 0.6)
	var main := Cake._texture(sprite)
	if not main.is_empty():
		_blit(main, 0, up, angle, sprite_scale, 1.0)


func _blit(tex: Dictionary, frame: int, at: Vector2, angle: float, k: float, alpha: float) -> void:
	var f: Array = tex.frames[frame]
	var size := Vector2(float(f[1]), float(f[2])) * k
	draw_set_transform(at, angle)
	draw_texture_rect_region(tex.tex, Rect2(-size / 2.0, size), Rect2(float(f[0]), 0.0, float(f[1]), float(f[2])),
		Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0)
