extends "res://tests/smoke/skill_preparation.gd"
## Dynamic hit/throw counts must finalize duration before the caster starts animation.
## Reuses the parent activation fixture; throws are captured with a synchronous clock stub.

## Preserve real Galder/card sequencing without creating projectiles or waiting in the game.
class CaptureThrow extends "res://scripts/skills/card_throw.gd":
	var throws_sent := 0

	func _throw(_foe: Enemy, _to: Vector2, _amount: float, _homing := true) -> void:
		throws_sent += 1

	func wait_for(_seconds := 0.0) -> bool:
		return alive()


var _extra: Enemy
var _speed_source: JobData


## Covers target count, attack speed, spell count and both Galder/card throw paths.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["jobs", "deck", "ref_stats", "_stats", "type_points", "_baseline", "form", "mp", "hp", "instinct", "hidden"]:
		saved[key] = Run.get(key)
	# The casts roll on the run's RNG: restore it so later sections see the same rolls.
	var rng_seed := Run.rng.seed
	var rng_state := Run.rng.state
	var registry := Run.deck.registry.duplicate()
	_speed_source = JobData.new()
	Run.jobs = [_speed_source]
	Run.deck = RunDeck.new()
	Run.deck.registry = registry
	Run.ref_stats = {"AP": 10, "DX": 10, "MA": 10, "HV": 10, "HP": 1000, "MP": 1000}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	Run._baseline = true
	Run.form = &""
	Run.instinct = false
	_fixture()
	_target.position = Vector2(60.0, 0.0)
	_extra = Enemy.new()
	_extra.state = Enemy.State.CHASE
	_extra.position = Vector2(80.0, 0.0)
	_blazing(1, false, 0.28, 2)
	_blazing(2, false, 0.42, 2)
	_blazing(2, true, 0.84, 5)
	_blazing(0, false, 0.28, 2)
	_room.enemies.assign([_target])
	_sky(1, 0.4)
	_sky(3, 0.99)
	_sky(5, 1.59)
	_throws(&"fist_full_of_galders", 1, 0.44, 2)
	_throws(&"fist_full_of_galders", 5, 0.68, 4)
	_throws(&"galder_thrower", 1, 0.32, 1)
	_throws(&"one_pair", 1, 0.32, 2)
	_pure_preparation()
	_player.skills.stop()
	_room.free()
	_target.free()
	_extra.free()
	for key: String in saved:
		Run.set(key, saved[key])
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state


func _blazing(targets: int, fast: bool, duration: float, hits: int) -> void:
	_reset()
	_room.enemies.clear()
	if targets > 0:
		_room.enemies.append(_target)
	if targets > 1:
		_room.enemies.append(_extra)
	_speed_source.passive_mods.clear()
	if fast:
		_speed_source.passive_mods["attack_speed%"] = 300.0
	var skill := _configured(&"blazing_strike")
	_begin(skill)
	check(is_equal_approx(_sprite.played_for, duration) and is_equal_approx(skill.duration, duration),
		"Blazing Strike finalizes animation duration for %d targets, %d hits" % [targets, hits])
	var prepared_targets: Array = skill.get("_targets")
	check(prepared_targets.size() == targets and skill.get("_hits") == hits,
		"Blazing Strike preserves its target selection and DX-derived hit count")
	check(_sprite.played == "weapon_crit" and skill.anim_frames == [3, 7],
		"Blazing Strike retains its action and animation frame range")
	_speed_source.passive_mods = {}


func _sky(level: int, duration: float) -> void:
	_reset()
	var skill := _configured(&"thunderbolt", level)
	_begin(skill)
	check(is_equal_approx(_sprite.played_for, duration) and is_equal_approx(skill.duration, duration),
		"Thunderbolt Lv %d finalizes animation duration from its strike count" % level)
	check(skill.get("_foe") == _target and _sprite.played == "cast",
		"Thunderbolt retains its selected target and cast action")


func _throws(id: StringName, level: int, duration: float, count: int) -> void:
	_reset()
	var skill := _configured(id, level) as CaptureThrow
	_begin(skill)
	check(is_equal_approx(_sprite.played_for, duration) and is_equal_approx(skill.duration, duration),
		"%s Lv %d finalizes its throw animation duration" % [id, level])
	check(skill.throws_sent == count, "%s retains its configured throw count" % id)
	check(not skill in Skill._lingering, "%s releases burst ownership after its captured throws" % id)


func _pure_preparation() -> void:
	var skill := _configured(&"fist_full_of_galders", 5) as CaptureThrow
	var mp := Run.mp
	var galder := Run.purse.galder
	var rng_state := Run.rng.state
	var children := _room.get_child_count()
	skill.prepare()
	check(is_equal_approx(skill.duration, 0.68) and skill.throws_sent == 0,
		"Galder preparation sets duration without throwing")
	check(Run.mp == mp and Run.purse.galder == galder and Run.rng.state == rng_state
		and _room.get_child_count() == children and not skill in Skill._lingering,
		"Galder preparation spends nothing and creates no projectile or lingering owner")


func _configured(id: StringName, level := 1) -> Skill:
	var card := Run.deck.card(id)
	var skill: Skill = CaptureThrow.new() if card.behavior.resource_path.ends_with("card_throw.gd") else card.behavior.new()
	skill.card = card
	skill.level = level
	skill.player = _player
	skill.room = _room
	skill.aim = Vector2.RIGHT
	skill.target = _target.position
	return skill


func _begin(skill: Skill) -> void:
	_player.skills._skill = skill
	_player.skills._begin()
