extends SmokeSection
## Effective borrowed/owned levels use the stronger source, without modifying ownership.

## Operates on a private deck; take_rune's synthetic card belongs to no Echo.
func run() -> void:
	var rng_seed: int = Run.rng.seed
	var rng_state: int = Run.rng.state
	var deck := RunDeck.new()
	var card := CardData.new()
	card.id = &"fixture_rune"
	card.kind = CardData.Kind.SKILL
	card.base_value = 10.0
	card.per_level = 10.0
	deck.registry[card.id] = card
	for owned: int in [0, 3, 5]:
		deck.cards = {card.id: owned} if owned > 0 else {}
		for borrowed: int in [1, 3, 5]:
			deck.rune = card
			deck.rune_level = borrowed
			check(deck.card_level(card.id) == maxi(owned, borrowed),
				"owned %d and rune %d use the higher effective level" % [owned, borrowed])
	deck.cards[card.id] = 5
	deck.take_rune(card)
	check(deck.card_level(card.id) >= 5 and deck.cards[card.id] == 5,
		"taking a rune cannot downgrade or rewrite a learned skill")
	deck.rune_level = 1
	check(deck.card_value(card.id) == 50.0 and deck.known_level(card.id) == 5,
		"value and prerequisite-level consumers retain the stronger learned level")
	check(deck.held_cards() == [card], "the same skill is counted once across owned and rune sources")
	deck.rune = null
	check(deck.card_level(card.id) == 5, "losing the borrowed source retains the owned level")
	deck.cards.clear()
	deck.rune = card
	deck.rune_level = 3
	check(deck.card_level(card.id) == 3 and deck.card_level(&"unheld") == 0,
		"borrowed-only and unrelated unknown skills keep their usual levels")
	deck.rune = null
	check(deck.card_level(card.id) == 0, "losing a borrowed-only skill leaves no permanent learned copy")
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state
