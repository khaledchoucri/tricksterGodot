extends Skill
## Blazing Strike (1205, Knight): devastating blows at blazing speed on the
## nearest enemies (up to the level's target count, within its range). The
## original says the number of hits depends on dexterity: here two, plus
## one for each 25% your DX speeds up your attacks, up to five.

const COLOR := Color(1.0, 0.55, 0.3)
const GAP := 0.07

var _targets: Array[Enemy] = []
var _hits := 2


func _init() -> void:
	duration = 0.5
	anim = "weapon_crit"
	anim_frames = [3, 7]
	dash_cancel_at = 0.36


func start() -> void:
	_targets = closest_in_circle(player.global_position, param("range", 120.0), int(param("targets", 2)))
	_hits = clampi(2 + int((Run.attack_speed_mult() - 1.0) / 0.25), 2, 5)
	duration = 0.14 + GAP * _hits * maxi(_targets.size(), 1)
	Audio.play("snd_p_207_ap.wav", -6.0)


func update(t: float, _delta: float) -> void:
	var n := 0
	for e in _targets:
		for h in _hits:
			if once(t, 0.08 + GAP * n, "s%d" % n) and is_instance_valid(e) and e.is_hittable():
				var dir := Combat.ground(e.global_position - player.global_position).normalized()
				player.weapon.swing(dir, deg_to_rad(140.0), h % 2 == 0, 0.0, GAP)
				Slash.spawn(room, e.global_position + Vector2(0, -18), {"radius": 34.0, "arc": deg_to_rad(160.0),
					"dir": dir.rotated(randf_range(-1.0, 1.0)), "clockwise": h % 2 == 0, "sweep_time": 0.04,
					"life": 0.14, "width": 10.0, "color": COLOR})
				hit(e, damage(), 40.0, h == _hits - 1)
				Audio.play(ComboAttack.HIT_SOUNDS[n % ComboAttack.HIT_SOUNDS.size()], -7.0)
				feedback(0.02, 1.2)
			n += 1
