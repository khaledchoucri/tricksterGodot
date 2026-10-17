class_name CharacterSheet
extends PanelContainer
## The character window (C / Tab): job and level, type points and the
## traits they unlocked, all twelve stats by type, equipment and its load,
## and skill cards. Opens over the game without pausing it.

@onready var _left: RichTextLabel = %Left
@onready var _middle: RichTextLabel = %Middle
@onready var _right: RichTextLabel = %Right


func _ready() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_fit()
		refresh()


## Fits the window: narrower screens get narrower columns, not a cut sheet.
func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var w := minf(1060.0, view.x - 32.0)
	var h := minf(530.0, view.y - 120.0)
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	position = ((view - size) / 2.0).round()


func refresh() -> void:
	_left.text = _header_text() + "
" + _types_text(["power", "magic"])
	_middle.text = _types_text(["sense", "charm"]).trim_prefix("\n") + "\n\n" + _skills_text()
	_right.text = _gear_text()


func _header_text() -> String:
	return "[font_size=18]%s  ·  %s[/font_size]   Lv %d
[color=#9fb2c0]HP %d / %d   MP %d / %d
%d Galder   %d %ss[/color]" % [
		Run.cls.display_name, Run.job.display_name, Run.level, Run.hp, Run.max_hp, Run.mp, Run.max_mp, Run.galder,
		Run.ore, Run.ORE_NAME]


func _types_text(types: Array) -> String:
	var lines: PackedStringArray = []
	for t: String in types:
		var info: Dictionary = Stats.TYPES[t]
		lines.append("")
		lines.append("[color=#%s][b]%s[/b]  %d points[/color]" % [info.color.to_html(false), info.name, Run.type_points[t]])
		for k: String in info.gain:
			lines.append("  %s  [b]%d[/b]   [color=#9fb2c0]%s · %s[/color]" % [k, Run.stat(k), Stats.NAMES[k], Stats.USES[k]])
		for i in Stats.THRESHOLDS.size():
			var tr := Stats.trait_at(t, i)
			if tr.is_empty():
				continue
			var on: bool = Run.type_points[t] >= Stats.THRESHOLDS[i]
			lines.append("  [color=#%s]%s %d · %s[/color]" % ["e8e0c0" if on else "5a6b7c",
				"●" if on else "○", Stats.THRESHOLDS[i], tr.name])
	return "
".join(lines)


func _skills_text() -> String:
	var lines: PackedStringArray = []
	lines.append("[font_size=18]Skills[/font_size]")
	for id: StringName in Run.cards:
		var card := Run.card(id)
		lines.append("  %s  Lv %d%s" % [card.display_name, Run.cards[id], "" if card.is_skill() else "  [color=#9fb2c0](talent)[/color]"])
	for j in Run.jobs:
		if j.passive != &"":
			lines.append("  [color=#e0b54d]%s[/color]  [color=#9fb2c0]%s[/color]" % [j.passive_name, j.passive_text])
		if j.technique != &"":
			lines.append("  [color=#e0b54d]%s[/color]  [color=#9fb2c0]%s[/color]" % [j.technique_name, j.technique_text])
	return "\n".join(lines)


func _gear_text() -> String:
	var lines: PackedStringArray = []
	var over := Run.overweight()
	lines.append("[font_size=18]Equipment[/font_size]   [color=#%s]Load %d / %d%s[/color]" % [
		"f07a62" if over else "9fb2c0", Run.equip_load(), Run.load_limit(), "  overweight" if over else ""])
	for k in Run.EQUIP_SLOTS:
		var g := Run.equipped(k)
		var label: String = {"weapon": "Weapon", "hat": "Hat", "shield": "Shield", "innerwear": "Innerwear",
			"acc1": "Accessory", "acc2": "Accessory"}[k]
		if g:
			lines.append("[color=#9fb2c0]%s[/color]  %s" % [label, g.title()])
			lines.append("    [color=#a8d8da]%s[/color]" % g.summary())
		else:
			lines.append("[color=#5a6b7c]%s  empty[/color]" % label)
	var worn: PackedStringArray = []
	for w in Run.worn_pieces():
		worn.append(w.display_name)
	if worn.size():
		lines.append("[color=#9fb2c0]Wardrobe[/color]  " + ", ".join(worn))
	var el := Run.element_attack()
	if not el.is_empty():
		var parts: PackedStringArray = []
		for k: String in el:
			parts.append("%s %d" % [k, el[k]])
		lines.append("[color=#9fb2c0]Elemental attack[/color]  " + "  ".join(parts))
	var kinds := 0
	var ready: PackedStringArray = []
	for id: StringName in Run.materials:
		if Run.materials[id] > 0:
			kinds += 1
			var m: MaterialData = Run.material_info[id]
			if Run.materials[id] >= m.need:
				ready.append(m.display_name)
	if kinds:
		var shown := ", ".join(ready.slice(0, 3)) + (" +%d more" % (ready.size() - 3) if ready.size() > 3 else "")
		lines.append("[color=#9fb2c0]Materials[/color]  %d kind%s carried%s" % [kinds, "" if kinds == 1 else "s",
			("  ·  ready to compound: " + shown) if ready.size() else ""])
	return "\n".join(lines)
