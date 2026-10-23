extends SmokeSection
## Gun skill damage must honor skill bonuses without applying general damage twice.
## Isolated run modules and fixed stats keep this check independent of maps and saved progress.

## No map is needed to fire along a clear line.
class OpenRoom extends Room:
	func line_clear(_from: Vector2, _to: Vector2) -> bool:
		return true


## Capture the pre-defense hit from the real gun skill and targeting code.
class CaptureGunSkill extends "res://scripts/skills/gun_skill.gd":
	var amount := 0.0
	var hit_fx: Dictionary = {}

	func hit(_enemy: Enemy, damage: float, _knockback: float, _heavy := true,
			fx := {}, _from := Vector2.INF) -> void:
		amount = damage
		hit_fx = fx


## Tests the common formula and both normal and special gun-skill damage paths.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["jobs", "deck", "gear", "ref_stats", "_stats", "type_points", "_baseline"]:
		saved[key] = Run.get(key)
	# The casts roll on the run's RNG: restore it so later sections see the same rolls.
	var rng_seed := Run.rng.seed
	var rng_state := Run.rng.state
	Run.jobs = []
	Run.deck = RunDeck.new()
	Run.gear = RunGear.new()
	Run.gear.equipment["weapon"] = GearItem.make(load("res://data/items/ebony_gun.tres"))
	Run.ref_stats = {"AC": 10, "AP": 10, "MA": 10, "DA": 10}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	Run._baseline = true  # Ignore wardrobe effects from the loaded profile.
	_check_bonuses()
	for key: String in saved:
		Run.set(key, saved[key])
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state


func _check_bonuses() -> void:
	var gun: CardData = load("res://data/skills/sense/power_shot.tres")
	var ap := CardData.new()
	ap.scaling = "AP"
	var base_gun := Run.formulas.skill_mult(gun)
	var base_ap := Run.formulas.skill_mult(ap)
	var base_basic := Run.formulas.gun_shot_mult()
	var base_shield := _shot(&"shield_breaker")
	var base_power := _shot(&"power_shot")
	var shield: CardData = load("res://data/skills/sense/shield_breaker.tres")
	check(is_equal_approx(base_shield, Run.formulas.GUN_SHOT * base_basic * (1.0 + shield.value_at(1) / 100.0)),
		"unmodified Shield Breaker keeps its base shot plus breach ratio")
	check(is_equal_approx(base_gun, base_basic * Run.formulas.GUN_SHOT / 100.0),
		"unmodified gun skills keep their table's percentage-of-shot conversion")
	var source := JobData.new()
	source.passive_mods = {"skill_damage%": 25.0}
	Run.jobs.append(source)
	check(is_equal_approx(Run.formulas.skill_mult(gun), base_gun * 1.25),
		"gun skills receive the skill-damage bonus")
	check(is_equal_approx(Run.formulas.skill_mult(ap), base_ap * 1.25),
		"AP skills retain the same skill-damage bonus")
	check(is_equal_approx(Run.formulas.gun_shot_mult(), base_basic),
		"skill-only bonuses do not change the basic gun shot")
	check(is_equal_approx(_shot(&"power_shot"), base_power * 1.25),
		"Power Shot delivers its skill-damage bonus to the shot")
	check(is_equal_approx(_shot(&"shield_breaker"), base_shield * 1.25),
		"Shield Breaker's special damage path receives the bonus too")
	source.passive_mods = {"skill_damage%": 25.0, "damage%": 50.0}
	check(is_equal_approx(Run.formulas.skill_mult(gun), base_gun * 1.25 * 1.5),
		"gun skills apply general damage exactly once alongside the skill bonus")
	check(is_equal_approx(_shot(&"shield_breaker"), base_shield * 1.25 * 1.5),
		"Shield Breaker applies general damage exactly once")
	check(is_equal_approx(Run.formulas.gun_shot_mult(), base_basic * 1.5),
		"basic gun shots retain their general damage bonus")
	var second := JobData.new()
	second.passive_mods = {"skill_damage%": 10.0}
	Run.jobs.append(second)
	check(is_equal_approx(Run.formulas.skill_mult(gun), base_gun * 1.25 * 1.1 * 1.5),
		"separate skill bonuses multiply using the existing mod policy")


func _shot(id: StringName) -> float:
	var room := OpenRoom.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room)
	var player := Player.new()  # Position and gun only: never enters the tree.
	player.gun = GunCycle.new()
	var enemy := Enemy.new()
	enemy.state = Enemy.State.CHASE
	enemy.position = Vector2(80.0, 0.0)
	room.enemies.append(enemy)
	var skill := CaptureGunSkill.new()
	skill.card = load("res://data/skills/sense/%s.tres" % id)
	skill.player = player
	skill.room = room
	skill.aim = Vector2.RIGHT
	skill.target = enemy.position
	skill.start()
	if id == &"shield_breaker":
		var debuffs: Dictionary = skill.hit_fx.get("debuffs", {})
		var breach: Array = debuffs.get("gunbreak", [])
		check(breach.size() == 2 and breach[0] == skill.card.value_at(1)
			and breach[1] == skill.card.param("seconds", 1),
			"Shield Breaker retains its breach strength and duration")
	var amount := skill.amount
	room.free()
	enemy.free()
	player.gun.free()
	player.free()
	return amount
