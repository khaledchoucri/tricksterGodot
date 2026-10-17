class_name CardData
extends Resource
## A skill card offered as a boon during a run. Skills are active moves that
## go in a skill slot; talents are passive effects that trigger on their own.

enum Kind { TALENT, SKILL }

@export var id: StringName
@export var display_name := ""
@export var kind := Kind.TALENT
## Row ID of the original skill in SkillParam2 (also names its icon).
@export var skill_id := 0
## Skills: damage (or the main number) at level 1, and its growth per level.
## Talents: the effect's value.
@export var base_value := 0.0
@export var per_level := 0.0
## Description; "{v}" is replaced by the value at the shown level.
@export_multiline var text := ""
## Prerequisites from the original skill tree: card id -> level needed.
@export var requires: Dictionary = {}
## Monster material Master Louis takes to raise this card's level cap.
@export var master_material: MaterialData

@export_group("Skill")
@export var mp_cost := 0
@export var cooldown := 0.0
@export_enum("none", "fire", "water", "wind", "earth", "lightning") var element := "none"
## Stat the damage scales with: AP for weapon skills, MA for magic.
@export_enum("AP", "MA", "DA", "DP") var scaling := "AP"
## Script extending Skill that performs it.
@export var behavior: Script


func is_skill() -> bool:
	return kind == Kind.SKILL


func value_at(level: int) -> float:
	return 0.0 if level <= 0 else base_value + per_level * (level - 1)


## Cooldown shrinks 6% per level after the first.
func cooldown_at(level: int) -> float:
	return cooldown * pow(0.94, maxi(level - 1, 0))


func describe(level: int) -> String:
	var out := text.replace("{v}", str(snappedf(value_at(level), 0.01)).trim_suffix(".0"))
	if is_skill():
		out += "  ·  %d MP, %ss" % [mp_cost, str(snappedf(cooldown_at(level), 0.1))]
	return out
