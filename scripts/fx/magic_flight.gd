class_name MagicFlight
extends Node2D
## One Mana Arrow or Mana Ring as the original client flies it (Trickster.bin's
## ArrowCake/ArrowBall and RingCake code, read with Ghidra through REA):
##  - It appears beside the caster (+-50 on each axis, 30 up) `appear` seconds
##    in, spinning flat on the ground and drifting away from the target at
##    100/s (0x421120, 0x421320).
##  - At `fire` (the group's time: 0.3 s for arrows, 0.5 s for rings) it is
##    kicked back at 200/s. An arrow then waits a random 0-0.9 s (0x421400), so
##    Arrow Rush's arrows land one after another. A ring instead follows its
##    own random cubic curve to the target, 10 px a frame (0x434c10, 0x4342f0).
##  - Then it rushes: accelerating at 5000/s^2 toward the target, re-aimed
##    every frame, for at most 6 s, and hits within 50 (0x421ef0, 0x435460).
## Distances are the original's world units, taken as ground pixels here.

const DRIFT := 100.0      # away from the target while appearing
const KICK := 200.0       # away from the target when the group fires
const PULL := 5000.0      # rush acceleration toward the target
const REACH := 50.0       # hit distance
const MAX_RUSH := 6.0
const AIM_HEIGHT := 24.0  # where on a monster it homes
## A ring's curve advances 10 px per client frame; the client's frame rate
## isn't in the data, so 60 is assumed.
const CURVE_STEP := 10.0
const CURVE_FPS := 60.0

var room: Room
## Who it flies at: a monster (your spells) or you (a boss casting them back).
var target: Node2D
## Where to fly when there's no target (or it dies on the way).
var target_point := Vector2.ZERO
var caster: Node2D
var appear := 0.0
var fire := 0.3
## The look: the flying sprite (laid flat, as the original's ZAlign), its
## spin while waiting (deg/s), size and alpha; "pointed" sprites turn along
## their flight when rushing (the arrow), others keep spinning (the ring).
var sprite := "magic_arrow"
var sprite_scale := 1.0
var sprite_alpha := 221.0 / 255.0
var spin := 2000.0
var pointed := true
## After the kick: a random wait (arrows) or a curve to the target (rings).
var wait_steps := 10      # randi() % wait_steps * 0.1 s
var curve := false
## The trail, as its emitter: particles that fade in and out on a sine to
## `trail_alpha`, heading for a point 300 up (+-50) at `trail_speed`, sized
## +-50% when `trail_vary`, shrinking to nothing when `trail_shrink`. The
## arrow's afterimage ("magic arrow jan sang") is 200/s at full alpha; the
## ring's mist ("magic ring2": yun gi) 100/s, peaking at 73/255, shrinking.
var trail := "magic_arrow_jan_sang"
var trail_rate := 40.0
var trail_life := 0.5
var trail_alpha := 1.0
var trail_speed := 200.0
var trail_vary := true
var trail_shrink := false
## Called with the target hit (an Enemy, or the Player), or null when it ends without one.
var on_hit: Callable
var on_appear: Callable

var _t := 0.0
var _phase := 0  # 0 not yet, 1 by the caster, 2 on its curve, 3 rushing, 4 done
var _ground := Vector2.ZERO  # ground-plane position
var _height := 0.0
var _vel := Vector3.ZERO     # x, z on the ground plane; y up
var _wait := -1.0
var _rush_t := 0.0
var _angle := 0.0            # sprite angle on the ground plane
var _path: Array[Vector2] = []  # screen points of a ring's curve
var _path_t := 0.0
var _path_h := 0.0
var _trails: Array[Dictionary] = []
var _emit := 0.0
var _tex: Dictionary
var _trail_tex: Dictionary


func _ready() -> void:
	z_index = 15
	material = Cake._material("ADD")  # the original's light: black is transparent
	_tex = Cake._texture(sprite)
	_trail_tex = Cake._texture(trail)
	visible = false


func _aim_ground() -> Vector2:
	if _target_alive():
		target_point = target.global_position
	return Combat.ground(target_point)


## Unit vector from it toward the target, in (ground x, up, ground z).
func _to_target() -> Vector3:
	var g := _aim_ground() - _ground
	var v := Vector3(g.x, AIM_HEIGHT - _height, g.y)
	return v.normalized() if v.length() > 0.001 else Vector3.ZERO


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			if _t >= appear:
				_appear()
		1:
			if _wait < 0.0 and _t >= fire:
				# The group fires: kicked back, then a wait or a curve of its own.
				_vel = -_to_target() * KICK + Vector3(Run.rng.randi_range(-4, 4), Run.rng.randi_range(-4, 4), Run.rng.randi_range(-4, 4))
				_wait = float(Run.rng.randi() % maxi(wait_steps, 1)) * 0.1
				if curve:
					_start_curve()
			elif _wait >= 0.0:
				_wait -= delta
				if _wait < 0.0:
					_phase = 3
			_move(delta)
			_angle += deg_to_rad(spin) * delta
		2:
			_follow_curve(delta)
			_angle += deg_to_rad(spin) * delta
		3:
			_rush_t += delta
			_vel += _to_target() * PULL * delta
			_move(delta)
			if pointed:
				_angle = Vector2(_vel.x, _vel.z).angle() + PI / 2.0  # the sprite points up
			else:
				_angle += deg_to_rad(spin) * delta
			var g := _aim_ground() - _ground
			if Vector3(g.x, AIM_HEIGHT - _height, g.y).length() < REACH:
				_finish(target if _target_alive() else null)
			elif _rush_t > MAX_RUSH:
				_finish(null)
	_tick_trail(delta)
	queue_redraw()


