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
##  - thrown_damage%: thrown weapons (cards tagged "thrown")
##  - combo_damage%, combo_reach%, finisher_damage%: the basic combo (Chi Sword, Champion's Fury)
##  - mp_regen%: a mage's MP regeneration (Aura of Mana)
##  - skill_damage%: your skills (job passives); elite_damage%: against elites and bosses
##  - move%, dash_distance%, dash_cooldown_cut%: moving and dashing
##  - galder%: Galder from kills; shop_discount%: shop prices
##  - room_heal%, clear_heal%: max HP healed entering a room, clearing one
const PERCENT: Array[String] = ["damage%", "attack_speed%", "cooldown_cut%", "mp_cost_cut%", "damage_cut%",
	"magic_damage_cut%", "reload_speed%", "power_shot%", "gun_AP%", "compound%", "skill_damage%",
	"elite_damage%", "move%", "dash_distance%", "dash_cooldown_cut%", "galder%", "shop_discount%",
	"room_heal%", "clear_heal%", "thrown_damage%", "combo_damage%", "combo_reach%",
	"finisher_damage%", "mp_regen%"]
## Other flat amounts:
##  - gun_AP: Gun AP added to every shot
##  - crit_damage: added to the critical multiplier (1.75)
##  - evade, material_drop, refine_chance: added chances (0-1)
##  - kill_mp, hit_mp: MP restored per kill, per hit
##  - card_choices, gear_choices: more options in those rewards
##  - job_change_points: free type points on every job change
##  - reveal_radius: nothing hides within this distance of you (Revealing Eye)
const FLAT: Array[String] = ["gun_AP", "crit_damage", "evade", "material_drop", "refine_chance", "kill_mp",
	"hit_mp", "card_choices", "gear_choices", "job_change_points", "reveal_radius"]
## The elements with their own keys: "resist:<element>" (resistance, %) and
## "boost:<element>%" (your spells of that element).
const ELEMENTS: Array[String] = ["Fire", "Water", "Wind", "Earth", "Elec", "Light", "Dark"]


## What a supplement adds to one skill (or a family: "pouch", an element), keyed
## "<skill id>.<effect>": Faint's "shockwave.stun_chance". The skill's own script reads it
## with Skill.skill_mod(effect), so no skill names another card.
const SKILL_EFFECTS: Array[String] = ["stun_chance", "stun_seconds", "guard_chance", "guard_seconds",
	"counter_chance", "counter_damage", "ratio", "cards_min", "cards_max", "arrows", "extra_share", "power",
	"poison", "poison_seconds", "commando_damage", "dx_down", "dx_seconds", "stun", "burn%", "burn_seconds",
	"fear_chance", "fear_seconds"]


## Whether `key` is one of the keys above.
static func is_key(key: String) -> bool:
	if "." in key:
		return key.get_slice(".", 1) in SKILL_EFFECTS
	if key in STAT_PERCENT or key in STAT_FLAT or key in PERCENT or key in FLAT:
		return true
	if key.begins_with("resist:"):
		return key.trim_prefix("resist:") in ELEMENTS
	if key.begins_with("boost:") and key.ends_with("%"):
		return key.trim_prefix("boost:").trim_suffix("%") in ELEMENTS
	return false
