class_name SmokeSection
extends Node
## A section of the smoke test (tests/smoke/*.gd): the runner (tests/smoke_test.gd) adds one as its
## child and calls its entry points in order. Shared helpers live here; check() reports to the runner.

## The runner: it counts failures and owns the game.
var runner: SmokeTest
## The game scene the runner built.
var game: Game:
	get:
		return runner.game


## Records a check (PASS or FAIL) with the runner.
func check(cond: bool, label: String) -> void:
	runner.check(cond, label)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func run_state() -> Node:
	return get_node("/root/Run")


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.is_hittable())


func clear_room() -> void:
	for _i in 60:
		if game.phase != game.Phase.FIGHT:
			return
		for e: Enemy in enemies():
			e.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.5)


func profile() -> Node:
	return get_node("/root/Profile")


func _item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id)


## Whether `o` has a method, property, constant or signal called `n`.
func _has_member(o: Object, n: String) -> bool:
	if o.has_method(n) or n in o or o.has_signal(n):
		return true
	var s: Script = o.get_script()
	return s != null and s.get_script_constant_map().has(n)


## Every .gd file under `dir`, recursively.
func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(d)))
	return out


func _restore_all(Run: Node) -> void:
	for r: RestorationData in Run.hub.restorations:
		if r.effect == "system":
			Profile.restorations[String(r.id)] = 1


## Takes a dummy away without a death (no EXP, no room clear).
func _remove(e: Enemy) -> void:
	if is_instance_valid(e):
		game.room.enemies.erase(e)
		e.queue_free()


## A dummy in front of the player that won't die from the checks.
## Why a spell check missed: did the cast start, where was the target, and
## what else was in the room.
func _why(cast: bool, e: Enemy, p: Player) -> String:
	var others := 0
	for o: Enemy in game.room.enemies:
		if o != e and o.is_hittable():
			others += 1
	return " [cast %s, target %s at %.0f px, state %d, player state %d, %d other monsters]" % [cast,
		"valid" if is_instance_valid(e) else "gone", e.global_position.distance_to(p.global_position) if is_instance_valid(e) else -1.0,
		e.state if is_instance_valid(e) else -1, p.state, others]


func _dummy(p: Player, ahead: float) -> Enemy:
	var room: Room = game.room
	var spot := Vector2.INF
	var dir := Vector2.RIGHT
	for _i in 300:
		var at := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		if room.line_clear(at, at + Combat.screen(d) * (ahead + 40.0)) and room.is_open_spot(at + Combat.screen(d) * ahead):
			spot = at
			dir = d
			break
	p.global_position = spot
	p.enter(Player.State.MOVE)
	p.aim = dir
	for other: Enemy in room.enemies.duplicate():
		_remove(other)  # nothing else may take the hit
	var at := spot + Combat.screen(dir) * ahead
	var e: Enemy = room.spawn(&"torobbie", at)
	for _w in 30:
		await wait(0.1)
		if e.is_hittable():
			break
	# It walks toward the player while it spawns; put it back where the check expects it
	# (left close, it could fall outside a skill's aim wedge and the check would flake).
	e.global_position = at
	e.max_hp = 99999
	e.hp = 99999
	return e
