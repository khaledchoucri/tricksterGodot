extends Skill
## Tidal Slash (1207, Knight): the advanced Lacerator. Wider blade auras in
## front and behind, strong enough to slice water in half, cutting up to the
## level's target count. Water damage.

const ARC := deg_to_rad(200.0)
const COLOR := Color(0.45, 0.75, 1.0)


func _init() -> void:
	duration = 0.4
	anim = "weapon_crit"
	anim_frames = [3, 7]
	dash_cancel_at = 0.16


func start() -> void:
	player.weapon.swing(aim, TAU, aim.x >= 0.0, 0.02, 0.16)
	Audio.play("snd_p_207_ap.wav", -3.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.07):
		return
	var reach := param("range", 100.0) * 1.25
	for dir: Vector2 in [aim, -aim]:
		Slash.spawn(room, player.global_position + Vector2(0, -14), {"radius": reach, "arc": ARC, "dir": dir,
			"clockwise": aim.x >= 0.0, "sweep_time": 0.1, "life": 0.34, "width": 26.0, "color": COLOR})
	Ring.spawn(room.ground_fx, player.global_position, reach * 0.85, 0.35, Color(COLOR, 0.8))
	var pool: Array[Enemy] = []
	for dir: Vector2 in [aim, -aim]:
		for e in enemies_in_wedge(player.global_position, dir, reach, ARC):
			if not e in pool:
				pool.append(e)
	pool.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	for e in pool.slice(0, int(param("targets", 5))):
		hit(e, damage(), 230.0)
		Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 12, 150.0)
	feedback(0.06 if pool.size() > 0 else 0.0, 5.0)
