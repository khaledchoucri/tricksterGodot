class_name Hud
extends CanvasLayer
## On-screen interface (scenes/hud.tscn): status and MP, skill slots, room
## progress, boss bar, the MMO-style system log, the pick-one panel (cards,
## level-ups, slot swaps) and the results screen. Layout and styling live in
## the scene and ui/hud_theme.tres; this script fills in the values.

signal picked(index: int)
signal restart_requested

const MUTED := Color(1, 1, 1, 0.6)
const SLOT_KEYS: Array[String] = ["RMB", "Q", "E", "F"]
const PICK_OPTION := preload("res://scenes/ui/pick_option.tscn")
const LOG_LINES := 6

@onready var pick_panel: PanelContainer = %PickPanel
@onready var results_panel: PanelContainer = %ResultsPanel
@onready var sheet: CharacterSheet = %CharacterSheet
@onready var drill: DrillPanel = %DrillPanel
@onready var _slots: Array[SkillSlot] = [$Root/SlotBar/Slot1, $Root/SlotBar/Slot2, $Root/SlotBar/Slot3, $Root/SlotBar/Slot4]

var _pick_count := 0
## Option buttons in option order (list and footer), the cancel option's
## index (-1 if none), and which option each number key picks.
var _pick_buttons: Array[PickOption] = []
var _pick_cancel := -1
var _pick_keys: Array[int] = []
var _hub_mode := false


func _ready() -> void:
	(%AgainButton as Button).pressed.connect(func() -> void: restart_requested.emit())
	Events.skill_cast.connect(func(slot: int) -> void:
		if slot < _slots.size():  # the basic spell (slot 4) has no box
			_slots[slot].pulse())
	Events.mp_short.connect(func() -> void:
		_flash(%MpBar, Color(1.8, 0.6, 0.6))
		Audio.play("etc_miss.wav", -10.0))


# ---------------------------------------------------------------- updates

## In the city: no combat status or skill slots; shows banked progress.
func set_hub_mode(on: bool) -> void:
	_hub_mode = on
	$Root/Status.visible = not on
	%SlotBar.visible = not on
	%CardsLabel.visible = not on
	sheet.visible = false
	_update_hint()


## The controls line; a mage's left click casts their basic spell.
func _update_hint() -> void:
	var basic := "LMB %s" % Run.cls.basic_skill.display_name if Run.cls and Run.cls.basic_skill else "LMB combo"
	var text := "WASD move  ·  F talk  ·  Space dash" if _hub_mode 		else "WASD move  ·  %s  ·  RMB / Q / E skills  ·  Space dash  ·  C character" % basic
	if $Root/Hint.text != text:
		$Root/Hint.text = text


func refresh(player: Player) -> void:
	_update_hint()
	if _hub_mode:
		%GalderLabel.text = "%d TM  ·  %d Harkon Shard%s  ·  %d Galder  ·  %d Bronze" % [Profile.tm, Profile.shards,
			"" if Profile.shards == 1 else "s", Profile.galder, Profile.ore]
		return
	var hp: ProgressBar = %HpBar
	hp.max_value = Run.max_hp
	hp.value = Run.hp
	%HpLabel.text = "HP %d / %d" % [Run.hp, Run.max_hp]
	var xp: ProgressBar = %XpBar
	xp.max_value = Run.exp_to_next()
	xp.value = Run.xp
	%LevelLabel.text = "Lv %d  %s" % [Run.level, Run.job.display_name]
	$Root/Status/Title.text = "%s  ·  %s" % [Run.cls.display_name, Stats.TYPES[_main_type()].name]
	var mp: ProgressBar = %MpBar
	mp.max_value = Run.max_mp
	mp.value = Run.mp
	%MpLabel.text = "MP %d / %d" % [Run.mp, Run.max_mp]
	%GalderLabel.text = "%d Galder  ·  %d Bronze" % [Run.purse.galder, Run.purse.ore]
	var owned: PackedStringArray = []
	for id: StringName in Run.cards:
		owned.append("%s %d" % [Run.card(id).display_name, Run.cards[id]])
	%CardsLabel.text = _pack(owned, %CardsLabel)
	_refresh_slots(player)
	if sheet.visible:
		sheet.refresh()
	if is_instance_valid(player):
		%DashLabel.text = "Dash  [Space]  " + ("ready" if player.can_dash() else "...")


