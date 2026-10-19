extends Skill
## Landmine (3104) and Explosives Expert (3304): bury mines at the cursor
## (one, or a scatter of small ones). A mine waits hidden until a monster
## comes within its radius, then surfaces and bursts on everything around it
## ("It will surface and explode on anyone that comes too close"). Mines
## left untouched fade after their seconds.


func _init() -> void:
	duration = 0.35
	anim = "throw"
	dash_cancel_at = 0.15


func start() -> void:
	var spot := target_spot()
	var count := maxi(int(param("count", 1)), 1)
	var radius := param("radius", 140.0) * 0.5
	var amount := damage()
	for i in count:
		var at := spot if count == 1 else spot + Combat.screen(Vector2.from_angle(TAU * i / count) * 34.0)
		var m := Mine.new()
		m.room = room
		m.radius = radius
		m.life = param("seconds", 20.0)
		m.on_burst = func(caught: Array[Enemy]) -> void:
			if not is_instance_valid(room):
				return
			effect("ht", m.global_position)
			for e in caught:
				_effect_hit.append(e)
				hit(e, amount, 160.0, true, {}, m.global_position)
			Events.shake_requested.emit(3.5)
		room.add_child(m)
		m.global_position = at
	linger()
	# The cast stays alive while its mines wait (they call back into it).
	await wait_for(param("seconds", 20.0) + 0.5)
	release()
