extends Skill
## Upper Smash (1008): knocks the enemy in front into the air, then smashes
## it as it comes down: two hits ("Double hits" in the original).

const REACH := 80.0
const ARC := deg_to_rad(110.0)
const COLOR := Color(1.0, 0.9, 0.7)

var _target: Enemy


func _init() -> void:
	duration = 0.62
	anim = "weapon_crit"
	anim_frames = [0, 4]
	dash_cancel_at = 0.5


func start() -> void:
	Audio.play("snd_skl_p_008_sbg.wav", -6.0)


func update(t: float, _delta: float) -> void:
	if once(t, 0.12, "up"):
		_target = nearest_in_wedge(aim, REACH, ARC)
		Slash.spawn(room, player.global_position + Vector2(0, -16), {"radius": REACH, "arc": ARC, "dir": aim,
			"clockwise": aim.x >= 0.0, "sweep_time": 0.08, "life": 0.2, "width": 14.0, "color": COLOR})
		if _target:
			hit(_target, damage(), 40.0, true, {"stun": 0.7})
			launch(_target, 40.0, 0.5)
			feedback(0.05, 3.0)
	if once(t, 0.48, "down"):
		player.sprite.play_action("weapon_crit", Combat.screen(aim), 0.14, true, [4, 7])
		if is_instance_valid(_target) and _target.is_hittable():
			Ring.spawn(room.ground_fx, _target.global_position, 50.0, 0.3, Color(COLOR, 0.95))
			Sparks.burst(room, _target.global_position, Color(0.85, 0.75, 0.55), 18, 180.0, 0.4, 3.0, 160.0)
			hit(_target, damage(), 200.0, true)
			Audio.play("snd_p_603_ht.wav", -3.0)
			feedback(0.08, 7.0)
