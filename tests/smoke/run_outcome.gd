extends SmokeSection
## Exercises real Game end callbacks and RunCity settlement, with presentation stubbed only.

class QuietGame extends Game:
	var deaths := 0
	var wins := 0
	func _present_death(_saved: Array[String], _bagged: Array[String]) -> void:
		deaths += 1
	func _present_win() -> void:
		wins += 1


## Everything is synchronous; cloned containers keep new_run from clearing the live fixture.
func run() -> void:
	var saved_profile := _snapshot(Profile)
	var saved_run := _snapshot(Run, ["max_hp", "max_mp"])
	var rng_seed: int = Run.rng.seed
	var rng_state: int = Run.rng.state
	var blocked: bool = Events.is_blocking_signals()
	var run_blocked: bool = Run.is_blocking_signals()
	Events.set_block_signals(true)
	Run.set_block_signals(true)
	Profile.use_path("user://run_outcome_test.json", true)
	Run.gear = RunGear.new()
	Run.deck = RunDeck.new()
	Run.deck.registry = saved_run.deck.registry
	Run.purse = RunPurse.new()
	Run.route = RunRoute.new()
	Run.route.regions = saved_run.route.regions
	Run.city = RunCity.new()
	Run.job = Run.cls.start_job
	Run.hub = null
	for key: String in ["jobs", "debuffs", "_stats", "type_points", "ref_stats"]:
		Run.set(key, saved_run[key].duplicate())
	_orders()
	_direct_settlement()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	_restore(Profile, saved_profile)
	_restore(Run, saved_run)
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state
	Run.set_block_signals(run_blocked)
	Events.set_block_signals(blocked)


func _orders() -> void:
	for win_first: bool in [true, false]:
		_reset()
		var g := QuietGame.new()
		g.player = Player.new()
		g.phase = Game.Phase.FIGHT
		Run.hp = 0
		if win_first:
			g._win()
			g._on_player_died()
		else:
			g._on_player_died()
			g._win()
		g._on_player_died()
		g._win()
		check(g.phase == Game.Phase.DEAD and not Run.won and not Run.last_result.won,
			"double KO settles death in callback order win-first=%s" % win_first)
		check(Profile.stats.runs == 1 and Profile.stats.deaths == 1 and Profile.stats.clears == 0,
			"double KO banks only one outcome")
		check(Profile.tm == 10 and Profile.shards == 1 and Profile.galder == 50,
			"double KO banks currency once without victory rewards")
		check(g.deaths == 1 and g.wins == 0, "only death presentation starts")
		g.player.free()
		g.free()
	_reset()
	var g := QuietGame.new()
	g.player = Player.new()
	Run.hp = 1
	g._win()
	Run.hp = 0
	g._on_player_died()
	g._win()
	check(g.phase == Game.Phase.WON and Run.last_result.won and Run.won,
		"damage after a live victory cannot replace the settled result")
	check(Profile.stats.runs == 1 and Profile.stats.clears == 1 and Profile.stats.deaths == 0,
		"a live victory is banked exactly once")
	check(Profile.shards == 3 and Profile.tm == 10 and Profile.galder == 100,
		"victory rewards and full leftovers are banked once")
	check(g.wins == 1 and g.deaths == 0, "only victory presentation starts")
	g.player.free()
	g.free()


func _direct_settlement() -> void:
	_reset()
	Run.city.finish(true)
	var result: Dictionary = Run.last_result.duplicate(true)
	Run.city.finish(false)
	Run.city.finish(true)
	check(Profile.stats.runs == 1 and Run.last_result == result,
		"direct finish calls cannot bank twice or replace the result")
	Run.new_run(42)
	check(not Run.city.finished, "new_run resets the terminal settlement latch")
	Run.city.finish(false)
	check(Profile.stats.runs == 2, "a later run may bank its own outcome")


func _reset() -> void:
	Profile.use_path("user://run_outcome_test.json", true)
	Run.city.finished = false
	Run.last_result = {}
	Run.won = false
	Run.purse = RunPurse.new()
	Run.purse.tm = 10
	Run.purse.shards = 1
	Run.purse.galder = 100
	Run.gear.equipment = {}
	Run._stats = {"WT": 0}


func _snapshot(node: Node, skip: Array[String] = []) -> Dictionary:
	var saved: Dictionary = {}
	for property: Dictionary in node.get_script().get_script_property_list():
		var key: String = property.name
		if key not in skip:
			saved[key] = node.get(key)
	return saved


func _restore(node: Node, saved: Dictionary) -> void:
	for key: String in saved:
		node.set(key, saved[key])
