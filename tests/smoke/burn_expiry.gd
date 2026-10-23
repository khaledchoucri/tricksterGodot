extends SmokeSection
## Burn expiry must separate a new application from the previous burn's DPS and tick phase.
## Exercises production hit/status handling with inert visuals and a controlled gameplay clock.

## Keep the real hit and burn logic without actor loading or automatic physics updates.
class FixtureEnemy extends Enemy:
	var clock := 10.0

	func _ready() -> void:
		pass

	func now() -> float:
		return clock


## Covers fresh burns after expiry and preserves the current active-refresh behavior.
func run() -> void:
	var enemy := _enemy()
	_burn(enemy, 80.0, 1.0)
	var hp := enemy.hp
	enemy._tick_status(0.2)
	check(enemy.hp == hp, "burn waits for its first half-second tick")
	enemy.clock = enemy.burn_until
	_burn(enemy, 20.0, 3.0)
	check(enemy.burn_dps == 20.0, "a burn applied at expiry does not inherit the old stronger DPS")
	check(enemy._burn_tick == 0.0, "a new burn starts a fresh tick interval")
	enemy._tick_status(0.3)
	check(enemy.hp == hp, "a new burn does not spend the old burn's partial tick")
	enemy._tick_status(0.2)
	check(enemy.hp == hp - 10, "the fresh weaker burn deals its own DPS on schedule")
	enemy.free()
	enemy = _enemy()
	_burn(enemy, 80.0, 1.0)
	enemy._tick_status(0.2)
	enemy.clock += 5.0
	hp = enemy.hp
	enemy._tick_status(0.5)
	check(enemy.hp == hp, "expired burns do not deal damage during the gap")
	_burn(enemy, 10.0, 2.0)
	check(enemy.burn_dps == 10.0 and enemy._burn_tick == 0.0,
		"reapplying after an expiry tick discards stale strength and tick progress")
	enemy._tick_status(0.5)
	check(enemy.hp == hp - 5, "reapplying after a long gap uses the new burn's DPS")
	enemy.free()
	_active_refresh()


func _active_refresh() -> void:
	var enemy := _enemy()
	_burn(enemy, 80.0, 2.0)
	enemy._tick_status(0.2)
	enemy.clock += 0.1
	_burn(enemy, 20.0, 3.0)
	check(enemy.burn_dps == 80.0, "an active weaker refresh retains the existing stronger burn")
	check(is_equal_approx(enemy.burn_until, enemy.now() + 3.0) and enemy._burn_tick == 0.2,
		"an active refresh keeps the existing deadline policy and tick progress")
	var hp := enemy.hp
	enemy._tick_status(0.3)
	check(enemy.hp == hp - 40, "an active refresh continues the current burn tick")
	enemy.clock += 0.1
	_burn(enemy, 100.0, 1.0)
	check(enemy.burn_dps == 100.0, "a stronger active refresh still increases burn DPS")
	enemy.state = Enemy.State.DEAD
	hp = enemy.hp
	enemy._tick_status(0.5)
	check(enemy.hp == hp, "dead enemies do not take burn ticks")
	enemy.free()


func _enemy() -> FixtureEnemy:
	var enemy := FixtureEnemy.new()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.state = Enemy.State.CHASE
	enemy.attack = AttackPattern.new()
	enemy.attack.poise = -1  # Prevent hit reactions; only status behavior is under test.
	var sprite := ActorSprite.new()
	sprite.name = "Sprite"
	enemy.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	enemy.add_child(shape)
	add_child(enemy)
	return enemy


func _burn(enemy: Enemy, dps: float, seconds: float) -> void:
	enemy.take_hit(0, Vector2.RIGHT, 0.0, false, {"burn": dps, "burn_for": seconds})
