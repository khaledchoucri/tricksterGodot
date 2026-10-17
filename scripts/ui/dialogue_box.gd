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

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %Name
@onready var _text: RichTextLabel = %Text
@onready var _more: Label = %More
@onready var _choices: VBoxContainer = %Choices
@onready var _scroll: ScrollContainer = %ChoiceScroll


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


## Shows a prompt with options ({"title", "tag", "text"}) and returns the
## index chosen.
func choose(line: Dictionary, options: Array) -> int:
	visible = true
	_show(line)
	_typing = false
	_text.visible_ratio = 1.0
	_more.visible = false
	for c in _choices.get_children():
		c.queue_free()
	for i in options.size():
		var o: Dictionary = options[i]
		var b: PickOption = PICK_OPTION.instantiate()
		_choices.add_child(b)
		b.setup(i, o.title, o.get("tag", ""), o.get("text", ""), o.get("icon"))
		b.fit.call_deferred()
		b.disabled = o.get("disabled", false)
		b.custom_minimum_size.x = 440.0
		b.pressed.connect(func() -> void: _chosen.emit(i))
	_scroll.visible = true
	await get_tree().process_frame
	_scroll.scroll_vertical = 0
	if _choices.get_child_count() > 0:
		(_choices.get_child(_choices.get_child_count() - options.size()) as Button).grab_focus()
	var picked: int = await _chosen
	_scroll.visible = false
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
	if not visible or _scroll.visible:
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
