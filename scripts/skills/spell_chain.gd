extends Skill
## Electro Attack (2105): a bolt strikes the enemy nearest the aim and its
## sparks leap on to others nearby, up to the level's target count.

const AIM_ARC := deg_to_rad(70.0)
const LEAP := 0.09


func _init() -> void:
	duration = 0.45
	anim = "cast"
	dash_cancel_at = 0.1


var _chain: Array[Enemy] = []


func start() -> void:
	var first := nearest_in_wedge(aim, param("range", 200.0), AIM_ARC)
	if first == null:
		Bolt.strike(room, target_spot())
		return
	_chain = [first]
	var leap := param("radius", 250.0) * 0.5
	while _chain.size() < int(param("targets", 2)):
		var last := _chain[_chain.size() - 1]
		var next: Enemy = null
		for e in closest_in_circle(last.global_position, leap, 8):
			if not e in _chain:
				next = e
				break
		if next == null:
			break
		_chain.append(next)


func update(t: float, _delta: float) -> void:
	for i in _chain.size():
		if once(t, LEAP * i, "leap%d" % i) and is_instance_valid(_chain[i]) and _chain[i].is_hittable():
			Bolt.strike(room, _chain[i].global_position)
			hit(_chain[i], damage(), 60.0, i == 0)
			feedback(0.03, 2.5)
