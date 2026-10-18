class_name CastBar
extends Node2D
## The cast bar under a mage while a spell is being cast (the original shows
## the activation time the same way): it fills up until the spell goes off.

const WIDTH := 46.0
const HEIGHT := 5.0

var caster: SkillCaster


func _ready() -> void:
	z_index = 30
	position = Vector2(-WIDTH / 2.0, 10.0)


func _process(_delta: float) -> void:
	visible = caster != null and caster.casting_left() > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var done := caster.cast_progress()
	draw_rect(Rect2(-1, -1, WIDTH + 2, HEIGHT + 2), Color(0.05, 0.08, 0.12, 0.85))
	draw_rect(Rect2(0, 0, WIDTH * done, HEIGHT), Color(0.6, 0.85, 1.0))
	draw_rect(Rect2(WIDTH * done - 1.5, -1, 3, HEIGHT + 2), Color(1, 1, 1, 0.9))