func _appear() -> void:
	_phase = 1
	visible = true
	var base := Combat.ground(caster.global_position if is_instance_valid(caster) else target_point)
	_ground = base + Vector2(Run.rng.randf_range(-50, 50), Run.rng.randf_range(-50, 50))
	_height = maxf(30.0 + Run.rng.randf_range(-50, 50), 6.0)
	_vel = -_to_target() * DRIFT
	_angle = Run.rng.randf() * TAU
	global_position = Combat.screen(_ground)
	if on_appear.is_valid():
		on_appear.call()


## A ring's path (0x434c10): a cubic from where it is to the target. The
## first control point is thrown back at 200 plus a random -4..3 x 100 in
## each axis, the second sits a third of the way along, off by a random
## +-1..3 x 40. How the client combines these terms is partly lost in the
## decompiled float code (the constants and ranges are its); the -4..3 x 100
## spread is taken at a quarter here, as at full size (+-400) it would throw
## rings off screen unless the client normalises it, which it may.
func _start_curve() -> void:
	_phase = 2
	var p0 := global_position
	var p3 := Combat.screen(_aim_ground())
	var back := Combat.screen(Vector2(_vel.x, _vel.z).normalized() * KICK)
	var p1 := p0 + back + Combat.screen(Vector2(Run.rng.randi_range(-4, 3), Run.rng.randi_range(-4, 3)) * 100.0 * 0.25)
	var side := func() -> float:
		var k := Run.rng.randi_range(-3, 2)
		return float(k if k != 0 else 1)
	var p2 := p0 + (p3 - p0) / 3.0 + Combat.screen(Vector2(side.call(), side.call()) * 40.0)
	var length := p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3)
	var steps := maxi(roundi(length / CURVE_STEP), 1)
	_path.clear()
	for i in steps + 1:
		var u := float(i) / steps
		var v := 1.0 - u
		_path.append(p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u)
	_path_t = 0.0
	_path_h = _height


func _follow_curve(delta: float) -> void:
	_path_t += delta * CURVE_FPS
	var i := mini(int(_path_t), _path.size() - 1)
	# The client keeps the curve on the ground; the ring settles down onto it.
	_height = _path_h * (1.0 - float(i) / _path.size())
	global_position = _path[i]
	_ground = Combat.ground(global_position)
	if i >= _path.size() - 1:
		_phase = 3  # then home in for what the target moved
		_vel = Vector3.ZERO


func _move(delta: float) -> void:
	_ground += Vector2(_vel.x, _vel.z) * delta
	_height = maxf(_height + _vel.y * delta, 2.0)
	global_position = Combat.screen(_ground)


## Leaving the room mid-flight (a room change) still ends it, so the cast
## that loosed it can finish.
func _exit_tree() -> void:
	if _phase < 4:
		_phase = 4
		if on_hit.is_valid():
			on_hit.call(null)


func _target_alive() -> bool:
	if not is_instance_valid(target):
		return false
	if target is Enemy:
		return (target as Enemy).is_hittable()
	return not (target is Player and (target as Player).state == Player.State.DEAD)


func _finish(e: Node2D) -> void:
	_phase = 4
	if on_hit.is_valid():
		on_hit.call(e)
	# The trail fades out after it is gone.
	await get_tree().create_timer(trail_life).timeout
	queue_free()


func _tick_trail(delta: float) -> void:
	if _phase >= 1 and _phase <= 3 and not _trail_tex.is_empty():
		_emit += delta * trail_rate
		while _emit >= 1.0:
			_emit -= 1.0
			var to := Vector3(randf_range(-50, 50), 300.0 + randf_range(-50, 50), randf_range(-50, 50)).normalized()
			var v := to * trail_speed * randf_range(0.5, 1.5)
			_trails.append({"at": global_position + Vector2(0, -_height), "t": 0.0,
				"vel": Combat.screen(Vector2(v.x, v.z)) + Vector2(0, -v.y),
				"k": randf_range(0.5, 1.5) if trail_vary else 1.0,
				"frame": randi() % maxi(_trail_tex.frames.size(), 1)})
	for p: Dictionary in _trails:
		p.t += delta
		p.at += p.vel * delta
		p.vel = p.vel.move_toward(Vector2.ZERO, 200.0 * delta)
	_trails = _trails.filter(func(p: Dictionary) -> bool: return p.t < trail_life)


func _draw() -> void:
	for p: Dictionary in _trails:
		var k: float = p.t / trail_life
		var size: float = p.k * (1.0 - k if trail_shrink else 1.0)
		_blit(_trail_tex, int(p.frame), p.at - global_position, 0.0, size, sin(k * PI) * trail_alpha, false)
	if _phase >= 1 and _phase <= 3 and not _tex.is_empty():
		_blit(_tex, 0, Vector2(0, -_height), _angle, sprite_scale, sprite_alpha, true)


## Draws one frame of a texture strip at `at`; `flat` lays it on the ground
## plane (the original's ZAlign): rotated there, then squashed like the floor.
func _blit(tex: Dictionary, frame: int, at: Vector2, angle: float, k: float, alpha: float, flat: bool) -> void:
	if tex.is_empty():
		return
	var f: Array = tex.frames[frame % tex.frames.size()]
	var size := Vector2(float(f[1]), float(f[2])) * k
	var xf := Transform2D(angle, Vector2.ZERO)
	if flat:
		xf = Transform2D(Vector2(1, 0), Vector2(0, 0.5), Vector2.ZERO) * xf
	draw_set_transform_matrix(Transform2D(0.0, at) * xf)
	draw_texture_rect_region(tex.tex, Rect2(-size / 2.0, size), Rect2(float(f[0]), 0.0, float(f[1]), float(f[2])),
		Color(1, 1, 1, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)
