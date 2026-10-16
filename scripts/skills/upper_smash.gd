extends Skill
## Upper Smash (1008): leaps to the cursor and crashes down, stunning
## everything around the landing. Clears obstacles on the way.

const MAX_LEAP := 200.0
const AIR := 0.36
const RADIUS := 88.0
const HOP := 46.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO


func _init() -> void:
	duration = 0.5
	anim = "jump"
	dash_cancel_at = 0.48
	invulnerable = true


func start() -> void:
	_from = player.global_position
	var leap := target - _from
	if leap.length() > MAX_LEAP:
		leap = leap.normalized() * MAX_LEAP
	_to = _landing(_from + leap)
	player.set_collision_mask_value(1, false)  # sail over obstacles
	Audio.play("snd_skl_p_008_sbg.wav", -6.0)


## Closest open spot at or before the target along the leap.
func _landing(want: Vector2) -> Vector2:
	for i in 21:
		var p := want.lerp(_from, i / 20.0)
		if room.is_open_spot(p):
			return p
	return _from


func movement(t: float) -> Vector2:
	return Vector2.ZERO if t >= AIR else (_to - _from) / AIR


func update(t: float, _delta: float) -> void:
	player.sprite.position.y = -sin(PI * clampf(t / AIR, 0.0, 1.0)) * HOP
	if once(t, AIR):
		player.sprite.position.y = 0.0
		player.global_position = _to
		player.sprite.play_action("weapon_crit", Combat.screen(aim), 0.14, true, [4, 7])
		_crash()


func _crash() -> void:
	Ring.spawn(room.ground_fx, _to, RADIUS, 0.4, Color(1.0, 0.9, 0.7, 0.95))
	Ring.spawn(room.ground_fx, _to, RADIUS * 0.6, 0.3, Color(1.0, 1.0, 1.0, 0.9))
	Sparks.burst(room, _to, Color(0.85, 0.75, 0.55), 24, 200.0, 0.5, 3.5, 200.0)
	Audio.play("snd_p_603_ht.wav", -2.0)
	var landed := false
	for e in enemies_in_circle(_to, RADIUS):
		hit(e, damage(), 260.0, true, {"stun": 0.6})
		landed = true
	feedback(0.08 if landed else 0.03, 9.0)


func finish() -> void:
	player.sprite.position.y = 0.0
	player.set_collision_mask_value(1, true)
	if not room.is_walkable(player.global_position):
		player.global_position = room.nearest_reachable(player.global_position)
