extends Skill
## Burning Rave (1004): two quick blows fused into one focused strike on the
## enemy in front (the original's range 80).

const REACH := 80.0
const ARC := deg_to_rad(110.0)
const COLOR := Color(1.0, 0.7, 0.4)


func _init() -> void:
	duration = 0.36
	anim = "attack2"
	dash_cancel_at = 0.22


func start() -> void:
	Audio.play("sachr002.wav", -4.0)


func movement(t: float) -> Vector2:
	return Combat.screen(aim).normalized() * 140.0 if t < 0.12 else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	if once(t, 0.08, "first"):
		Slash.spawn(room, player.global_position + Vector2(0, -16), {"radius": REACH * 0.8, "arc": ARC, "dir": aim,
			"clockwise": aim.x >= 0.0, "sweep_time": 0.06, "life": 0.18, "width": 10.0, "color": COLOR})
	if not once(t, 0.16):
		return
	Slash.spawn(room, player.global_position + Vector2(0, -16), {"radius": REACH, "arc": ARC, "dir": aim,
		"clockwise": aim.x < 0.0, "sweep_time": 0.06, "life": 0.24, "width": 18.0, "color": COLOR})
	var e := nearest_in_wedge(aim, REACH, ARC)
	if e:
		hit(e, damage(), 260.0)
		Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 16, 180.0)
		Audio.play("dmg_normal_c.wav", -4.0)
		feedback(0.08, 5.0)
