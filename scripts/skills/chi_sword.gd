extends Skill
## Chi Sword (1505, Gladiator): three blades of chi fan out from the sword
## and pass through every enemy in their way.

const SPREAD := 0.42  # radians between blades
const COLOR := Color(1.0, 0.85, 0.5)


func _init() -> void:
	duration = 0.4
	anim = "cast"
	dash_cancel_at = 0.2


func start() -> void:
	player.weapon.swing(aim, deg_to_rad(140.0), aim.x >= 0.0, 0.04, 0.14)
	Audio.play("snd_skl_common_ki.wav", -6.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.14):
		return
	for a in [-SPREAD, 0.0, SPREAD]:
		var dir := aim.rotated(a)
		var wave := EnergyWave.new()
		wave.direction = Combat.screen(dir).normalized()
		wave.color = COLOR
		wave.half_width = 30.0
		wave.room = room
		wave.on_hit = func(e: Enemy) -> void:
			hit(e, damage(), 120.0)
			Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 8, 120.0)
		room.add_child(wave)
		wave.global_position = player.global_position + Combat.screen(dir) * 20.0
	Audio.play("snd_p_205_ap.wav", -4.0)
	feedback(0.0, 3.0)
