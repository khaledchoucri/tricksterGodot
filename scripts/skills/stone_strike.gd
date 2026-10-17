extends Skill
## Stone Strike (3002, Explorer; borrowed through a rune): hurl a heavy stone
## that knocks the first enemy down hard and stuns it. Scales with DA.

const COLOR := Color(0.8, 0.72, 0.6)


func _init() -> void:
	duration = 0.34
	anim = "throw"
	dash_cancel_at = 0.18


func start() -> void:
	Audio.play("snd_p_207_ap.wav", -6.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.12):
		return
	var wave := EnergyWave.new()
	wave.direction = Combat.screen(aim).normalized()
	wave.color = COLOR
	wave.half_width = 20.0
	wave.speed = 460.0
	wave.room = room
	var spent := [false]
	wave.on_hit = func(e: Enemy) -> void:
		if spent[0]:
			return
		spent[0] = true
		hit(e, damage(), 260.0, true, {"stun": 0.8})
		Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 14, 160.0)
		Events.shake_requested.emit(4.0)
		wave.queue_free()
	room.add_child(wave)
	wave.global_position = player.global_position + Combat.screen(aim) * 18.0
