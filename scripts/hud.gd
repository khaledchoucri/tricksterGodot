class_name Hud
extends CanvasLayer
## On-screen interface (scenes/hud.tscn): status and MP, skill slots, room
## progress, boss bar, the MMO-style system log, the pick-one panel (cards,
## level-ups, slot swaps) and the results screen. Layout and styling live in
## the scene and ui/hud_theme.tres; this script fills in the values.

signal picked(index: int)
signal restart_requested

const MUTED := Color(1, 1, 1, 0.6)
const SLOT_KEYS: Array[String] = ["RMB", "Q", "E"]
const PICK_OPTION := preload("res://scenes/ui/pick_option.tscn")
const LOG_LINES := 6

@onready var pick_panel: PanelContainer = %PickPanel
@onready var results_panel: PanelContainer = %ResultsPanel
@onready var _slots: Array[SkillSlot] = [$Root/SlotBar/Slot1, $Root/SlotBar/Slot2, $Root/SlotBar/Slot3]

var _pick_count := 0


func _ready() -> void:
	(%AgainButton as Button).pressed.connect(func() -> void: restart_requested.emit())
	Events.skill_cast.connect(func(slot: int) -> void: _slots[slot].pulse())
	Events.mp_short.connect(func() -> void:
		_flash(%MpBar, Color(1.8, 0.6, 0.6))
		Audio.play("etc_miss.wav", -10.0))


# ---------------------------------------------------------------- updates

func refresh(player: Player) -> void:
	var hp: ProgressBar = %HpBar
	hp.max_value = Run.max_hp
	hp.value = Run.hp
	%HpLabel.text = "HP %d / %d" % [Run.hp, Run.max_hp]
	var xp: ProgressBar = %XpBar
	xp.max_value = Run.exp_to_next()
	xp.value = Run.xp
	%LevelLabel.text = "Lv %d" % Run.level
	var mp: ProgressBar = %MpBar
	mp.max_value = Run.MAX_MP
	mp.value = Run.mp
	%MpLabel.text = "MP %d / %d" % [Run.mp, Run.MAX_MP]
	%GalderLabel.text = "%d Galder" % Run.galder
	var owned: PackedStringArray = []
	for id: StringName in Run.cards:
		owned.append("%s %d" % [Run.region.card(id).display_name, Run.cards[id]])
	%CardsLabel.text = "  ·  ".join(owned)
	_refresh_slots(player)
	if is_instance_valid(player):
		%DashLabel.text = "Dash  [Space]  " + ("ready" if player.can_dash() else "...")


func _refresh_slots(player: Player) -> void:
	for i in _slots.size():
		var id: StringName = Run.loadout[i]
		if id == &"":
			_slots[i].clear()
			continue
		var card := Run.region.card(id)
		var level := Run.card_level(id)
		var left := 0.0
		if is_instance_valid(player):
			left = maxf(0.0, player.skills.slot_ready_at[i] - player.now())
		_slots[i].show_skill(card, level, left, card.cooldown_at(level) * Run.skill_cooldown_mult(), Run.mp >= card.mp_cost)


func _flash(node: CanvasItem, color: Color) -> void:
	node.modulate = color
	node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.25)


func set_room(text: String) -> void:
	%RoomLabel.text = text


func show_boss(enemy_name: String, hp: int, max_hp: int) -> void:
	%BossBox.visible = true
	%BossName.text = enemy_name
	var bar: ProgressBar = %BossBar
	bar.max_value = max_hp
	bar.value = hp


func hide_boss() -> void:
	%BossBox.visible = false


func log_line(text: String, color := MUTED) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	var box: VBoxContainer = %LogBox
	box.add_child(l)
	while box.get_child_count() > LOG_LINES:
		box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)


func center(text: String, hold := 0.0) -> void:
	var label: Label = %CenterLabel
	label.text = text
	label.modulate.a = 1.0
	if hold > 0.0:
		var tw := label.create_tween()
		tw.tween_interval(hold)
		tw.tween_property(label, "modulate:a", 0.0, 0.4)


func notice(text: String) -> void:
	var label: Label = %Notice
	label.text = text
	label.modulate.a = 1.0
	var tw := label.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)


func fade(to_alpha: float, time := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(%Overlay, "color:a", to_alpha, time)
	await tw.finished


# ---------------------------------------------------------------- pickers

## options: Array of {"title": String, "tag": String, "text": String}
func show_pick(title: String, options: Array) -> void:
	var list: VBoxContainer = %PickList
	for c in list.get_children():
		c.queue_free()
	%PickTitle.text = title
	_pick_count = options.size()
	for i in options.size():
		var o: Dictionary = options[i]
		var option: PickOption = PICK_OPTION.instantiate()
		list.add_child(option)
		option.setup(i, o.title, o.get("tag", ""), o.text)
		option.pressed.connect(_on_pick.bind(i))
	pick_panel.visible = true
	await get_tree().process_frame
	if _pick_count > 0 and list.get_child_count() > 0:
		(list.get_child(list.get_child_count() - _pick_count) as Button).grab_focus()


func _on_pick(i: int) -> void:
	if not pick_panel.visible:
		return
	pick_panel.visible = false
	picked.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if pick_panel.visible and event is InputEventKey and event.pressed:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < _pick_count:
			_on_pick(n)
	if results_panel.visible and event.is_action_pressed("restart"):
		restart_requested.emit()


func show_results(won: bool) -> void:
	var title: Label = %ResultsTitle
	title.text = "Coral Beach cleared" if won else "Rollback"
	title.add_theme_color_override("font_color", Color("e0b54d") if won else Color("f07a62"))
	var cards: PackedStringArray = []
	for id: StringName in Run.cards:
		cards.append("%s Lv %d" % [Run.region.card(id).display_name, Run.cards[id]])
	%ResultsBody.text = "\n".join([
		"Rooms cleared    %d / %d" % [Run.depth + (1 if won else 0), Run.plan.size()],
		"Time             %d:%04.1f" % [int(Run.time) / 60, fmod(Run.time, 60.0)],
		"Level            %d" % Run.level,
		"Monsters         %d" % Run.kills,
		"",
		"Carried home",
		"  TM             %d" % Run.tm,
		"  Harkon shards  %d" % Run.shards,
		"  Galder         %d" % Run.galder,
		"",
		"Cards  " + (", ".join(cards) if cards.size() else "none"),
	])
	results_panel.visible = true
