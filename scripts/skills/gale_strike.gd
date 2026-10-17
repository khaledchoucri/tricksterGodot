extends Skill
## Gale Strike (1504, Gladiator): spin into a whirl of wind for a second,
## cutting everything around Buffalo again and again. You can steer it.

const RADIUS := 84.0
const TICK := 0.16
const STEER := 90.0
const COLOR := Color(0.7, 1.0, 0.8)

var _next := 0.0


func _init() -> void:
	duration = 1.0
	anim = "weapon_crit"
	anim_frames = [3, 7]
	dash_cancel_at = 0.3


func start() -> void:
	Audio.play("snd_p_305_ht.wav", -4.0)


func movement(_t: float) -> Vector2:
	return player.move_input() * STEER


func update(t: float, _delta: float) -> void:
	if t < _next:
		return
	_next = t + TICK
	var dir := Vector2.from_angle(t * 14.0)
	player.weapon.swing(dir, TAU, true, 0.0, TICK)
	Slash.spawn(room, player.global_position + Vector2(0, -14), {"radius": RADIUS, "arc": TAU * 0.6, "dir": dir,
		"clockwise": true, "sweep_time": TICK, "life": TICK + 0.12, "width": 14.0, "color": COLOR})
	var landed := false
	for e in enemies_in_circle(player.global_position, RADIUS):
		hit(e, damage(), 60.0, false)
		landed = true
	if landed:
		Audio.play("dmg_normal_b.wav", -8.0)
		feedback(0.02, 1.5)