## The type the class grows in most (Power for Buffalo and Bunny).
func _main_type() -> String:
	var best := "power"
	for t: String in Stats.TYPE_ORDER:
		if float(Run.cls.graph.get(t, 0.0)) > float(Run.cls.graph.get(best, 0.0)):
			best = t
	return best


func _refresh_slots(player: Player) -> void:
	_slots[3].visible = Run.rune != null
	for i in _slots.size():
		var id: StringName = Run.loadout[i] if i < Run.loadout.size() else (Run.rune.id if Run.rune else &"")
		if id == &"":
			_slots[i].clear()
			continue
		var card := Run.card(id)
		var level := Run.card_level(id)
		var left := 0.0
		if is_instance_valid(player):
			left = maxf(0.0, player.skills.slot_ready_at[i] - player.now())
		_slots[i].show_skill(card, level, left, card.cooldown_at(level) * Run.skill_cooldown_mult(), Run.mp >= card.mp_at(level),
			not Run.form_allows(id))


func _flash(node: CanvasItem, color: Color) -> void:
	node.modulate = color
	node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.25)


## Hides the system log (behind the dialogue box, for example).
func set_log_visible(on: bool) -> void:
	%LogBox.visible = on


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
	# Keep clear of the centred skill bar on narrow screens.
	var room := (get_viewport().get_visible_rect().size.x - (%SlotBar as Control).size.x) / 2.0 - 36.0
	box.size.x = clampf(room, 220.0, 460.0)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
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

## options: Array of {"title", "tag", "text"} with optional "icon" (Texture2D),
## "disabled" and "cancel". Cancel options (leave, back, keep) are pinned
## under the scrolling list and also picked with Esc; the others get number
## keys 1-9 and 0.
func show_pick(title: String, options: Array) -> void:
	var list: VBoxContainer = %PickList
	var footer: VBoxContainer = %PickFooter
	for box: Control in [list, footer]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	%PickTitle.text = title
	_pick_count = options.size()
	_pick_buttons.clear()
	_pick_keys.clear()
	_pick_cancel = -1
	for i in options.size():
		var o: Dictionary = options[i]
		var cancel: bool = o.get("cancel", false) and _pick_cancel < 0
		var option: PickOption = PICK_OPTION.instantiate()
		(footer if cancel else list).add_child(option)
		var key := "Esc" if cancel else ("" if _pick_keys.size() >= 10 else str((_pick_keys.size() + 1) % 10))
		if cancel:
			_pick_cancel = i
		elif _pick_keys.size() < 10:
			_pick_keys.append(i)
		option.setup(key, o.title, o.get("tag", ""), o.text, o.get("icon"))
		option.disabled = o.get("disabled", false)
		option.pressed.connect(_on_pick.bind(i))
		_pick_buttons.append(option)
	footer.visible = footer.get_child_count() > 0
	pick_panel.visible = true
	_fit_pick_panel()
	await get_tree().process_frame
	_fit_pick_panel()
	(%PickScroll as ScrollContainer).scroll_vertical = 0
	for b in _pick_buttons:
		if not b.disabled and b.get_parent() == list:
			b.grab_focus()
			return
	if _pick_cancel >= 0:
		_pick_buttons[_pick_cancel].grab_focus()


