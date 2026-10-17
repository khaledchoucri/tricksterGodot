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
		refresh()


func refresh() -> void:
	_left.text = _header_text() + "
" + _types_text(["power", "magic"])
	_middle.text = "

" + _types_text(["sense", "charm"])
	_right.text = _gear_text()


func _header_text() -> String:
	return "[font_size=18]%s  ·  %s[/font_size]   Lv %d
[color=#9fb2c0]HP %d / %d   MP %d / %d   %d Galder   %d %ss[/color]" % [
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
	var el := Run.element_attack()
	if not el.is_empty():
		var parts: PackedStringArray = []
		for k: String in el:
			parts.append("%s %d" % [k, el[k]])
		lines.append("[color=#9fb2c0]Elemental attack[/color]  " + "  ".join(parts))
	var mats: PackedStringArray = []
	for id: StringName in Run.materials:
		if Run.materials[id] > 0:
			var m: MaterialData = Run.material_info[id]
			mats.append("%s %d/%d" % [m.display_name, Run.materials[id], m.need])
	if mats.size():
		lines.append("[color=#9fb2c0]Materials[/color]  " + ", ".join(mats))
	lines.append("")
	lines.append("[font_size=18]Skills[/font_size]")
	for id: StringName in Run.cards:
		var card := Run.card(id)
		lines.append("  %s  Lv %d%s" % [card.display_name, Run.cards[id], "" if card.is_skill() else "  [color=#9fb2c0](talent)[/color]"])
	for j in Run.jobs:
		if j.passive != &"":
			lines.append("  [color=#e0b54d]%s[/color]  [color=#9fb2c0]%s[/color]" % [j.passive_name, j.passive_text])
	return "\n".join(lines)
