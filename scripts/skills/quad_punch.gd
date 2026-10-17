extends Skill
## Quad Punch (1104, Boxer) and Tetra Punch (1108, its advanced form): four
## blows in a row on the enemy in front, each counted. Tetra Punch aims at
## vital points: every blow that lands makes the next stronger.

const REACH := 80.0
const ARC := deg_to_rad(100.0)
const GAP := 0.09
## Tetra Punch's gain per landed blow (the original says only "more").
const TETRA_STEP := 0.25

var _landed := 0


func _init() -> void:
	duration = 0.5
	anim = "attack"
	dash_cancel_at = 0.4


func movement(t: float) -> Vector2:
	return Combat.screen(aim).normalized() * 40.0 if t < 0.36 else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	for i in 4:
		if not once(t, 0.06 + GAP * i, "blow%d" % i):
			continue
		if i % 2 == 1:
			player.sprite.play_action("attack2", Combat.screen(aim), GAP * 1.6, true)
		else:
			player.sprite.play_action("attack", Combat.screen(aim), GAP * 1.6, true)
		var e := nearest_in_wedge(aim, REACH, ARC)
		var c := Color(1.0, 0.75 + 0.06 * i, 0.4)
		Slash.spawn(room, player.global_position + Vector2(0, -18), {"radius": REACH * 0.85, "arc": ARC * 0.6,
			"dir": aim.rotated(0.25 if i % 2 else -0.25), "clockwise": i % 2 == 0, "sweep_time": 0.04, "life": 0.14,
			"width": 9.0, "color": c})
		if e:
			var scale := 1.0 + TETRA_STEP * _landed if card.id == &"tetra_punch" else 1.0
			hit(e, damage(scale), 50.0 if i < 3 else 180.0, i == 3)
			_landed += 1
			Sparks.burst(room, e.global_position + Vector2(0, -20), c, 6, 110.0)
			Audio.play(ComboAttack.HIT_SOUNDS[i % ComboAttack.HIT_SOUNDS.size()], -6.0)
			feedback(0.03, 1.5)
