extends Skill
## Earthquake Blade (1210, Knight): the advanced Piercing Wave. A sword
## summoned into the ground ahead (at the level's range) sends out a
## shockwave that hits the enemies around it, up to the target count. Earth
## damage.

const COLOR := Color(0.85, 0.7, 0.45)

var _at := Vector2.ZERO


func _init() -> void:
	duration = 0.5
	anim = "cast"
	dash_cancel_at = 0.3


func start() -> void:
	var reach := param("range", 120.0)
	_at = player.global_position + Combat.screen(aim) * reach
	if not room.is_walkable(_at):
		_at = room.nearest_reachable(_at)
	player.weapon.swing(aim, deg_to_rad(120.0), aim.x >= 0.0, 0.04, 0.14)
	Ring.spawn(room.ground_fx, _at, param("radius", 120.0) * 0.3, 0.24, Color(COLOR, 0.7))
	Audio.play("snd_skl_common_ki.wav", -8.0)


func update(t: float, _delta: float) -> void:
	if not once(t, 0.24):
		return
	var radius := param("radius", 120.0) * 0.6
	Bolt.strike(room, _at)
	Ring.spawn(room.ground_fx, _at, radius, 0.45, Color(COLOR, 0.95))
	Ring.spawn(room.ground_fx, _at, radius * 0.55, 0.3, Color(1, 1, 1, 0.8))
	Sparks.burst(room, _at, COLOR, 26, 220.0, 0.5, 3.5, 220.0)
	Audio.play("snd_p_603_ht.wav", -2.0)
	var landed := false
	for e in closest_in_circle(_at, radius, int(param("targets", 2))):
		player.deal_hit(e, damage(), 1.0, 260.0, true, {"element": card.element}, _at)
		landed = true
	feedback(0.07 if landed else 0.02, 8.0)
