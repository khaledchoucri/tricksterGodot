class_name ThrownBlade
extends Node2D
## Inferno Blade: the sword spins out along the aim, hangs for a moment, and
## flies back to the thrower, burning and cutting what it passes through.

signal returned

var texture: Texture2D
var thrower: Node2D
var direction := Vector2.RIGHT  # screen space, normalized
var distance := 210.0
var out_time := 0.42
var hang_time := 0.25
var back_time := 0.38
var radius := 30.0              # ground-plane hit radius
var tick := 0.2                 # seconds between hits on the same enemy
var height := 22.0              # flies above the ground
## on_hit(enemy) for every tick that touches an enemy.
var on_hit: Callable
var room: Room

var _t := 0.0
var _origin := Vector2.ZERO
var _last_hit: Dictionary = {}  # Enemy -> time of last hit
var _sprite := Sprite2D.new()
var _trail: PackedVector2Array = []


func _ready() -> void:
	z_index = 14
	_origin = global_position
	_sprite.texture = texture
	_sprite.position.y = -height
	_sprite.scale = Vector2(1.4, 1.4)
	_sprite.self_modulate = Color(1.4, 1.1, 0.9)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	var ground_pos: Vector2
	if _t < out_time:
		var k := _t / out_time
		ground_pos = _origin + direction * distance * (1.0 - (1.0 - k) * (1.0 - k))
	elif _t < out_time + hang_time:
		ground_pos = _origin + direction * distance
	else:
		var k := clampf((_t - out_time - hang_time) / back_time, 0.0, 1.0)
		var far := _origin + direction * distance
		var home := thrower.global_position if is_instance_valid(thrower) else _origin
		ground_pos = far.lerp(home, k * k)
		if k >= 1.0:
			returned.emit()
			queue_free()
			return
	global_position = ground_pos
	_sprite.rotation += delta * 24.0
	_trail.append(global_position + Vector2(0, -height))
	if _trail.size() > 10:
		_trail.remove_at(0)
	if randf() < 0.5:
		Sparks.burst(room, global_position + Vector2(randf_range(-6, 6), -height), Color(1.0, 0.55, 0.15), 3, 40.0, 0.35, 2.0, -60.0)
	# on_hit can kill and remove enemies; keep this damage pass stable.
	for e: Enemy in room.enemies.duplicate():
		if not e.is_hittable() or not Combat.in_circle(global_position, e.global_position, radius, e.body_radius):
			continue
		if _t - float(_last_hit.get(e, -10.0)) >= tick:
			_last_hit[e] = _t
			on_hit.call(e)
	queue_redraw()


func _draw() -> void:
	for i in _trail.size():
		var k := float(i + 1) / _trail.size()
		draw_circle(_trail[i] - global_position, 16.0 * k, Color(1.0, 0.4 + 0.3 * k, 0.1, 0.45 * k))
	draw_circle(Vector2(0, -height), 30.0, Color(1.0, 0.55, 0.15, 0.25))
	draw_circle(Vector2(0, -height), 18.0, Color(1.0, 0.8, 0.4, 0.35))
