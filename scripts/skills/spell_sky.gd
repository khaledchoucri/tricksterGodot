extends Skill
## Strikes from the sky on the enemy nearest the cursor: Thunderbolt (2128,
## several strikes), Arrow of Light (2205), Scythe (2701, the Grim Reaper;
## Fear rides on it) and Staff of Agony (2703). Table rows: range, count.

const GAP := 0.12

var _foe: Enemy
var _spot := Vector2.ZERO


func _init() -> void:
	duration = 0.4
	anim = "cast"
	dash_cancel_at = 0.15


func start() -> void:
	_spot = target_spot()
	_foe = nearest_to(_spot, 90.0)
	if _foe == null:
		_foe = nearest_to(player.global_position, param("range", 200.0))
	duration = maxf(duration, GAP * param("count", 1.0) + 0.15)


func update(t: float, _delta: float) -> void:
	for i in int(param("count", 1.0)):
		if not once(t, 0.05 + GAP * i, "strike%d" % i):
			continue
		var at := _foe.global_position if is_instance_valid(_foe) and _foe.is_hittable() else _spot
		if card.element == "Elec" or card.element == "Light":
			Bolt.strike(room, at)
		else:
			Slash.spawn(room, at + Vector2(0, -26), {"radius": 42.0, "arc": deg_to_rad(200.0), "dir": Vector2(1, 1).normalized(),
				"clockwise": i % 2 == 0, "sweep_time": 0.08, "life": 0.25, "width": 16.0, "color": color()})
		Ring.spawn(room.ground_fx, at, 30.0, 0.25, Color(color(), 0.9))
		if is_instance_valid(_foe) and _foe.is_hittable():
			hit(_foe, damage(), 80.0, true, {}, at)
			feedback(0.04, 3.5)
