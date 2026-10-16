class_name Hud
extends CanvasLayer
## On-screen interface: status, room progress, boss bar, the MMO-style system
## log, the pick-one-of-three panel (cards and level-ups) and the results screen.

signal picked(index: int)
signal restart_requested

const INK := Color(0.06, 0.1, 0.13)
const TEXT := Color("f4efe6")
const MUTED := Color(1, 1, 1, 0.6)
const ACCENT := Color("4cc2c4")
const MP_COLOR := Color("4f8fe0")
const SLOT_KEYS: Array[String] = ["RMB", "Q", "E"]
const SLOT_SIZE := 64.0

var hp_bar: ProgressBar
var hp_label: Label
var xp_bar: ProgressBar
var level_label: Label
var mp_bar: ProgressBar
var mp_label: Label
var slots: Array[Dictionary] = []  # per slot: panel, icon, shade, timer, cost, name
var _icons: Dictionary = {}  # skill id -> Texture2D or null
var dash_label: Label
var room_label: Label
var galder_label: Label
var cards_label: Label
var log_box: VBoxContainer
var center_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_name: Label
var overlay: ColorRect
var pick_panel: PanelContainer
var pick_title: Label
var pick_list: VBoxContainer
var results_panel: PanelContainer
var results_body: Label
var results_title: Label
var notice_label: Label

var _pick_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var status := VBoxContainer.new()
	status.position = Vector2(20, 16)
	status.add_theme_constant_override("separation", 3)
	root.add_child(status)
	status.add_child(_label("Buffalo  ·  Power", 15, TEXT))
	hp_bar = _bar(Color("d9573f"), Vector2(240, 14))
	status.add_child(hp_bar)
	hp_label = _label("", 12, TEXT)
	status.add_child(hp_label)
	xp_bar = _bar(Color("e0b54d"), Vector2(240, 6))
	status.add_child(xp_bar)
	level_label = _label("", 12, Color("e0b54d"))
	status.add_child(level_label)
	mp_bar = _bar(MP_COLOR, Vector2(240, 8))
	status.add_child(mp_bar)
	mp_label = _label("", 12, Color("a9c8f0"))
	status.add_child(mp_label)
	dash_label = _label("", 12, Color("a8d8da"))
	status.add_child(dash_label)

	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -320
	right.offset_right = -20
	right.offset_top = 16
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(right)
	room_label = _label("", 16, TEXT)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(room_label)
	galder_label = _label("", 13, Color("e0b54d"))
	galder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(galder_label)
	cards_label = _label("", 12, MUTED)
	cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(cards_label)

	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -220
	boss_box.offset_right = 220
	boss_box.offset_top = 18
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = _label("", 15, Color("e0b54d"))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = _bar(Color("e0b54d"), Vector2(440, 12))
	boss_box.add_child(boss_bar)

	log_box = VBoxContainer.new()
	log_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_box.offset_left = 20
	log_box.offset_top = -160
	log_box.offset_right = 480
	log_box.offset_bottom = -40
	log_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(log_box)

	_build_slots(root)

	var hint := _label("WASD move  ·  LMB sword combo  ·  RMB / Q / E skills  ·  Space dash", 12, Color(1, 1, 1, 0.5))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_right = -20
	hint.offset_top = -32
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	notice_label = _label("", 14, Color("e0b54d"))
	notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notice_label.offset_left = -300
	notice_label.offset_right = 300
	notice_label.offset_top = -150
	notice_label.offset_bottom = -126
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(notice_label)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.09, 0.12, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	center_label = _label("", 30, TEXT)
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(center_label)

	pick_panel = _panel(root, Vector2(560, 0))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	pick_panel.add_child(pv)
	pick_title = _label("", 20, TEXT)
	pick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pick_title)
	pick_list = VBoxContainer.new()
	pick_list.add_theme_constant_override("separation", 8)
	pv.add_child(pick_list)

	results_panel = _panel(root, Vector2(460, 0))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	results_panel.add_child(rv)
	results_title = _label("", 24, TEXT)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(results_title)
	results_body = _label("", 14, TEXT)
	rv.add_child(results_body)
	var again := Button.new()
	again.text = "Log in again  [R]"
	again.custom_minimum_size = Vector2(0, 40)
	again.pressed.connect(func(): restart_requested.emit())
	rv.add_child(again)


func _build_slots(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -130
	bar.offset_right = 130
	bar.offset_top = -112
	bar.offset_bottom = -26
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	for i in SLOT_KEYS.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(column)
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(INK, 0.8)
		sb.border_color = Color(ACCENT, 0.7)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", sb)
		column.add_child(panel)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8
		icon.offset_top = 8
		icon.offset_right = -8
		icon.offset_bottom = -8
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.04, 0.06, 0.7)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(shade)
		var timer := _label("", 18, TEXT)
		timer.set_anchors_preset(Control.PRESET_FULL_RECT)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(timer)
		var key := _label(SLOT_KEYS[i], 11, Color("e0b54d"))
		key.position = Vector2(4, 1)
		panel.add_child(key)
		var cost := _label("", 11, Color("a9c8f0"))
		cost.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cost.offset_left = -30
		cost.offset_top = -17
		cost.offset_right = -4
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(cost)
		var label := _label("", 11, TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(SLOT_SIZE + 14, 0)
		column.add_child(label)
		slots.append({"panel": panel, "icon": icon, "shade": shade, "timer": timer, "cost": cost, "name": label})
	Events.skill_cast.connect(func(slot: int) -> void: _pulse(slots[slot].panel, Color(1.6, 1.6, 1.6)))
	Events.mp_short.connect(func() -> void:
		_pulse(mp_bar, Color(1.8, 0.6, 0.6))
		Audio.play("etc_miss.wav", -10.0))


func _pulse(node: CanvasItem, color: Color) -> void:
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)


