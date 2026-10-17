class_name DialogueBox
extends Control
## Conversation panel at the bottom of the screen: portrait, speaker name,
## typewriter text, and an optional list of choices. Advance with interact,
## attack, Enter or a click.

signal _advanced
signal _chosen(index: int)

const CHARS_PER_SECOND := 55.0
const PICK_OPTION := preload("res://scenes/ui/pick_option.tscn")

var _typing := false
## The open choice list: buttons in option order and the exit's index.
var _buttons: Array[PickOption] = []
var _cancel := -1

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %Name
@onready var _text: RichTextLabel = %Text
@onready var _more: Label = %More
@onready var _choices: VBoxContainer = %Choices
@onready var _scroll: ScrollContainer = %ChoiceScroll
@onready var _footer: VBoxContainer = %ChoiceFooter


func _ready() -> void:
	visible = false


## Shows lines one after another; each is {"name", "portrait" (Texture2D or
## null), "text"}. Returns when the last is dismissed.
func play(lines: Array) -> void:
	visible = true
	_scroll.visible = false
	for line: Dictionary in lines:
		_show(line)
		await _advanced
	visible = false


## Shows a prompt with options ({"title", "tag", "text"}, optional "icon",
## "disabled", "cancel") and returns the index chosen. The cancel option
## (Leave, Back...) is pinned under the list and picked with Esc; keys 1-9
## pick the others.
func choose(line: Dictionary, options: Array) -> int:
	visible = true
	_show(line)
	_typing = false
	_text.visible_ratio = 1.0
	_more.visible = false
	for box: Control in [_choices, _footer]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_buttons.clear()
	_cancel = -1
	var key := 0
	for i in options.size():
		var o: Dictionary = options[i]
		var cancel: bool = o.get("cancel", false) and _cancel < 0
		var b: PickOption = PICK_OPTION.instantiate()
		(_footer if cancel else _choices).add_child(b)
		if cancel:
			_cancel = i
			b.setup("Esc", o.title, o.get("tag", ""), o.get("text", ""), o.get("icon"))
		else:
			key += 1
			b.setup(str(key) if key <= 9 else "", o.title, o.get("tag", ""), o.get("text", ""), o.get("icon"))
		b.disabled = o.get("disabled", false)
		b.custom_minimum_size.x = 440.0
		_solid(b)
		b.pressed.connect(func() -> void: _chosen.emit(i))
		_buttons.append(b)
	_footer.visible = _cancel >= 0
	_scroll.offset_bottom = -252.0 if _footer.visible else -180.0
	_scroll.visible = true
	await get_tree().process_frame
	for b in _buttons:
		b.fit()
	if _footer.visible:
		_footer.offset_top = _footer.offset_bottom - _footer.get_combined_minimum_size().y
		_scroll.offset_bottom = _footer.offset_top - 6.0
	_scroll.scroll_vertical = 0
	for b in _buttons:
		if not b.disabled and b.get_parent() == _choices:
			b.grab_focus()
			break
	var picked: int = await _chosen
	_scroll.visible = false
	_footer.visible = false
	visible = false
	return picked


func _show(line: Dictionary) -> void:
	_name.text = line.get("name", "")
	_portrait.texture = line.get("portrait")
	_portrait.visible = _portrait.texture != null
	_text.text = line.get("text", "")
	_text.visible_ratio = 0.0
	_more.visible = false
	_typing = true


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	var total := maxi(_text.get_total_character_count(), 1)
	_text.visible_ratio = minf(1.0, _text.visible_ratio + delta * CHARS_PER_SECOND / total)
	if _text.visible_ratio >= 1.0:
		_typing = false
		_more.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if visible and _scroll.visible:
		_choice_input(event)
		return
	if not visible:
		return
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("attack") \
		or event.is_action_pressed("ui_accept")
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_text.visible_ratio = 1.0  # first press finishes the line
		_typing = false
		_more.visible = true
	else:
		_advanced.emit()


func _choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _cancel >= 0:
		get_viewport().set_input_as_handled()
		_chosen.emit(_cancel)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_1
		var listed: Array[int] = []
		for i in _buttons.size():
			if i != _cancel:
				listed.append(i)
		if n >= 0 and n < mini(listed.size(), 9) and not _buttons[listed[n]].disabled:
			get_viewport().set_input_as_handled()
			_chosen.emit(listed[n])


## True when option `i` can be clicked: inside the screen, and (for listed
## options) its scroll area is on screen.
func choice_reachable(i: int) -> bool:
	if i < 0 or i >= _buttons.size():
		return false
	var screen := get_viewport().get_visible_rect()
	if i == _cancel:
		return screen.encloses(_buttons[i].get_global_rect())
	return screen.encloses(_scroll.get_global_rect())


## Choices float over the city with no panel behind them; make their
## backgrounds nearly opaque so the world doesn't show through the text.
func _solid(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := b.get_theme_stylebox(state)
		if sb is StyleBoxFlat:
			var solid := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			solid.bg_color.a = maxf(solid.bg_color.a, 0.94)
			b.add_theme_stylebox_override(state, solid)