## Caps the list's height so the title and the pinned footer stay on screen.
func _fit_pick_panel() -> void:
	var view := get_viewport().get_visible_rect().size.y
	var used: float = (%PickTitle as Control).get_combined_minimum_size().y + 40.0
	if (%PickFooter as Control).visible:
		used += (%PickFooter as Control).get_combined_minimum_size().y + 10.0
	var room := maxf(140.0, view - 120.0 - used)
	var scroll: ScrollContainer = %PickScroll
	scroll.custom_minimum_size.y = minf((%PickList as Control).get_combined_minimum_size().y, room)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pick_panel.reset_size()
	pick_panel.position = (get_viewport().get_visible_rect().size - pick_panel.size) / 2.0


## True when option `i` can be seen and clicked: its button lies inside the
## screen and, for list options, inside the scroll area (the playtest bot
## only presses buttons a player could press).
func pick_reachable(i: int) -> bool:
	if i < 0 or i >= _pick_buttons.size():
		return false
	var b := _pick_buttons[i]
	var screen := get_viewport().get_visible_rect()
	if not screen.encloses(b.get_global_rect()) and b.get_parent() == %PickFooter:
		return false
	if not screen.encloses((%PickScroll as Control).get_global_rect()):
		return false
	return screen.encloses(pick_panel.get_global_rect())


func _on_pick(i: int) -> void:
	if not pick_panel.visible:
		return
	if i >= 0 and i < _pick_buttons.size() and _pick_buttons[i].disabled:
		return
	pick_panel.visible = false
	picked.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if not _hub_mode and event.is_action_pressed("character"):
		sheet.toggle()
	if pick_panel.visible and event.is_action_pressed("ui_cancel") and _pick_cancel >= 0:
		get_viewport().set_input_as_handled()
		_on_pick(_pick_cancel)
	elif pick_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		var n: int = 9 if event.keycode == KEY_0 else event.keycode - KEY_1
		if n >= 0 and n < _pick_keys.size():
			_on_pick(_pick_keys[n])
	if results_panel.visible and event.is_action_pressed("restart"):
		restart_requested.emit()


## Joins entries with dots, breaking lines only between whole entries.
func _pack(entries: PackedStringArray, label: Label) -> String:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var width := maxf(label.size.x, 200.0)
	var lines: PackedStringArray = []
	var line := ""
	for e in entries:
		var next := e if line == "" else line + "  ·  " + e
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines.append(line)
			line = e
		else:
			line = next
	if line != "":
		lines.append(line)
	return "
".join(lines)


func show_results(won: bool) -> void:
	var title: Label = %ResultsTitle
	title.text = "%s cleared" % Run.route.region.display_name if won else "Rollback"
	title.add_theme_color_override("font_color", Color("e0b54d") if won else Color("f07a62"))
	var cards: PackedStringArray = []
	for id: StringName in Run.cards:
		cards.append("%s Lv %d" % [Run.card(id).display_name, Run.cards[id]])
	var gear: PackedStringArray = []
	for k in Run.EQUIP_SLOTS:
		if Run.equipped(k):
			gear.append(Run.equipped(k).title())
	var rows := [["Rooms cleared", "%d / %d" % [Run.route.depth + (1 if won else 0), Run.route.plan.size()]],
		["Time", "%d:%04.1f" % [int(Run.time) / 60, fmod(Run.time, 60.0)]],
		["Level", "%d  %s" % [Run.level, Run.job.display_name]],
		["Monsters", str(Run.kills)],
		["TM carried home", str(Run.purse.tm)], ["Harkon Shards", str(Run.purse.shards)], ["Galder", str(Run.purse.galder)]]
	var t := "[table=2]"
	for r: Array in rows:
		t += "[cell][color=#9fb2c0]%s[/color]     [/cell][cell]%s[/cell]" % r
	t += "[/table]\n\n[color=#9fb2c0]Cards[/color]  %s\n[color=#9fb2c0]Gear[/color]  %s" % [
		", ".join(cards) if cards.size() else "none", ", ".join(gear) if gear.size() else "none"]
	%ResultsBody.text = t
	pick_panel.visible = false
	var sb := results_panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a < 1.0:
		var solid := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		solid.bg_color.a = 1.0
		results_panel.add_theme_stylebox_override("panel", solid)
	results_panel.visible = true
