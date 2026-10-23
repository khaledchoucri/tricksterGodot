extends Skill
## Spells that run along the ground toward the cursor: Cleaving Terra
## (2109, a fissure) and Light Wave (2209, a widening wave of light).
## Everything on the path takes the damage once. Table rows: range, radius
## (the fissure's width or the wave's reach), angle (Light Wave's spread).

const SHRINK := 0.6

var _dir := Vector2.RIGHT
var _reach := 200.0
var _hit: Array[Enemy] = []


func _init() -> void:
	duration = 0.5
	anim = "cast"
	dash_cancel_at = 0.15


func start() -> void:
	_dir = aim.normalized()
	_reach = param("range", 200.0)
	if card.id == &"light_wave":
		_reach = param("radius", 180.0)
		Slash.spawn(room, player.global_position + Vector2(0, -10), {"radius": _reach, "arc": deg_to_rad(param("angle", 50.0)),
			"dir": _dir, "clockwise": true, "sweep_time": 0.2, "life": 0.45, "width": 26.0, "color": color()})


func update(t: float, _delta: float) -> void:
	var along := _reach * clampf(t / 0.35, 0.0, 1.0)
	if card.id == &"light_wave":
		for e in enemies_in_wedge(player.global_position, _dir, along, deg_to_rad(param("angle", 50.0))):
			_strike(e)
		return
	var width := param("radius", 150.0) * SHRINK * 0.4
	var head := player.global_position + Combat.screen(_dir) * along
	if once(t, along / _reach * 0.35, "crack%d" % int(along / 24.0)):
		Sparks.burst(room, head, color(), 6, 100.0, 0.35, 2.5)
		Ring.spawn(room.ground_fx, head, width, 0.3, Color(color(), 0.8))
	# A lethal strike removes its target before the next target is visited.
	for e: Enemy in room.enemies.duplicate():
		if e.is_hittable() and Combat.in_lane(player.global_position, e.global_position, _dir, along, width * 2.0, e.body_radius):
			_strike(e)


func _strike(e: Enemy) -> void:
	if e in _hit:
		return
	_hit.append(e)
	hit(e, damage(), 150.0, true)
	feedback(0.03, 3.0)
