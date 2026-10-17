extends Skill
## Tempest Strike (1209, Knight, the advanced Lacerator) and Gale Strike
## (1504, Gladiator, the advanced Tempest Strike): quick movements of the
## blade throw circular blades of wind around you that slash the nearest
## enemies, up to the level's target count. Wind damage.

const COLOR := Color(0.7, 1.0, 0.8)

var _gale := false


func _init() -> void:
	duration = 0.42
	anim = "weapon_crit"
	anim_frames = [3, 7]
	dash_cancel_at = 0.2


func start() -> void:
	_gale = card.id == &"gale_strike"
	player.weapon.swing(aim, TAU, true, 0.0, 0.2)
	Audio.play("snd_p_305_ht.wav", -4.0)


func update(t: float, _delta: float) -> void:
	var radius := param("radius", 110.0)
	var rings := 3 if _gale else 2
	for i in rings:
		if once(t, 0.04 + 0.06 * i, "ring%d" % i):
			var dir := Vector2.from_angle(TAU * i / rings + t * 6.0)
			Slash.spawn(room, player.global_position + Vector2(0, -14), {"radius": radius * (0.7 + 0.15 * i),
				"arc": TAU * 0.85, "dir": dir, "clockwise": true, "sweep_time": 0.12, "life": 0.28,
				"width": 16.0 if _gale else 12.0, "color": COLOR})
	if not once(t, 0.12):
		return
	var landed := false
	for e in closest_in_circle(player.global_position, radius, int(param("targets", 1))):
		hit(e, damage(), 120.0 if _gale else 90.0)
		Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 10, 150.0)
		landed = true
	if landed:
		Audio.play("dmg_normal_b.wav", -6.0)
	feedback(0.05 if landed else 0.0, 4.0 if _gale else 3.0)
