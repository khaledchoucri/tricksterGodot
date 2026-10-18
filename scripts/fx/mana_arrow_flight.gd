class_name ManaArrowFlight
extends Node2D
## One Mana Arrow as the original client flies it (Trickster.bin ArrowCake /
## ArrowBall, read with Ghidra; addresses below):
##  - It appears beside the caster (+-50 on each axis, 30 up) `appear` seconds
##    in, spinning flat on the ground at 2000 deg/s and drifting away from the
##    target at 100/s (0x421120, 0x421320).
##  - At `fire` (the group's 0.3 s) it is kicked back at 200/s and waits a
##    random 0-0.9 s in 0.1 steps (0x421400): Arrow Rush's arrows land one
##    after another.
##  - Then it rushes: accelerating at 5000/s^2 toward the target, re-aimed each
##    frame and pointing along its flight, for at most 6 s, and hits within 50
##    (0x421ef0; times from 0x431ae0's 0.3 and 6.0).
## Distances are the original's world units, taken as ground pixels here.

const SPIN := 2000.0      # deg/s while waiting
const DRIFT := 100.0      # away from the target while appearing
const KICK := 200.0       # away from the target when the group fires
const PULL := 5000.0      # rush acceleration toward the target
const REACH := 50.0       # hit distance
const MAX_RUSH := 6.0
const AIM_HEIGHT := 24.0  # where on a monster the arrow homes
## The afterimage ("magic arrow jan sang", cake.xml): 40 a second, 0.5 s
## each, fading in and out on a sine. Each heads for a point 300 up (+-50) at
## 200/s (+-50%) against 200/s^2 of air resistance, sized 101% (+-50%).
const TRAIL_RATE := 40.0
const TRAIL_LIFE := 0.5
const TRAIL_SPEED := 200.0
const TRAIL_DRAG := 200.0

var room: Room
var target: Enemy
## Where to fly when there's no target (or it dies on the way).
var target_point := Vector2.ZERO
var caster: Node2D
var appear := 0.0
var fire := 0.3
## Called with the enemy hit, or null when the arrow ends without one.
var on_hit: Callable
var on_appear: Callable

var _t := 0.0
var _phase := 0  # 0 not yet, 1 waiting by the caster, 2 rushing, 3 done
var _ground := Vector2.ZERO  # ground-plane position
var _height := 0.0
var _vel := Vector3.ZERO     # x, z on the ground plane; y up
var _wait := -1.0
var _rush_t := 0.0
var _angle := 0.0            # sprite angle on the ground plane
var _trail: Array[Dictionary] = []
var _emit := 0.0
var _arrow: Dictionary
var _after: Dictionary


func _ready() -> void:
	z_index = 15
	material = Cake._material("ADD")  # the original's light: black is transparent
	_arrow = Cake._texture("magic_arrow")
	_after = Cake._texture("magic_arrow_jan_sang")
	visible = false


func _aim_ground() -> Vector2:
	if is_instance_valid(target) and target.is_hittable():
		target_point = target.global_position
	return Combat.ground(target_point)


## Unit vector from the arrow toward the target, in (ground x, up, ground z).
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
				# The group fires: kicked back, then a random wait of its own.
				_wait = float(randi() % 10) * 0.1
				_vel = -_to_target() * KICK + Vector3(randi_range(-4, 4), randi_range(-4, 4), randi_range(-4, 4))
			elif _wait >= 0.0:
				_wait -= delta
				if _wait < 0.0:
					_phase = 2
			_move(delta)
			_angle += deg_to_rad(SPIN) * delta
		2:
			_rush_t += delta
			_vel += _to_target() * PULL * delta
			_move(delta)
			_angle = Vector2(_vel.x, _vel.z).angle() + PI / 2.0  # the sprite points up
			var g := _aim_ground() - _ground
			if Vector3(g.x, AIM_HEIGHT - _height, g.y).length() < REACH:
				_finish(target if is_instance_valid(target) and target.is_hittable() else null)
			elif _rush_t > MAX_RUSH:
				_finish(null)
	_tick_trail(delta)
	queue_redraw()


func _appear() -> void:
	_phase = 1
	visible = true
	var base := Combat.ground(caster.global_position if is_instance_valid(caster) else target_point)
	_ground = base + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	_height = maxf(30.0 + randf_range(-50, 50), 6.0)
	_vel = -_to_target() * DRIFT
	_angle = randf() * TAU
	global_position = Combat.screen(_ground)
	if on_appear.is_valid():
		on_appear.call()


func _move(delta: float) -> void:
	_ground += Vector2(_vel.x, _vel.z) * delta
	_height = maxf(_height + _vel.y * delta, 2.0)
	global_position = Combat.screen(_ground)


## Leaving the room mid-flight (a room change) still ends the arrow, so the
## cast that loosed it can finish.
func _exit_tree() -> void:
	if _phase < 3:
		_phase = 3
		if on_hit.is_valid():
			on_hit.call(null)


func _finish(e: Enemy) -> void:
	_phase = 3
	if on_hit.is_valid():
		on_hit.call(e)
	# The afterimage fades out after the arrow is gone.
	await get_tree().create_timer(TRAIL_LIFE).timeout
	queue_free()


func _tick_trail(delta: float) -> void:
	if _phase == 1 or _phase == 2:
		_emit += delta * TRAIL_RATE
		while _emit >= 1.0:
			_emit -= 1.0
			var to := Vector3(randf_range(-50, 50), 300.0 + randf_range(-50, 50), randf_range(-50, 50)).normalized()
			var v := to * TRAIL_SPEED * randf_range(0.5, 1.5)
			_trail.append({"at": global_position + Vector2(0, -_height), "t": 0.0, "k": randf_range(0.5, 1.5),
				"vel": Combat.screen(Vector2(v.x, v.z)) + Vector2(0, -v.y),
				"frame": randi() % maxi(_after.get("frames", [1]).size(), 1)})
	for p: Dictionary in _trail:
		p.t += delta
		p.at += p.vel * delta
		p.vel = p.vel.move_toward(Vector2.ZERO, TRAIL_DRAG * delta)
	_trail = _trail.filter(func(p: Dictionary) -> bool: return p.t < TRAIL_LIFE)


func _draw() -> void:
	if not _after.is_empty():
		for p: Dictionary in _trail:
			var k: float = p.t / TRAIL_LIFE
			_blit(_after, int(p.frame), p.at - global_position, 0.0, p.k, sin(k * PI), false)
	if _phase == 1 or _phase == 2:
		if not _arrow.is_empty():
			_blit(_arrow, 0, Vector2(0, -_height), _angle, 1.0, 221.0 / 255.0, true)


## Draws one frame of a texture strip at `at`; `flat` lays it on the ground
## plane (the original's ZAlign): rotated there, then squashed like the floor.
func _blit(tex: Dictionary, frame: int, at: Vector2, angle: float, k: float, alpha: float, flat: bool) -> void:
	var f: Array = tex.frames[frame % tex.frames.size()]
	var size := Vector2(float(f[1]), float(f[2])) * k
	var xf := Transform2D(angle, Vector2.ZERO)
	if flat:
		xf = Transform2D(Vector2(1, 0), Vector2(0, 0.5), Vector2.ZERO) * xf
	draw_set_transform_matrix(Transform2D(0.0, at) * xf)
	draw_texture_rect_region(tex.tex, Rect2(-size / 2.0, size), Rect2(float(f[0]), 0.0, float(f[1]), float(f[2])),
		Color(1, 1, 1, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)
