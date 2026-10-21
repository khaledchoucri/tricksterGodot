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
## Other percentages:
##  - damage%: all your damage (Berserker's rage)
##  - attack_speed%: attacks and combos faster (Hyper Beat, Aura of Haste)
##  - cooldown_cut%, mp_cost_cut%: skills recover sooner, cost less MP
##  - damage_cut%, magic_damage_cut%: less damage taken (all, or magic only)
##  - reload_speed%: the gun's reload fills faster
##  - power_shot%: more damage on an overcharged shot
##  - gun_AP%: the gun's own Gun AP
##  - compound%: compounding succeeds more often
const PERCENT: Array[String] = ["damage%", "attack_speed%", "cooldown_cut%", "mp_cost_cut%", "damage_cut%",
	"magic_damage_cut%", "reload_speed%", "power_shot%", "gun_AP%", "compound%"]
## Other flat amounts: gun_AP, Gun AP added to every shot.
const FLAT: Array[String] = ["gun_AP"]
## The elements with their own keys: "resist:<element>" (resistance, %) and
## "boost:<element>%" (your spells of that element).
const ELEMENTS: Array[String] = ["Fire", "Water", "Wind", "Earth", "Elec", "Light", "Dark"]


## Whether `key` is one of the keys above.
static func is_key(key: String) -> bool:
	if key in STAT_PERCENT or key in STAT_FLAT or key in PERCENT or key in FLAT:
		return true
	if key.begins_with("resist:"):
		return key.trim_prefix("resist:") in ELEMENTS
	if key.begins_with("boost:") and key.ends_with("%"):
		return key.trim_prefix("boost:").trim_suffix("%") in ELEMENTS
	return false
