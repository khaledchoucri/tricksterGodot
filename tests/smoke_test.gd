extends SceneTree
## Headless smoke test for the combat room.
## Run: godot --headless --path . -s res://tests/smoke_test.gd

var failures := 0


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await wait(0.2)
	var player: Player = arena.player
	check(player != null and player.sprite.sprite_frames != null, "player spawns with Buffalo sprites")

	await wait(4.5)
	var enemies := get_nodes_in_group("enemies")
	check(enemies.size() == 3, "wave 1 spawns 3 enemies (got %d)" % enemies.size())

	# Put one Torobbie right in front of the player and punch it.
	var target: Enemy = enemies[0]
	var hp_before := target.hp
	target.global_position = player.global_position + Vector2(30, 10)
	player.aim = Combat.ground(target.global_position - player.global_position).normalized()
	player._start_attack(0)
	for _i in 30:
		player.aim = Combat.ground(target.global_position - player.global_position).normalized()
		await physics_frame
	check(target.hp < hp_before, "punch damages Torobbie (%d -> %d)" % [hp_before, target.hp])

	# Dash grants invulnerability.
	player._start_dash()
	check(player.is_invulnerable(), "dash makes the player invulnerable")
	await wait(0.6)

	# Dashing through a standing enemy must not push it.
	var blocker: Enemy = null
	for e in get_nodes_in_group("enemies"):
		if e.is_hittable():
			blocker = e
			break
	player.global_position = Vector2(-120, 60)
	blocker.global_position = player.global_position + Vector2(55, 0)
	blocker._enter(Enemy.State.RECOVER, 5.0)
	blocker._knock = Vector2.ZERO
	await physics_frame
	var blocker_start := blocker.global_position
	player.aim = Vector2.RIGHT
	player._dash_dir = Vector2.RIGHT
	Input.action_press("move_right")
	player._start_dash()
	await wait(0.5)
	Input.action_release("move_right")
	check(player.global_position.x > blocker_start.x + 20.0, "dash carries the player through the enemy")
	check(blocker.global_position.distance_to(blocker_start) < 2.0,
		"dash doesn't push the enemy (moved %.1f px)" % blocker.global_position.distance_to(blocker_start))
	check(player.get_collision_layer_value(2), "player is solid again after clearing the enemy")
	blocker._enter(Enemy.State.CHASE)

	# Stand still among enemies and confirm they wind up and land a hit.
	var hp_start := player.hp
	for e in get_nodes_in_group("enemies"):
		if e.is_hittable():
			e.global_position = player.global_position + Vector2(randf_range(-30, 30), randf_range(-15, 15))
	var saw_windup := false
	for _i in 300:
		for e in get_nodes_in_group("enemies"):
			if e.state == Enemy.State.WINDUP:
				saw_windup = true
		await physics_frame
	check(saw_windup, "enemies telegraph before attacking")
	check(player.hp < hp_start, "enemy attacks damage the player (%d -> %d)" % [hp_start, player.hp])
	check(arena.attackers.size() <= arena.MAX_ATTACKERS, "attack tokens cap simultaneous attackers")

	# Kill everything and confirm the wave advances.
	var wave_before: int = arena.wave
	for e in get_nodes_in_group("enemies"):
		if e.is_hittable():
			e.take_hit(9999, Vector2.RIGHT, 0.0, true)
	await wait(3.5)
	check(arena.wave == wave_before + 1, "clearing a wave starts the next (wave %d -> %d)" % [wave_before, arena.wave])

	# Boss: jump to the last wave and check summons trigger at 66% HP.
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	arena.alive = 0
	var boss: Enemy = arena.spawn_monster("golden_mole", Vector2(0, -100))
	await wait(0.7)
	check(boss is BossMole and boss.max_hp > 900, "boss spawns with boss HP (%d)" % boss.max_hp)
	boss.take_hit(int(boss.max_hp * 0.36), Vector2.RIGHT, 0.0, true)
	await wait(1.2)
	var minions := get_nodes_in_group("enemies").filter(func(e): return e != boss)
	check(minions.size() >= 3, "boss summons Torobbies below 66%% HP (%d)" % minions.size())

	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	Engine.time_scale = 1.0
	quit(1 if failures else 0)
