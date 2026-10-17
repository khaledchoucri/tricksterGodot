extends Skill
## Chi Release (1305, Champion): the energy within you goes off in one
## explosion around you, hitting the nearest enemies up to the level's
## target count. Costs a lot of MP.

const COLOR := Color(1.0, 0.95, 0.6)


func _init() -> void:
	duration = 0.6
	anim = "charge"
	dash_cancel_at = 0.4


func start() -> void:
	Ring.spawn(room.ground_fx, player.global_position, 30.0, 0.3, Color(COLOR, 0.6))
	Audio.play("snd_skl_common_ki.wav", -6.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.3):
		return
	var radius := param("radius", 110.0)
	Ring.spawn(room.ground_fx, player.global_position, radius, 0.45, Color(COLOR, 0.95))
	Ring.spawn(room.ground_fx, player.global_position, radius * 0.6, 0.35, Color(1, 1, 1, 0.9))
	Sparks.burst(room, player.global_position + Vector2(0, -20), COLOR, 30, 260.0, 0.5, 3.5)
	Audio.play("eff_energy.wav", -2.0)
	var landed := false
	for e in closest_in_circle(player.global_position, radius, int(param("targets", 3))):
		hit(e, damage(), 320.0)
		landed = true
	feedback(0.09 if landed else 0.03, 9.0)
