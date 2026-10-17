extends Skill
## Drip Bomb (2103, Bard; borrowed through a rune): lob a water bomb at the
## cursor that bursts and soaks everything around it. Scales with MA.

const RANGE := 240.0
const RADIUS := 82.0
const FLIGHT := 0.32
const COLOR := Color(0.45, 0.75, 1.0)

var _spot := Vector2.ZERO


func _init() -> void:
	duration = 0.42
	anim = "cast"
	dash_cancel_at = 0.22


func start() -> void:
	var to := target - player.global_position
	_spot = player.global_position + (to.limit_length(RANGE))
	if not room.is_walkable(_spot):
		_spot = room.nearest_reachable(_spot)
	var warn := Telegraph.make("circle", FLIGHT, {"radius": RADIUS, "color": Color(COLOR, 0.35)})
	room.add_ground_fx(warn, _spot)
	Audio.play("snd_skl_common_ki.wav", -8.0)


func update(t: float, _delta: float) -> void:
	if not once(t, FLIGHT):
		return
	Ring.spawn(room.ground_fx, _spot, RADIUS, 0.4, Color(COLOR, 0.9))
	Sparks.burst(room, _spot + Vector2(0, -10), COLOR, 18, 200.0)
	var landed := false
	for e in enemies_in_circle(_spot, RADIUS):
		hit(e, damage(), 160.0)
		landed = true
	Audio.play("dmg_normal_c.wav", -4.0)
	feedback(0.04 if landed else 0.0, 4.0)
