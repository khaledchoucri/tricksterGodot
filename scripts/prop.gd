class_name Prop
extends Sprite2D
## A map prop (tree, banner, building...). Fades out while it hides an actor
## standing behind it, so the fight stays readable.

const HIDE_PLAYER_ALPHA := 0.3
const HIDE_ENEMY_ALPHA := 0.55
const FADE_SPEED := 5.0

## Top-layer props (canopies, banners) are drawn over everything.
var always_front := false
## Alpha the prop is easing toward; the room sets it every physics frame.
var target_alpha := 1.0

static var _masks: Dictionary = {}  # texture path -> BitMap

var _mask: BitMap
var _bounds: Rect2


func setup(tex: Texture2D, anchor: Vector2, front: bool) -> void:
	texture = tex
	centered = false
	offset = -anchor
	always_front = front
	_bounds = Rect2(position - anchor, tex.get_size())
	if not _masks.has(tex.resource_path):
		var bm := BitMap.new()
		bm.create_from_image_alpha(tex.get_image(), 0.4)
		_masks[tex.resource_path] = bm
	_mask = _masks[tex.resource_path]


## True when this prop is drawn over `point` (a world position) of an actor
## whose feet are at `feet_y`.
func hides(point: Vector2, feet_y: float) -> bool:
	if not always_front and feet_y >= position.y:
		return false  # the actor is in front of the prop
	if not _bounds.has_point(point):
		return false
	var p := Vector2i(point - _bounds.position)
	return _mask.get_bitv(p)


func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, target_alpha, delta * FADE_SPEED)
