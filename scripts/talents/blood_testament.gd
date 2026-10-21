extends Talent
## Blood Testament (2219): spells cost its HP row (% of max HP) as well, never fatal (its MA
## is a mod).


func on_cast(skill: CardData, lvl: int, slot: int) -> void:
	if skill.cast_at(lvl) <= 0.0 or slot == SkillCaster.BASIC:
		return
	var hp_cost := roundi(Run.max_hp * row("hp") / 100.0)
	Run.take_damage(mini(hp_cost, Run.hp - 1))
