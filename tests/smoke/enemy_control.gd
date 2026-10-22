extends SmokeSection
## Held enemies must not retreat, wander or acquire attacks, even after losing their target.
## Tests production state handlers with inert visuals and an explicitly open navigation surface.

## No map loading: every retreat destination is walkable in this fixture.
class OpenRoom extends Room:
	func is_walkable(_point: Vector2) -> bool:
		return true


## Keep production AI and status application without actor loading.
class FixtureEnemy extends Enemy:
	func _ready() -> void:
		pass


## Ours: arbitrary knockback used to distinguish forced movement from AI movement.
const KNOCK := Vector2(7.0, 3.0)


## Covers both immobilizing statuses, recovery, knockback and existing boss immunity.
func run() -> void:
	var hidden := Run.hidden
	var rng_state := Run.rng.state
	Run.hidden = false
	var room := OpenRoom.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room)
	var player := Player.new()  # Only its position/state are needed; never enters the tree.
	player.position = Vector2(20.0, 0.0)
	var enemy := FixtureEnemy.new()
	enemy.player = player
	enemy.room = room
	enemy.attack = AttackPattern.new()
	enemy.attack.ranged = true
	enemy.attack.keep_away = 100.0
	var sprite := ActorSprite.new()
	sprite.name = "Sprite"
	enemy.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	enemy.add_child(shape)
	room.add_child(enemy)
	for status: String in ["hold", "frozen"]:
		_held_states(enemy, player, status)
	enemy.debuffs.clear()
	enemy.is_boss = true
	enemy.state = Enemy.State.CHASE
	enemy.apply_debuff("hold", 1.0, 2.0)
	enemy.apply_debuff("frozen", 1.0, 2.0)
	enemy._state_chase()
	check(not enemy.is_held() and enemy.velocity.x < 0.0, "boss immunity still permits retreat")
	room.free()
	player.free()
	Run.hidden = hidden
	Run.rng.state = rng_state


func _held_states(enemy: Enemy, player: Player, status: String) -> void:
	enemy.debuffs.clear()
	enemy.state = Enemy.State.WINDUP
	enemy.room.attackers.append(enemy)
	enemy.apply_debuff(status, 1.0, 2.0)
	check(enemy.state == Enemy.State.CHASE and not enemy in enemy.room.attackers,
		"%s still interrupts windup and releases its attack token" % status)
	enemy._knock = Vector2.ZERO
	enemy._state_chase()
	check(enemy.velocity == Vector2.ZERO and enemy.state == Enemy.State.CHASE,
		"%s stops a nearby ranged enemy retreating" % status)
	enemy._knock = KNOCK
	enemy._state_chase()
	check(enemy.velocity == KNOCK, "%s preserves forced knockback without retreat" % status)
	enemy.state = Enemy.State.IDLE
	enemy._state_len = 100.0
	enemy._wander_target = Vector2(80.0, 0.0)
	enemy._state_idle()
	check(enemy.velocity == KNOCK, "%s stops idle wandering" % status)
	enemy.state = Enemy.State.CHASE
	Run.hidden = true
	enemy._state_chase()
	check(enemy.state == Enemy.State.CHASE and enemy.velocity == KNOCK,
		"%s does not start wandering when the player hides" % status)
	Run.hidden = false
	enemy.state = Enemy.State.CHASE
	enemy.player = null
	enemy._state_chase()
	check(enemy.state == Enemy.State.CHASE and enemy.velocity == KNOCK,
		"%s does not start wandering when its target disappears" % status)
	enemy.player = player
	enemy.state = Enemy.State.CHASE
	enemy.debuffs[status] = [1.0, enemy.now() - 0.1]
	enemy._state_chase()
	check(enemy.velocity.x < KNOCK.x and enemy.state == Enemy.State.CHASE,
		"%s expiring restores ranged retreat" % status)
	enemy.state = Enemy.State.IDLE
	enemy._state_idle()
	check(enemy.velocity.x > KNOCK.x, "%s expiring restores idle wandering" % status)
