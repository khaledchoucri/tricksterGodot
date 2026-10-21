class_name SkillSlot
extends VBoxContainer
## One skill slot on the HUD: the skill's icon, its key, MP cost, a cooldown
## shade that drains from the top, and its name and level underneath.

const POOR := Color(0.45, 0.5, 0.75)  # icon tint while MP is too low
const LOCKED := Color(0.3, 0.3, 0.3)  # a skill your beast form can't use

@export var key := "RMB"

static var _icons: Dictionary = {}  # skill row ID -> Texture2D or null

@onready var _box: Panel = %Box
@onready var _icon: TextureRect = %Icon
@onready var _shade: ColorRect = %Shade
@onready var _timer: Label = %Timer
@onready var _cost: Label = %Cost
@onready var _name: Label = %Name


func _ready() -> void:
	(%Key as Label).text = key


func clear() -> void:
	_icon.texture = null
	_name.text = ""
	_cost.text = ""
	_timer.text = ""
	_set_shade(1.0)


## `left` and `total` are the cooldown's remaining and full length in seconds;
## `locked`: unusable in Metamorphosis, shown dark and marked.
func show_skill(card: CardData, level: int, left: float, total: float, affordable: bool, locked := false) -> void:
	_icon.texture = _icon_for(card)
	_icon.modulate = LOCKED if locked else Color.WHITE if affordable else POOR
	_name.text = "%s %d%s" % [card.display_name, level, "  (locked)" if locked else ""]
	_cost.text = str(card.mp_at(level))
	_timer.text = "%.1f" % left if left > 0.0 else ""
	_set_shade(clampf(left / maxf(total, 0.01), 0.0, 1.0))


func pulse() -> void:
	_box.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(_box, "modulate", Color.WHITE, 0.25)


func _set_shade(frac: float) -> void:
	_shade.size = Vector2(_box.size.x, _box.size.y * frac)
	_shade.position = Vector2(0, _box.size.y - _shade.size.y)


static func _icon_for(card: CardData) -> Texture2D:
	if not _icons.has(card.skill_id):
		var path := Assets.skill_icon(card.skill_id)
		_icons[card.skill_id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[card.skill_id]
