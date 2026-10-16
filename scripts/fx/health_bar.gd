class_name HealthBar
extends Node2D
## Small health bar under an enemy's feet. Reads the parent enemy's hp each
## frame; recent damage shows as a pale chunk that drains after a moment.
## Bosses use the HUD bar instead.

const HEIGHT := 4.0
const BG := Color(0.06, 0.1, 0.13, 0.85)
const FILL := Color("d9573f")
const ELITE_FILL := Color("e0b54d")
const CHIP := Color(1.0, 0.92, 0.8)

var width := 34.0

var _shown := 1.0   # fraction drawn as current health
var _chip := 1.0    # fraction drawn as recently lost health
var _chip_hold := 0.0

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	width = clampf(enemy.body_radius * 2.6, 28.0, 64.0)
	visible = not enemy.is_boss


func _process(delta: float) -> void:
	if not visible:
		return
	var frac := clampf(float(enemy.hp) / maxf(1.0, enemy.max_hp), 0.0, 1.0)
	if frac < _shown:
		_chip_hold = 0.35
	_shown = frac
	if _chip_hold > 0.0:
		_chip_hold -= delta
	else:
		_chip = move_toward(_chip, _shown, delta * 1.5)
	_chip = maxf(_chip, _shown)
	# Follow the enemy's spawn fade-in and death fade-out.
	modulate.a = enemy.sprite.modulate.a if enemy.state != Enemy.State.DEAD else 0.0
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-width / 2.0, 0.0, width, HEIGHT)
	draw_rect(r.grow(1.0), BG)
	draw_rect(Rect2(r.position, Vector2(width * _chip, HEIGHT)), CHIP)
	draw_rect(Rect2(r.position, Vector2(width * _shown, HEIGHT)), ELITE_FILL if enemy.is_elite else FILL)
