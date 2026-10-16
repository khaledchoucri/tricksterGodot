extends Skill
## Lacerator (1202): a spinning cut that throws blade auras both in front and
## behind, hitting everything around Buffalo.

const REACH := 105.0
const ARC := deg_to_rad(170.0)
const COLOR := Color(0.6, 0.9, 1.0)


func _init() -> void:
	duration = 0.36
	anim = "weapon_crit"
	anim_frames = [3, 7]
	dash_cancel_at = 0.14


func start() -> void:
	player.weapon.swing(aim, TAU, aim.x >= 0.0, 0.02, 0.14)
	Audio.play("snd_p_207_ap.wav", -4.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.06):
		return
	for dir: Vector2 in [aim, -aim]:
		Slash.spawn(room, player.global_position + Vector2(0, -14), {"radius": REACH, "arc": ARC, "dir": dir,
			"clockwise": aim.x >= 0.0, "sweep_time": 0.1, "life": 0.3, "width": 22.0, "color": COLOR})
	Ring.spawn(room.ground_fx, player.global_position, REACH * 0.8, 0.3, Color(COLOR, 0.8))
	var landed := false
	for dir: Vector2 in [aim, -aim]:
		for e in enemies_in_wedge(player.global_position, dir, REACH, ARC):
			hit(e, damage(), 220.0)
			Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 10, 140.0)
			landed = true
	feedback(0.06 if landed else 0.0, 4.0)
