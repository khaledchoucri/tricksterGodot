extends SmokeSection
## Room spawning, warnings, wave advancement and Game reward/intro timers freeze during pause.

class CaptureRoom extends Room:
	var spawned := 0
	var advanced := 0
	var encounters := 0
	## No enemy assets: capture the actual spawn callback after its real warning/timer.
	func spawn(_id: StringName, _at: Vector2, _elite := false) -> Enemy:
		spawned += 1
		return null
	func _next_wave() -> void:
		advanced += 1
	## Capture Game's encounter handoff without generating monster waves.
	func start_encounter(_depth: int, _elite: bool, _boss: bool) -> void:
		encounters += 1

class CaptureGame extends Game:
	var rewards := 0
	func _ready() -> void:
		pass
	func _next_step() -> void:
		rewards += 1
	func _process(_delta: float) -> void:
		pass


## Async fixtures run after all ordinary smoke sections, never before boot or mid-section.
func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved_route: RunRoute = Run.route
	var rng_seed: int = Run.rng.seed
	var rng_state: int = Run.rng.state
	var paused: bool = get_tree().paused
	var scale: float = Engine.time_scale
	Engine.time_scale = 1.0
	Run.route = RunRoute.new()
	var region := RegionData.new()
	region.port_depth = -1
	Run.route.regions = [region]
	Run.route.plan = [RoomPlan.new(RoomData.new(), region)]
	await _spawns()
	await _waves()
	await _game_delays()
	Run.route = saved_route
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state
	Engine.time_scale = scale
	get_tree().paused = paused


func _room() -> CaptureRoom:
	var room := CaptureRoom.new()
	add_child(room)
	room.ground_fx = Node2D.new()
	room.add_child(room.ground_fx)
	return room


## Observation uses an always-processing physics timer; it does not drive game behavior.
func _observe(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _spawns() -> void:
	var room := _room()
	get_tree().paused = true
	room.spawn_with_warning(&"fixture_monster", Vector2.ZERO, 0.2)
	await _observe(0.4)
	check(room.pending == 1 and room.ground_fx.get_child_count() == 0 and room.spawned == 0,
		"paused stagger cannot create a warning or monster")
	get_tree().paused = false
	await _observe(0.3)
	check(room.ground_fx.get_child_count() == 1 and room.spawned == 0,
		"resuming stagger creates its warning before the monster")
	get_tree().paused = true
	await _observe(0.8)
	check(room.pending == 1 and room.spawned == 0, "warning delay cannot spawn a monster during pause")
	get_tree().paused = false
	await _observe(0.7)
	check(room.pending == 0 and room.spawned == 1, "resuming warning delay spawns once and settles pending")
	# An already-running warning must retain its remaining time through a pause.
	room.spawn_with_warning(&"fixture_monster", Vector2.ZERO, 0.0)
	await _observe(0.2)
	get_tree().paused = true
	await _observe(0.8)
	check(room.spawned == 1, "mid-warning pause retains the pending spawn")
	get_tree().paused = false
	await _observe(0.15)
	check(room.spawned == 1, "resumption retains remaining warning time")
	await _observe(0.4)
	check(room.spawned == 2 and room.pending == 0, "remaining warning completes once after resume")
	room.free()


func _waves() -> void:
	var room := _room()
	var dead := Enemy.new()
	room.enemies = [dead]
	room.alive = 1
	room.wave = 0
	get_tree().paused = true
	room._on_enemy_died(dead)
	await _observe(1.2)
	check(room.advanced == 0 and room.alive == 0, "last-enemy death cannot advance a wave during pause")
	get_tree().paused = false
	await _observe(0.4)
	check(room.advanced == 0, "wave pacing retains its unspent gameplay delay")
	await _observe(0.8)
	check(room.advanced == 1, "wave advances once after its resumed delay")
	dead.free()
	room.free()


func _game_delays() -> void:
	var room := _room()
	# Attach behavior after tree entry: these private timing helpers need neither ready nor HUD.
	var host := Node2D.new()
	add_child(host)
	host.set_script(CaptureGame)
	var game := host as CaptureGame
	game.room = room
	get_tree().paused = true
	game._start_fight_after_intro(Run.route.plan[0])
	game._queue_room_rewards(room)
	await _observe(1.1)
	check(room.encounters == 0 and game.phase == Game.Phase.LOADING,
		"intro cannot start an encounter during pause")
	check(game.rewards == 0 and game._steps.is_empty(), "reward generation cannot advance during pause")
	get_tree().paused = false
	await _observe(1.0)
	check(room.encounters == 1 and game.phase == Game.Phase.FIGHT,
		"intro starts its encounter once after resuming")
	check(game.rewards == 1 and game._steps == ["card"], "reward queue runs once after resuming")
	game.free()
	room.free()
