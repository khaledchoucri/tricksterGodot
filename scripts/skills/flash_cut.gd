extends Skill
## Flash Cut (1302, Champion) and Mega Flash Cut (1304, its advanced form):
## close the level's range in a flash and strike the first enemy in the way.
## Mega Flash Cut also throws it into the air.

const TIME := 0.1
const WIDTH := 30.0
const COLOR := Color(1.0, 1.0, 0.85)

var _from := Vector2.ZERO
var _target: Enemy
var _stop := 0.0


func _init() -> void:
	duration = 0.32
	anim = "dodge"
	dash_cancel_at = 0.2
	invulnerable = true


func start() -> void:
	_from = player.global_position
	var reach := param("range", 200.0)
	var dir := Combat.ground(Combat.screen(aim)).normalized()
	_stop = reach
	_target = null
	for e in room.enemies:
		if not e.is_hittable():
			continue
		var g := Combat.ground(e.global_position - _from)
		var along := g.dot(dir)
		if along > 0.0 and along < _stop and (g - dir * along).length() <= WIDTH + e.body_radius:
			_stop = maxf(along - e.body_radius - Player.BODY_RADIUS, 0.0)
			_target = e
	Ring.spawn(room.ground_fx, _from, 26.0, 0.25, Color(COLOR, 0.8))
	Audio.play("snd_p_603_ht.wav", -5.0)


func movement(t: float) -> Vector2:
	return Combat.screen(aim).normalized() * (_stop / TIME) if t < TIME else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	if not once(t, TIME):
		return
	player.sprite.play_action("attack2", Combat.screen(aim), 0.16, true)
	Slash.spawn(room, player.global_position + Vector2(0, -16), {"radius": 70.0, "arc": deg_to_rad(150.0), "dir": aim,
		"clockwise": aim.x >= 0.0, "sweep_time": 0.05, "life": 0.22, "width": 16.0, "color": COLOR})
	if is_instance_valid(_target) and _target.is_hittable():
		var mega := card.id == &"mega_flash_cut"
		hit(_target, damage(), 160.0, true, {"stun": 0.8} if mega else {})
		if mega:
			launch(_target, 40.0, 0.7)
		Sparks.burst(room, _target.global_position + Vector2(0, -20), COLOR, 14, 180.0)
		feedback(0.07, 5.0)


func finish() -> void:
	if not room.is_walkable(player.global_position):
		player.global_position = room.nearest_reachable(player.global_position)
