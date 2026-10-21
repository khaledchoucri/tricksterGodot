class_name CardData
extends Resource
## A skill card offered as a boon during a run. Skills are active moves that
## go in a skill slot; talents are passive effects that trigger on their own.
## The Power line's cards are generated from the original skill tables by
## tools/power_skills.py (their numbers live in `table`).

enum Kind { TALENT, SKILL }

@export var id: StringName
@export var display_name := ""
@export var kind := Kind.TALENT
## Row ID of the original skill in SkillParam2 (also names its icon).
@export var skill_id := 0
## Skills: damage (or the main number) at level 1, and its growth per level.
## Talents: the effect's value. Used when `table` has no "value" row.
@export var base_value := 0.0
@export var per_level := 0.0
## Description; "{v}" is replaced by the value at the shown level, and
## "{name}" by table row `name` at that level.
@export_multiline var text := ""
## Prerequisites from the original skill tree: card id -> level needed.
@export var requires: Dictionary = {}
## The skill this one is an advanced form of (Gale Strike -> Tempest Strike).
## It's only offered while that skill is known, and learning it replaces it.
@export var upgrades: StringName
## Jobs that may learn it (the original's Job field); empty: anyone whose
## jobs include the tree it's in. A Priest can't learn dark magic.
@export var jobs: Array[StringName] = []
## Cards that can't be held together with this one (the Seals and Pacts:
## Seal of Water shuts out Seal of Fire and Seal of Earth).
@export var excludes: Array[StringName] = []
## The original's sounds: "ap" (cast), "ht" (hit), "fl" (flight), "ke" (lasting).
@export var sounds: Dictionary = {}
## The original's particle effects (cake.xml names) by the same phases, plus
## "ed" (when it ends). Played through Cake.
@export var effects: Dictionary = {}
## Highest level without mastery; 0 for the usual cap. Skills the original
## caps at level 1 (Dash, Faint...) have 1 and can't be mastered.
@export var max_level := 0
## Numbers by level (index 0 is level 1): row name -> values. "value" is the
## main number, "mp" the MP cost, "cooldown" in seconds; other rows (range,
## targets, seconds...) are read by the skill or talent through param().
@export var table: Dictionary = {}
## Monster material Master Louis takes to raise this card's level cap.
@export var master_material: MaterialData
## What the card adds to Run.mod() while held: a Mod key -> "value" (its value at its level)
## or the name of one of its table rows. Written by the generators from each card's SPEC.
@export var mods: Dictionary[String, String] = {}
## What kind of card this is, for the rules that apply to a family of cards:
##  - gun: needs a gun; needs_load: also needs it loaded (the basic shot)
##  - thrown: a thrown weapon (Precise Pitch's thrown_damage%)
##  - grows_gun: a gun talent, offered like the cards that build on a gunner's basic
##  - retaliate: strikes back at a monster that hits you (the elemental Blessings)
@export var tags: Array[StringName] = []
## The beast form this skill needs: a form card's id (Evolution, Metamorphosis), "beast"
## for either, or empty for any shape (and then it doesn't work in a beast).
@export var form: StringName
## On a form card (Evolution, Metamorphosis): the beast body learning it turns you into.
@export var form_actor := ""
## The debuff your hits carry while this talent is held (an Enemy.debuffs key): its
## value for `seconds` (its table row) when it has one, else for its value in seconds.
@export var inflicts := ""

@export_group("Skill")
@export var mp_cost := 0
@export var cooldown := 0.0
## The original element names (the monster tables' resistances use them).
@export_enum("none", "Fire", "Water", "Wind", "Earth", "Elec", "Light", "Dark") var element := "none"
## Stat the damage scales with: AP for weapon skills, MA for magic.
@export_enum("AP", "MA", "DA", "DP") var scaling := "AP"
## Script extending Skill that performs it.
@export var behavior: Script


func has_tag(tag: StringName) -> bool:
	return tag in tags


func is_skill() -> bool:
	return kind == Kind.SKILL


## Table row `name` at `level` (the last entry past the end), or `default`.
func param(name: String, level: int, default := 0.0) -> float:
	var row: Array = table.get(name, [])
	if row.is_empty() or level <= 0:
		return default
	return float(row[mini(level, row.size()) - 1])


## What this card adds to Run.mod(`key`) at `level`: its value, or the table row its `mods`
## names; 0 when it adds nothing to that key.
func mod_at(key: String, level: int) -> float:
	var source: String = mods.get(key, "")
	if source == "":
		return 0.0
	return value_at(level) if source == "value" else param(source, level)


func value_at(level: int) -> float:
	if level <= 0:
		return 0.0
	if table.has("value"):
		return param("value", level)
	return base_value + per_level * (level - 1)


## Seconds a spell takes to cast before its effect (half the original's).
func cast_at(level: int) -> float:
	return param("cast", level)


## Plays one of the original's sounds ("ap", "ht", "fl", "ke"), if it has it.
func play(which: String, volume := -4.0) -> void:
	if sounds.has(which):
		Audio.play(String(sounds[which]), volume)


func mp_at(level: int) -> int:
	return roundi(param("mp", level, mp_cost))


## The original's cooldown at this level when the table has one; otherwise
## the card's cooldown shrinking 6% per level after the first.
func cooldown_at(level: int) -> float:
	if table.has("cooldown"):
		return param("cooldown", level)
	return cooldown * pow(0.94, maxi(level - 1, 0))


func describe(level: int) -> String:
	var out := text.replace("{v}", _num(value_at(level)))
	for row: String in table:
		out = out.replace("{%s}" % row, _num(param(row, level)))
	if is_skill():
		out += "  ·  %d MP, %ss" % [mp_at(level), str(snappedf(cooldown_at(level), 0.1))]
	return out


func _num(v: float) -> String:
	return str(snappedf(v, 0.01)).trim_suffix(".0")
