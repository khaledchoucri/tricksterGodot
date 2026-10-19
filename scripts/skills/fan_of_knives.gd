extends Skill
## Fan of Knives (3109, Explorer; also borrowed through a rune): throw seven
## knives across its Angle (60 to 120 degrees). Each cuts the first enemy it
## meets, up to MonNum enemies in all (2 to 7: "up to a maximum of seven").
## Scales with DA.

const KNIVES := 7
const COLOR := Color(0.85, 0.9, 1.0)


func _init() -> void:
	duration = 0.32
	anim = "throw"
	dash_cancel_at = 0.16


func start() -> void:
	Audio.play("snd_p_207_ap.wav", -6.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.1):
		return
	var spread := deg_to_rad(param("angle", 70.0))
	var struck: Array[Enemy] = []
	var most := maxi(int(param("targets", KNIVES)), 1)
	for i in KNIVES:
		var a := lerpf(-spread / 2.0, spread / 2.0, float(i) / (KNIVES - 1))
		var dir := aim.rotated(a)
		var wave := EnergyWave.new()
		wave.direction = Combat.screen(dir).normalized()
		wave.color = COLOR
		wave.half_width = 12.0
		wave.life = 0.45
		wave.speed = 520.0
		wave.room = room
		var spent := [false]
		wave.on_hit = func(e: Enemy) -> void:
			if spent[0] or (not e in struck and struck.size() >= most):
				return
			spent[0] = true
			if not e in struck:
				struck.append(e)
			hit(e, damage(), 90.0, false)
			Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 6, 100.0)
			wave.queue_free()
		room.add_child(wave)
		wave.global_position = player.global_position + Combat.screen(dir) * 16.0
	feedback(0.0, 2.0)
