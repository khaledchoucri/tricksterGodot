extends Skill
## Tornado Bomb (1011): sends out a drifting whirlwind that drags enemies in
## and cuts them over and over.


func _init() -> void:
	duration = 0.34
	anim = "throw"
	anim_frames = [3, 7]
	dash_cancel_at = 0.14


func update(t: float, _delta: float) -> void:
	if not once(t, 0.1):
		return
	var tornado := Tornado.new()
	tornado.direction = Combat.screen(aim).normalized()
	tornado.life = 2.0 + 0.2 * level
	tornado.room = room
	tornado.on_hit = func(e: Enemy) -> void:
		hit(e, damage(), 0.0, false)
	room.add_child(tornado)
	tornado.global_position = player.global_position + Combat.screen(aim) * 40.0
	Audio.play("snd_skl_p_015_ebg1.wav", -4.0)
