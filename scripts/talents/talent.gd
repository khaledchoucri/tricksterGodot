class_name Talent
extends RefCounted
## A talent's own behaviour, for what its numbers (its `mods`) can't say: a barrier that
## refills, a block, a heal over time, a second life. A card's `talent` points at a
## subclass; Run keeps one per held card for the run (Run.talents()) and the player and Run
## call these hooks on each, in skill-id order. Every hook does nothing by default.

## The card this talent plays.
var card: CardData


## The card's level now.
func level() -> int:
	return Run.card_level(card.id)


## The card's value at its level.
func value() -> float:
	return card.value_at(level())


## One of the card's table rows at its level.
func row(name: String) -> float:
	return card.param(name, level())


## Every physics frame while held.
func tick(_player: Player, _delta: float) -> void:
	pass


## A hit is about to land (before evasion): true blocks it outright.
func guard(_player: Player, _magic: bool) -> bool:
	return false


## A hit after defence: the damage still to take.
func absorb(_player: Player, amount: int) -> int:
	return amount


## A hit landed on you (after defence): strike back at `attacker`.
func retaliate(_player: Player, _attacker: Enemy, _amount: int, _magic: bool) -> void:
	pass


## A fatal blow: true when this talent saves you (it sets your HP).
func revive() -> bool:
	return false


## Adjusts a number the run computes: &"damage" (your damage multiplier) or &"power_shot%".
func adjust(_what: StringName, amount: float) -> float:
	return amount


## A skill was cast in `slot`, its MP and Galder paid.
func on_cast(_skill: CardData, _level: int, _slot: int) -> void:
	pass
