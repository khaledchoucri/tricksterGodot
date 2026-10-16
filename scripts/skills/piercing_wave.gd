extends Skill
## Piercing Wave (1204): a wave of energy that runs through every enemy in a line.


func _init() -> void:
	duration = 0.34
	anim = "cast"
	dash_cancel_at = 0.16


func start() -> void:
	player.weapon.swing(aim, deg_to_rad(120.0), aim.x >= 0.0, 0.04, 0.12)
	Audio.play("snd_skl_common_ki.wav", -8.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.12):
		return
	var wave := EnergyWave.new()
	wave.direction = Combat.screen(aim).normalized()
	wave.room = room
	wave.on_hit = func(e: Enemy) -> void:
		hit(e, damage(), 150.0)
		Sparks.burst(room, e.global_position + Vector2(0, -20), Color(0.6, 0.9, 1.0), 10, 140.0)
		Events.hitstop_requested.emit(0.03)
	room.add_child(wave)
	wave.global_position = player.global_position + Combat.screen(aim) * 20.0
	Audio.play("snd_p_205_ap.wav", -4.0)
	feedback(0.0, 3.0)
