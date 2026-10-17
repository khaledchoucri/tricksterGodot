extends Skill
## Lightning Strike (1211): bolts fall on the nearest enemies (up to the
## level's target count) one after another, each with a chance to stun.
## With nobody around, one bolt hits the cursor.

const RANGE := 280.0
const GAP := 0.09

var _targets: Array[Enemy] = []
var _spot := Vector2.ZERO


func _init() -> void:
	duration = 0.5
	anim = "cast"
	dash_cancel_at = 0.3


func start() -> void:
	var pool := enemies_in_circle(player.global_position, RANGE)
	pool.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(target) < b.global_position.distance_squared_to(target))
	_targets = pool.slice(0, int(param("targets", 2)))
	_spot = target
	Audio.play("snd_skl_common_ki.wav", -8.0)


func update(t: float, _delta: float) -> void:
	if _targets.is_empty():
		if once(t, 0.15):
			_strike(_spot, null)
		return
	for i in _targets.size():
		if once(t, 0.12 + GAP * i, "bolt%d" % i) and is_instance_valid(_targets[i]):
			_strike(_targets[i].global_position, _targets[i])


func _strike(at: Vector2, e: Enemy) -> void:
	Bolt.strike(room, at)
	Audio.play("snd_p_305_ht.wav" if randf() < 0.5 else "snd_p_305_ht2.wav", -6.0, 0.08)
	feedback(0.04, 5.0)
	if e == null:
		for other in enemies_in_circle(at, 34.0):
			hit(other, damage(), 90.0, true)
		return
	var fx := {"stun": param("stun", 3.0)} if randf() * 100.0 < param("chance", 50.0) else {}
	hit(e, damage(), 90.0, true, fx)
