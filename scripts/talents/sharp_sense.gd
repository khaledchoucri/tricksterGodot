extends Talent
## Sharp Sense (3504) on top of a mastered Keen Sense (the card it requires): the power
## shot's bonus becomes the mastered Keen Sense's, raised by Sharp Sense's value. The card
## text's "gun critical" is the power shot: the server's ESASharpSense sets the factor its
## power-shot formula multiplies (+0x428).


func adjust(what: StringName, amount: float) -> float:
	if what != &"power_shot%":
		return amount
	var keen: CardData = Run.deck.card(card.requires.keys()[0]) if not card.requires.is_empty() else null
	var top: float = keen.value_at(Run.deck.MAX_CARD_LEVEL) if keen else 0.0
	return (100.0 + top) * (1.0 + value() / 100.0) - 100.0
