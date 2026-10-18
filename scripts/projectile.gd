class_name Projectile
extends Node2D
## Enemy shot (scenes/projectile.tscn): a glowing orb with a short tail that
## flies straight and hurts the player on contact.

## Height above the ground the shot flies at; hits are tested on the ground below.
const FLY_HEIGHT := 18.0

@export var speed := 210.0
@export var radius := 9.0
@export var life := 2.2
@export var color := Color(0.55, 0.85, 1.0)

var direction := Vector2.RIGHT
var damage := 8
var accuracy := 50
## The monster that fired it (its element, and who a reflect hits back).
var shooter: Enemy
## Set by the shooter before the projectile enters the tree.
var room: Room
var player: Player

var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	position += direction * speed * delta
	var ground_pos := global_position + Vector2(0, FLY_HEIGHT)
	if _t > life or not room.is_inside(ground_pos):
		queue_free()
		return
	if is_instance_valid(player) and Combat.in_circle(ground_pos, player.global_position, radius, 10.0):
		if not player.is_invulnerable():
			player.take_hit(damage, Combat.ground(direction).normalized(), 160.0, true, accuracy, shooter)
			queue_free()
	queue_redraw()


func _draw() -> void:
	for i in 4:
		var back := -direction * (6.0 + i * 6.0)
		draw_circle(back, radius * (0.8 - i * 0.15), Color(color, 0.35 - i * 0.07))
	draw_circle(Vector2.ZERO, radius + 3.0, Color(color, 0.35))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-2, -2), radius * 0.45, Color(1, 1, 1, 0.9))
