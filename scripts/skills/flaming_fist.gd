extends Skill
## Flaming Fist (1303, Champion): fists burning with fighting spirit strike
## the enemy in front for fire damage (your fire attack from compounds adds
## to it, as the original's fire stat does).

const REACH := 80.0
const ARC := deg_to_rad(110.0)
const COLOR := Color(1.0, 0.5, 0.2)


func _init() -> void:
	duration = 0.46
	anim = "attack2"
	dash_cancel_at = 0.3


func start() -> void:
	Sparks.burst(room, player.global_position + Vector2(0, -20), COLOR, 12, 90.0, 0.4)
	Audio.play("snd_p_208_ht.wav", -4.0)


func movement(t: float) -> Vector2:
	return Combat.screen(aim).normalized() * 120.0 if t < 0.14 else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	if not once(t, 0.18):
		return
	Slash.spawn(room, player.global_position + Vector2(0, -18), {"radius": REACH, "arc": ARC, "dir": aim,
		"clockwise": aim.x >= 0.0, "sweep_time": 0.07, "life": 0.3, "width": 22.0, "color": COLOR})
	var e := nearest_in_wedge(aim, REACH, ARC)
	if e:
		hit(e, damage(), 240.0)
		Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 22, 200.0, 0.5)
		Ring.spawn(room.ground_fx, e.global_position, 40.0, 0.3, Color(COLOR, 0.9))
		feedback(0.09, 6.0)
