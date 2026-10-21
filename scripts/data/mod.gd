class_name Mod
## The keys a card can add to through its `mods`, summed by Run.mod(key) over everything the
## player holds. Code asks for a key, never for the cards behind it (CLAUDE.md, section 2).
## A key ending in "%" is a percentage on a multiplier; a bare key is a flat amount. Every
## card's keys are checked when the run loads its cards, so a typo fails loudly.

## Stat buffs, always on (Trickster's are timed casts): the stat is multiplied by
## 1 + mod / 100.
const STAT_PERCENT: Array[String] = ["AP%", "AC%", "MA%", "DA%", "LK%", "HV%", "DP%", "MD%"]
## Flat stat additions (Physical Training's HP, Bottle of Mana's MP, Heavy Carrier's weight).
const STAT_FLAT: Array[String] = ["HP", "MP", "WT"]


## Whether `key` is one of the keys above.
static func is_key(key: String) -> bool:
	return key in STAT_PERCENT or key in STAT_FLAT
