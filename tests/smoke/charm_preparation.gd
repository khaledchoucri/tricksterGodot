extends "res://tests/smoke/skill_preparation.gd"
## Charm animation and duration are finalized before the caster starts presentation.
## Reuses the activation fixture from the parent preparation branch.


## Covers modified Charm variants, default controls, target locking and pure preparation.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["jobs", "deck", "ref_stats", "_stats", "type_points", "_baseline", "form", "mp", "hp", "instinct", "hidden"]:
		saved[key] = Run.get(key)
	var registry := Run.deck.registry.duplicate()
	Run.jobs = []
	Run.deck = RunDeck.new()
	Run.deck.registry = registry
	Run.ref_stats = {"AP": 10, "DX": 10, "HV": 10, "HP": 1000, "MP": 1000}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	Run._baseline = true
	Run.form = &""
	Run.instinct = false
	Run.hp = 1000
	_fixture()
	_target.position = Vector2(60.0, 0.0)
	_configuration(&"power_blow", "attack", 0.34)
	_configuration(&"volley_kick", "weapon_crit", 0.42)
	_configuration(&"heavy_hit", "weapon_crit", 0.42)
	_configuration(&"two_hit_combo", "attack", 0.62)
	_configuration(&"beast_claw", "attack", 0.36)
	_configuration(&"siren_song", "attack2", 0.45)
	_configuration(&"sharp_scream", "attack2", 0.45)
	_configuration(&"mass_destruction", "charge", 0.6)
	_configuration(&"impelling_rage", "cast", 0.45)
	_pure_preparation()
	_player.skills.stop()
	_room.free()
	_target.free()
	for key: String in saved:
		Run.set(key, saved[key])


func _configuration(id: StringName, action_name: String, duration: float) -> void:
	_reset()
	var skill := _configured(id)
	_player.skills._skill = skill
	_player.skills._begin()
	check(_sprite.played == action_name, "%s starts its intended animation" % id)
	check(is_equal_approx(_sprite.played_for, duration) and is_equal_approx(skill.duration, duration),
		"%s animation and skill share their finalized duration" % id)
	if skill.card.behavior.resource_path.ends_with("charm_strike.gd"):
		check(skill.get("_foe") == _target, "%s retains its prepared strike target" % id)


func _pure_preparation() -> void:
	var skill := _configured(&"beast_claw")
	var mp := Run.mp
	var hp := Run.hp
	var rng_state := Run.rng.state
	var fx := _room.ground_fx.get_child_count()
	skill.prepare()
	check(skill.movement(0.05).length() > 0.0 and skill.movement(0.14) == Vector2.ZERO,
		"Beast Claw prepares its lunge before activation and preserves its movement window")
	check(Run.mp == mp and Run.hp == hp and Run.rng.state == rng_state
		and _room.ground_fx.get_child_count() == fx,
		"Charm preparation causes no damage, resource spending, random roll or ground effect")


func _configured(id: StringName) -> Skill:
	var card := Run.deck.card(id)
	var skill: Skill = card.behavior.new()
	skill.card = card
	skill.player = _player
	skill.room = _room
	skill.aim = Vector2.RIGHT
	skill.target = _target.position
	return skill
