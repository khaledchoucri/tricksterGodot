class_name Door
extends Node2D
## Exit portal (scenes/door.tscn) that shows the reward waiting in the next room.

const REWARDS := {
	"card": {"label": "Skill Card", "color": Color(0.35, 0.85, 0.95)},
	"upgrade": {"label": "Card Upgrade", "color": Color(0.55, 0.95, 0.6)},
	"heal": {"label": "Recovery", "color": Color(1.0, 0.5, 0.55)},
	"galder": {"label": "Galder", "color": Color(1.0, 0.82, 0.35)},
	"shard": {"label": "Harkon Shard", "color": Color(0.8, 0.6, 1.0)},
	"gear": {"label": "Equipment", "color": Color(0.95, 0.65, 0.35)},
	"anvil": {"label": "Anvil", "color": Color(0.75, 0.8, 0.9)},
	"compound": {"label": "Compounder", "color": Color(0.55, 0.85, 0.75)},
	"shop": {"label": "Shop", "color": Color(1.0, 0.9, 0.55)},
	"dig": {"label": "Dig Site", "color": Color(0.8, 0.65, 0.45)},
	"boss": {"label": "Boss", "color": Color(1.0, 0.35, 0.3)},
	"rest": {"label": "Rest Stop", "color": Color(0.6, 0.95, 0.7)},
	"expedition": {"label": "Coral Beach Gate", "color": Color(0.35, 0.85, 0.85)},
}

var reward := "card"
## The monster whose den lies behind this door (its waves lean on it), and
## the name shown under the reward.
var feature: StringName
var feature_name := ""

var _t := 0.0
var _color := Color.WHITE

@onready var label: Label = $Label


func _ready() -> void:
	var info: Dictionary = REWARDS.get(reward, REWARDS.card)
	_color = info.color
	label.text = info.label + ("
%s den" % feature_name if feature_name != "" else "")
	label.add_theme_color_override("font_color", _color.lightened(0.3))


## A short delay keeps the player from entering a door the instant it appears.
func ready_to_enter() -> bool:
	return _t > 0.6


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var grow := minf(_t / 0.4, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for i in 3:
		_ellipse((26.0 - i * 6.0) * grow, Color(_color, 0.18 + 0.1 * i))
	_ring(28.0 * grow, Color(_color, 0.6 + 0.4 * pulse), 2.0)
	# Rising light column marks the exit from a distance.
	var h := 52.0 * grow
	draw_rect(Rect2(-10, -h, 20, h), Color(_color, 0.18 + 0.1 * pulse))
	draw_rect(Rect2(-4, -h - 6, 8, h + 6), Color(_color.lightened(0.4), 0.35))
	draw_circle(Vector2(0, -h - 14), 7.0 * grow, Color(_color, 0.9))
	draw_circle(Vector2(-2, -h - 16), 2.5 * grow, Color(1, 1, 1, 0.85))


func _ellipse(r: float, color: Color) -> void:
	if r <= 0.5:
		return
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_colored_polygon(pts, color)


func _ring(r: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, color, width, true)
