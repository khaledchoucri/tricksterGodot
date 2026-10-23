extends SmokeSection
## Verifies the smoke check helpers against wraparound and short-lived real falling rocks.

## This async fixture runs only in its standalone scene, never between gameplay sections.
func run() -> void:
	var charm: GDScript = load("res://tests/smoke/charm.gd")
	for degrees: float in [0.0, 179.0, 180.0, -179.0]:
		var aim := Vector2.from_angle(deg_to_rad(degrees))
		var angles: Array[float] = []
		for offset: float in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
			angles.append(charm._fan_angle(aim, aim.rotated(deg_to_rad(offset))))
		angles.sort()
		check(is_equal_approx(rad_to_deg(angles[-1] - angles[0]), 30.0),
			"a 30-degree fan remains 30 degrees when aimed at %.0f degrees" % degrees)
	var boss: GDScript = load("res://tests/smoke/boss.gd")
	var world := Node2D.new()
	var ground := Node2D.new()
	add_child(world)
	add_child(ground)
	var rock := FallingRock.drop(world, Vector2(80, 40), 0.9)
	var sample: Vector2i = boss._rocks_with_marks(world, ground)
	check(sample == Vector2i(1, 0), "a missing warning is detected rather than accepting a rock count alone")
	var mark := Telegraph.make("circle", 0.9, {"radius": 30.0})
	ground.add_child(mark)
	mark.position = Vector2(100, 40)
	check(boss._rocks_with_marks(world, ground) == Vector2i(1, 0),
		"an unrelated warning cannot cover a rock elsewhere")
	mark.position = rock.position
	sample = await boss._sample_rocks(get_tree(), world, ground)
	check(sample == Vector2i(1, 1), "observe a marked rock during its 0.9-second flight")
	# Finish awaiting only within this standalone fixture; no later game section shares its clock.
	await get_tree().create_timer(1.0, false, true).timeout
	check(boss._rocks_with_marks(world, ground).x == 0, "the observed rock is gone after the old 1-second sampling delay")
	world.free()
	ground.free()