func _icon(card: CardData) -> Texture2D:
	if not _icons.has(card.id):
		var path := "res://original_assets/icons/%d.png" % card.skill_id
		_icons[card.id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[card.id]


func _refresh_slots(player: Player) -> void:
	var t := player.now() if is_instance_valid(player) else 0.0
	for i in slots.size():
		var ui: Dictionary = slots[i]
		var id: StringName = Run.loadout[i]
		var panel: Panel = ui.panel
		var shade: ColorRect = ui.shade
		if id == &"":
			(ui.icon as TextureRect).texture = null
			(ui.name as Label).text = ""
			(ui.cost as Label).text = ""
			(ui.timer as Label).text = ""
			shade.position = Vector2.ZERO
			shade.size = panel.size
			continue
		var card := Run.region.card(id)
		var level := Run.card_level(id)
		(ui.icon as TextureRect).texture = _icon(card)
		(ui.name as Label).text = "%s %d" % [card.display_name, level]
		(ui.cost as Label).text = str(card.mp_cost)
		var left := 0.0
		var total := card.cooldown_at(level) * Run.skill_cooldown_mult()
		if is_instance_valid(player):
			left = maxf(0.0, player.slot_ready_at[i] - t)
		var frac := clampf(left / maxf(total, 0.01), 0.0, 1.0)
		shade.size = Vector2(panel.size.x, panel.size.y * frac)
		shade.position = Vector2(0, panel.size.y - shade.size.y)
		(ui.timer as Label).text = "%.1f" % left if left > 0.0 else ""
		# Not enough MP: dim the slot.
		(ui.icon as TextureRect).modulate = Color(1, 1, 1) if Run.mp >= card.mp_cost else Color(0.45, 0.5, 0.75)


func _panel(root: Control, min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.12, 0.16, 0.95)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	root.add_child(p)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _bar(color: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.85)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


# ---------------------------------------------------------------- updates

func refresh(player: Player) -> void:
	hp_bar.max_value = Run.max_hp
	hp_bar.value = Run.hp
	hp_label.text = "HP %d / %d" % [Run.hp, Run.max_hp]
	xp_bar.max_value = Run.exp_to_next()
	xp_bar.value = Run.xp
	level_label.text = "Lv %d" % Run.level
	galder_label.text = "%d Galder" % Run.galder
	var owned: PackedStringArray = []
	for id: StringName in Run.cards:
		owned.append("%s %d" % [Run.region.card(id).display_name, Run.cards[id]])
	cards_label.text = "  ·  ".join(owned)
	mp_bar.max_value = Run.MAX_MP
	mp_bar.value = Run.mp
	mp_label.text = "MP %d / %d" % [Run.mp, Run.MAX_MP]
	_refresh_slots(player)
	if is_instance_valid(player):
		var t := player.now()
		dash_label.text = "Dash  [Space]  " + ("ready" if t >= player.dash_ready_at else "...")


func set_room(text: String) -> void:
	room_label.text = text


func show_boss(enemy_name: String, hp: int, max_hp: int) -> void:
	boss_box.visible = true
	boss_name.text = enemy_name
	boss_bar.max_value = max_hp
	boss_bar.value = hp


func hide_boss() -> void:
	boss_box.visible = false


func log_line(text: String, color := MUTED) -> void:
	var l := _label(text, 13, color)
	log_box.add_child(l)
	while log_box.get_child_count() > 6:
		log_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)


func center(text: String, hold := 0.0) -> void:
	center_label.text = text
	center_label.modulate.a = 1.0
	if hold > 0.0:
		var tw := center_label.create_tween()
		tw.tween_interval(hold)
		tw.tween_property(center_label, "modulate:a", 0.0, 0.4)


func notice(text: String) -> void:
	notice_label.text = text
	notice_label.modulate.a = 1.0
	var tw := notice_label.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(notice_label, "modulate:a", 0.0, 0.5)


func fade(to_alpha: float, time := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", to_alpha, time)
	await tw.finished


# ---------------------------------------------------------------- pickers

## options: Array of {"title": String, "tag": String, "text": String}
func show_pick(title: String, options: Array) -> void:
	for c in pick_list.get_children():
		c.queue_free()
	pick_title.text = title
	_pick_count = options.size()
	for i in options.size():
		var o: Dictionary = options[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 64)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_pick.bind(i))
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 14
		box.offset_top = 8
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := _label("%d.  %s   %s" % [i + 1, o.title, o.get("tag", "")], 16, TEXT)
		box.add_child(head)
		var body := _label(o.text, 13, Color("a8d8da"))
		box.add_child(body)
		b.add_child(box)
		pick_list.add_child(b)
	pick_panel.visible = true
	await get_tree().process_frame
	if pick_list.get_child_count() > 0:
		(pick_list.get_child(0) as Button).grab_focus()


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
	results_title.text = "Coral Beach cleared" if won else "Rollback"
	results_title.add_theme_color_override("font_color", Color("e0b54d") if won else Color("f07a62"))
	var cards: PackedStringArray = []
	for id: StringName in Run.cards:
		cards.append("%s Lv %d" % [Run.region.card(id).display_name, Run.cards[id]])
	results_body.text = "\n".join([
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
