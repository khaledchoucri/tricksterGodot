extends Skill
## Uppercut (1103, Boxer): stored energy throws the enemy in front into the
## air. Counter Punch (a passive) can follow it with a counter blow.

const REACH := 80.0
const ARC := deg_to_rad(100.0)
const COLOR := Color(1.0, 0.85, 0.5)
## Seconds the enemy spends in the air (the original gives no number).
const AIRBORNE := 1.0

var _target: Enemy


func _init() -> void:
	duration = 0.5
	anim = "attack2"
	dash_cancel_at = 0.34


func update(t: float, _delta: float) -> void:
	if once(t, 0.14):
		_target = nearest_in_wedge(aim, REACH, ARC)
		Slash.spawn(room, player.global_position + Vector2(0, -22), {"radius": REACH, "arc": ARC, "dir": aim,
			"clockwise": aim.x < 0.0, "sweep_time": 0.07, "life": 0.22, "width": 16.0, "color": COLOR})
		Audio.play("sachr002_1.wav", -3.0)
		if _target:
			hit(_target, damage(), 60.0, true, {"stun": AIRBORNE})
			launch(_target, 48.0, AIRBORNE * 0.8)
			Sparks.burst(room, _target.global_position + Vector2(0, -24), COLOR, 14, 170.0)
			feedback(0.08, 5.0)
	if once(t, 0.32, "counter") and is_instance_valid(_target) and _target.is_hittable():
		# Counter Punch: a second blow by its chance (AP, as Uppercut).
		if skill_mod("counter_damage") > 0.0 and Run.rng.randf() * 100.0 < skill_mod("counter_chance"):
			player.deal_hit(_target, skill_mod("counter_damage") * Run.formulas.skill_mult(card),
				1.0, 120.0, true, {}, player.global_position)
			Events.text_shown.emit(_target.global_position + Vector2(0, -70), "Counter", COLOR)
			Audio.play("dmg_normal_d.wav", -3.0)
			feedback(0.06, 4.0)
