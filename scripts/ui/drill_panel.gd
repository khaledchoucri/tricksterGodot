class_name DrillPanel
extends PanelContainer
## The drilling minigame (a Dig Site reward): a marker sweeps the bar and
## each strike (Space, LMB or Enter) lands in or out of the sweet spot. Good
## strikes dig deeper; the centre of the spot digs half again. Misses make
## noise. Runs while the game is paused.

signal finished(depth: int, misses: int)

const BAR := Vector2(520, 26)
const GOOD := Color(0.45, 0.85, 0.5)
const BEST := Color(0.95, 0.9, 0.45)

var _drill: DrillData
var _zone := 0.14
var _spot := 0.5
var _t := 0.0
var _left := 0
var _depth := 0
var _misses := 0
var _flash := 0.0
var _last := ""

@onready var _title: Label = %DrillTitle
@onready var _info: Label = %DrillInfo
@onready var _bar: Control = %DrillBar


func _ready() -> void:
	visible = false
	_bar.draw.connect(_draw_bar)


## Starts a dig with `drill`; `zone_bonus` widens the sweet spot (DA).
func start(drill: DrillData, zone_bonus := 0.0) -> void:
	_drill = drill
	_zone = clampf(drill.zone + zone_bonus, 0.05, 0.5)
	_left = drill.strikes
	_depth = 0
	_misses = 0
	_t = 0.0
	_last = ""
	_new_spot()
	visible = true
	_refresh()


func _new_spot() -> void:
	_spot = randf_range(_zone / 2.0 + 0.05, 1.0 - _zone / 2.0 - 0.05)


func _marker() -> float:
	var x := fmod(_t * _drill.speed, 2.0)
	return x if x <= 1.0 else 2.0 - x  # back and forth


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_bar.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _left <= 0:
		return
	if event.is_action_pressed("dash") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_strike()


func _strike() -> void:
	var off := absf(_marker() - _spot)
	_left -= 1
	if off <= _zone / 2.0:
		var gain := _drill.scoop * (1.5 if off <= _zone / 6.0 else 1.0)
		_depth = mini(_drill.depth, _depth + roundi(gain))
		_last = "Perfect!" if off <= _zone / 6.0 else "Good"
		Audio.play("ui_drillboy1.wav", -4.0)
	else:
		_misses += 1
		_last = "Clang!"
		Audio.play("etc_miss.wav", -4.0)
	_flash = 0.25
	_new_spot()
	_refresh()
	if _left <= 0 or _depth >= _drill.depth:
		_left = 0
		await get_tree().create_timer(0.6, true, false, true).timeout
		visible = false
		finished.emit(_depth, _misses)


func _refresh() -> void:
	_title.text = "Dig Site  ·  %s" % _drill.display_name
	_info.text = "Depth %d / %d  ·  %d strike%s left  ·  %s" % [_depth, _drill.depth, _left, "" if _left == 1 else "s",
		_last if _last != "" else "Space or click to strike"]


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, BAR)
	_bar.draw_rect(r, Color(0.08, 0.12, 0.16, 0.9))
	var zx := (_spot - _zone / 2.0) * BAR.x
	_bar.draw_rect(Rect2(zx, 0, _zone * BAR.x, BAR.y), Color(GOOD, 0.75))
	_bar.draw_rect(Rect2((_spot - _zone / 6.0) * BAR.x, 0, _zone / 3.0 * BAR.x, BAR.y), Color(BEST, 0.85))
	var mx := _marker() * BAR.x
	_bar.draw_rect(Rect2(mx - 3, -6, 6, BAR.y + 12), Color(1, 1, 1, 1.0 if _flash <= 0.0 else 0.5))
	_bar.draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)
