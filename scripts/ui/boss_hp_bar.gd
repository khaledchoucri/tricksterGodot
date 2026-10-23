class_name BossHpBar
extends Control
## The boss's HP at the top of the screen, as the original client draws it (Trickster.bin's
## uBossHPInfoView, 0x79f7e0 builds it, 0x79f4e0 fills it; art from MonsterHPInfoUI.nri,
## exported by tools/setup_assets.py UI_STRIPS): one bar per life left, stacked. The bar it is
## on drains in the colour of its lives left (BossGauge_0..4: red, yellow, green, blue,
## purple; five lives or more stay purple); the next one shows full beneath it at 0xaf alpha.
## Reading: when a bar empties its colour drops away (ours), and the client's separate name
## window and 350 x 9 gauge are drawn here as one box, the gauge at twice its size.

## Gauge colours by lives left, from the client's anim titles.
const GAUGES := 5
## The client's alpha for the bar beneath (0xafffffff, 0x79f698).
const UNDER_ALPHA := 175.0 / 255.0
## The art's sizes: the gauge's frame is 9 px high, the fill 7 px inside it, both with 2-px
## caps; the window 52 px high with 3-px sides.
const FRAME_H := 9.0
const FILL_H := 7.0
const CAP := 2
const WINDOW_SIDE := 3
const WINDOW_EDGE := 4
## Drawn at twice the art's size. Ours.
const ART_SCALE := 2.0
## How long a broken bar takes to fall away, and how far it falls. Ours.
const DROP_FOR := 0.6
const DROP_BY := 10.0

var _name: Label
var _count: Label
var _gauge: Control
var _under: NinePatchRect
var _top: NinePatchRect
var _frame: NinePatchRect
var _layer := -1
var _ratio := 1.0
var _textures: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in GAUGES:
		_textures.append(_art("boss_gauge_%d" % i))
	var window := _patch(_art("boss_window"), WINDOW_SIDE, WINDOW_EDGE)
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.05, 0.12, 0.55)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	add_child(window)
	_name = _label(15, Color(0.878, 0.71, 0.302))
	_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_name.offset_top = 4.0
	_name.offset_bottom = 24.0
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count = _label(12, Color(1, 1, 1, 0.75))
	_count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_count.offset_left = -48.0
	_count.offset_right = -10.0
	_count.offset_top = 6.0
	_count.offset_bottom = 24.0
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gauge = Control.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.scale = Vector2.ONE * ART_SCALE
	add_child(_gauge)
	_under = _patch(null, CAP, 0)
	_top = _patch(null, CAP, 0)
	_frame = _patch(_art("boss_gauge_frame"), CAP, 0)
	for n: NinePatchRect in [_under, _top]:
		n.position = Vector2(0, (FRAME_H - FILL_H) / 2.0)
		_gauge.add_child(n)
	_gauge.add_child(_frame)
	_under.modulate.a = UNDER_ALPHA
	resized.connect(_layout)
	_layout()


## Shows `hp` of `max_hp` split into `bars` bars.
func set_hp(boss_name: String, hp: int, max_hp: int, bars: int) -> void:
	_name.text = boss_name
	bars = maxi(bars, 1)
	var per := float(max_hp) / bars
	var left := clampi(ceili(hp / per), 1, bars) if hp > 0 else 1
	var layer := left - 1
	var ratio := clampf((hp - per * layer) / per, 0.0, 1.0) if hp > 0 else 0.0
	if _layer > layer:
		_drop(_layer)
	_layer = layer
	_top.texture = gauge_texture(layer)
	_under.texture = gauge_texture(layer - 1) if layer > 0 else null
	_under.visible = layer > 0
	_ratio = ratio
	_top.size = Vector2(_inner_width() * ratio, FILL_H)
	_top.visible = ratio > 0.0
	_count.text = "x%d" % left if bars > 1 else ""


## The lives left the bar it shows is on (0 for the last bar), and its fill (0-1): for tests.
func layer() -> int:
	return _layer


func fill() -> float:
	return _top.size.x / _inner_width() if _top.visible else 0.0


## The gauge art for a bar with `lives` lives left after it.
func gauge_texture(lives: int) -> Texture2D:
	return _textures[clampi(lives, 0, GAUGES - 1)] if lives >= 0 and not _textures.is_empty() else null


func _layout() -> void:
	var w := (size.x - 20.0) / ART_SCALE
	_gauge.position = Vector2(10.0, size.y - FRAME_H * ART_SCALE - 7.0)
	_gauge.size = Vector2(w, FRAME_H)
	_frame.size = Vector2(w, FRAME_H)
	_under.size = Vector2(w, FILL_H)
	_top.size = Vector2(w * _ratio, FILL_H)


func _inner_width() -> float:
	return maxf(_gauge.size.x, 1.0)


## A broken bar's colour falls away under the gauge and fades.
func _drop(layer_lost: int) -> void:
	var ghost := _patch(gauge_texture(layer_lost), CAP, 0)
	ghost.size = Vector2(_inner_width(), FILL_H)
	ghost.position = Vector2(0, (FRAME_H - FILL_H) / 2.0)
	_gauge.add_child(ghost)
	var tw := ghost.create_tween().set_parallel()
	tw.tween_property(ghost, "position:y", ghost.position.y + DROP_BY, DROP_FOR).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "modulate:a", 0.0, DROP_FOR)
	tw.chain().tween_callback(ghost.queue_free)


func _art(name: String) -> Texture2D:
	var path := Assets.ui(name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _patch(tex: Texture2D, side: int, edge: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.patch_margin_left = side
	n.patch_margin_right = side
	n.patch_margin_top = edge
	n.patch_margin_bottom = edge
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
