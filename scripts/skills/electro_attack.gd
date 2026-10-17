extends Skill
## Electro Attack (2105, Bard; borrowed through a rune): lightning leaps from
## the nearest enemy to the next, up to five. Scales with MA.

const RANGE := 220.0
const JUMP := 150.0
const JUMPS := 5
const GAP := 0.07

var _chain: Array[Enemy] = []


func _init() -> void:
	duration = 0.45
	anim = "cast"
	dash_cancel_at = 0.25


func start() -> void:
	var from := player.global_position
	var left := enemies_in_circle(from, RANGE)
	while _chain.size() < JUMPS and not left.is_empty():
		left.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
		var next: Enemy = left.pop_front()
		if next.global_position.distance_to(from) > (RANGE if _chain.is_empty() else JUMP):
			break
		_chain.append(next)
		from = next.global_position
	Audio.play("snd_p_305_ht.wav", -6.0)


func update(t: float, _delta: float) -> void:
	for i in _chain.size():
		if once(t, 0.08 + GAP * i, "jump%d" % i) and is_instance_valid(_chain[i]) and _chain[i].is_hittable():
			Bolt.strike(room, _chain[i].global_position)
			hit(_chain[i], damage(), 80.0, false, {"stun": 0.2})
			feedback(0.02, 2.0)
