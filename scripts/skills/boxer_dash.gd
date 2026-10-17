extends Skill
## Dash (1102, Boxer): quick steps that put you right in front of the enemy
## you aim at, with a jab before it can react. Up to the original's range.

const SPEED := 900.0
const AIM_ARC := deg_to_rad(70.0)

var _to := Vector2.ZERO
var _travel := 0.0
var _target: Enemy


func _init() -> void:
	duration = 0.3
	anim = "dodge"
	dash_cancel_at = 0.3
	invulnerable = true


func start() -> void:
	var from := player.global_position
	_target = null
	for e in enemies_in_wedge(from, aim, param("range", 500.0), AIM_ARC):
		if room.line_clear(from, e.global_position) and (_target == null
				or e.global_position.distance_squared_to(from) < _target.global_position.distance_squared_to(from)):
			_target = e
	if _target:
		var back := Combat.screen(Combat.ground(from - _target.global_position).normalized())
		_to = _target.global_position + back * (_target.body_radius + Player.BODY_RADIUS + 8.0)
	else:
		_to = from + Combat.screen(aim) * 150.0
	_travel = from.distance_to(_to) / SPEED
	duration = _travel + 0.18
	dash_cancel_at = duration
	Audio.play("etc_miss.wav", -4.0)
	Ring.spawn(room.ground_fx, from, 20.0, 0.25, Color(1, 1, 1, 0.6))


func movement(t: float) -> Vector2:
	return (_to - player.global_position).normalized() * SPEED if t < _travel and player.global_position.distance_to(_to) > 6.0 else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	if not once(t, _travel):
		return
	player.sprite.play_action("attack", Combat.screen(aim), 0.16, true)
	if is_instance_valid(_target) and _target.is_hittable():
		hit(_target, damage(), 120.0, false)
		Sparks.burst(room, _target.global_position + Vector2(0, -20), Color.WHITE, 8, 120.0)
		Audio.play("dmg_normal_a.wav", -4.0)
		feedback(0.04, 2.0)


func finish() -> void:
	if not room.is_walkable(player.global_position):
		player.global_position = room.nearest_reachable(player.global_position)
