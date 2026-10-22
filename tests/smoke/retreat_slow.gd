extends SmokeSection
## Ranged retreat must honor the same Slow/DX movement factor as chasing.
## Exercises real status and AI methods with inert visuals and an open navigation fixture.

## Control whether retreat is possible without loading a map.
class OpenRoom extends Room:
	var retreat_open := true

	func is_walkable(_point: Vector2) -> bool:
		return retreat_open

	func line_clear(_from: Vector2, _to: Vector2) -> bool:
		return true


## Keep production AI and debuffs without actor setup or automatic updates.
class InertEnemy extends Enemy:
	func _ready() -> void:
		pass


## Tests reductions, their clamp, expiration, forced movement and chase fallback.
func run() -> void:
	var hidden := Run.hidden
	Run.hidden = false
	var room := OpenRoom.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room)
	var player := Player.new()  # Only target position/state; never enters the tree.
	player.position = Vector2(20.0, 0.0)
	var enemy := _enemy(room, player)
	enemy._state_chase()
	check(enemy.velocity == Vector2(-100.0, 0.0), "an unmodified ranged enemy retreats at its walk speed")
	_reductions(enemy)
	enemy.debuffs.clear()
	enemy.apply_debuff("slow", 50.0, 2.0)
	enemy.apply_debuff("dx", 25.0, 2.0)
	enemy._state_chase()
	check(enemy.velocity.is_equal_approx(Vector2(-25.0, 0.0)), "Slow and DX combine using the existing movement rule")
	enemy.debuffs.clear()
	enemy.apply_debuff("slow", 50.0, 2.0)
	enemy._knock = Vector2(20.0, 10.0)
	enemy._state_chase()
	check(enemy.velocity.is_equal_approx(Vector2(-30.0, 10.0)), "slowing retreat does not reduce forced knockback")
	enemy._knock = Vector2.ZERO
	room.retreat_open = false
	enemy._state_chase()
	check(enemy.velocity.is_equal_approx(Vector2(50.0, 0.0)), "a blocked retreat retains slowed pursuit fallback")
	room.retreat_open = true
	enemy.attack.ranged = false
	enemy._state_chase()
	check(enemy.velocity.is_equal_approx(Vector2(50.0, 0.0)), "melee pursuit keeps its existing slow behavior")
	enemy.attack.ranged = true
	player.position = Vector2(200.0, 0.0)
	enemy._state_chase()
	check(enemy.velocity.is_equal_approx(Vector2(50.0, 0.0)), "ranged pursuit outside keep-away range stays slowed")
	room.free()
	player.free()
	Run.hidden = hidden


func _reductions(enemy: Enemy) -> void:
	for status: String in ["slow", "dx"]:
		enemy.debuffs.clear()
		enemy.apply_debuff(status, 50.0, 2.0)
		enemy._state_chase()
		check(enemy.velocity.is_equal_approx(Vector2(-50.0, 0.0)),
			"%s halves ranged retreat at 50 percent" % status)
		enemy.apply_debuff(status, 150.0, 2.0)
		enemy._state_chase()
		check(enemy.velocity.is_equal_approx(Vector2(-20.0, 0.0)),
			"%s respects the existing minimum movement factor" % status)
		enemy.debuffs[status] = [150.0, enemy.now() - 0.1]
		enemy._state_chase()
		check(enemy.velocity == Vector2(-100.0, 0.0), "%s expiry restores normal retreat speed" % status)


func _enemy(room: Room, player: Player) -> Enemy:
	var enemy := InertEnemy.new()
	enemy.room = room
	enemy.player = player
	enemy.state = Enemy.State.CHASE
	enemy.walk_speed = 100.0
	enemy.run_speed = 100.0
	enemy.attack = AttackPattern.new()
	enemy.attack.ranged = true
	enemy.attack.keep_away = 100.0
	enemy.attack.range = 0.0
	var sprite := ActorSprite.new()
	sprite.name = "Sprite"
	enemy.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	enemy.add_child(shape)
	room.add_child(enemy)
	return enemy
