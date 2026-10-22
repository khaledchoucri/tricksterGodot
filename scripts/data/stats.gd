class_name Stats
extends RefCounted
## Trickster's twelve stats in four types (Power, Magic, Sense, Charm), what
## a type point gives, and the traits unlocked by investing in a type.
## Players pick types on level-up; gear and monsters work on the stats.

const KEYS: Array[String] = ["AP", "AC", "DX", "MP", "MA", "MD", "WT", "DA", "LK", "HP", "DP", "HV"]

const NAMES := {
	"AP": "Attack Power", "AC": "Accuracy", "DX": "Dexterity",
	"MP": "Mana", "MA": "Magic Power", "MD": "Magic Defense",
	"WT": "Weight", "DA": "Detect Ability", "LK": "Luck",
	"HP": "Health", "DP": "Defense Power", "HV": "Hit Evasion",
}

## What each stat does in this game (shown on the character sheet).
const USES := {
	"AP": "physical damage", "AC": "hits evasive foes cleanly", "DX": "attack speed",
	"MP": "max mana", "MA": "skill cooldowns", "MD": "less magic damage",
	"WT": "how much you carry (materials, ore, gear out of a fall)", "DA": "better drops, more ore", "LK": "critical hits, refining",
	"HP": "max health", "DP": "less physical damage", "HV": "evade attacks",
}

const TYPE_ORDER: Array[String] = ["power", "magic", "sense", "charm"]

const TYPES := {
	"power": {"name": "Power", "color": Color("e0675e"), "gain": {"AP": 4, "AC": 2, "DX": 2},
		"text": "Hit harder and faster."},
	"magic": {"name": "Magic", "color": Color("6f8ff0"), "gain": {"MP": 12, "MA": 3, "MD": 3},
		"text": "More mana, faster skills."},
	"sense": {"name": "Sense", "color": Color("5fc28c"), "gain": {"WT": 40, "DA": 2, "LK": 2},
		"text": "Better loot, crits and refining."},
	"charm": {"name": "Charm", "color": Color("e5b94a"), "gain": {"HP": 14, "DP": 3, "HV": 2},
		"text": "Survive, evade, outlast."},
}

## Chosen points needed for each trait of a type.
const THRESHOLDS: Array[int] = [3, 6, 10]

const TRAITS := {
	"power": [
		{"id": &"staggering_finish", "name": "Staggering Finish", "text": "Combo finishers stun for 0.35 s."},
		{"id": &"extra_swing", "name": "Extra Swing", "text": "Your combo gains another swing."},
		{"id": &"armor_crush", "name": "Armor Crush", "text": "Finishers expose enemies: +25% damage taken for 4 s."},
	],
	"magic": [
		{"id": &"mana_flow", "name": "Mana Flow", "text": "Hits restore 3 more MP.", "mods": {"hit_mp": 3.0}},
		{"id": &"dash_casting", "name": "Dash Casting", "text": "Cast skills in the middle of a dash."},
		{"id": &"overcast", "name": "Overcast", "text": "Short on MP, pay the rest with HP (2 HP per MP)."},
	],
	"sense": [
		{"id": &"treasure_sense", "name": "Treasure Sense", "text": "Gear rewards offer a choice of two.", "mods": {"gear_choices": 1.0}},
		{"id": &"smiths_eye", "name": "Smith's Eye", "text": "Refining succeeds 10% more often.", "mods": {"refine_chance": 0.1}},
		{"id": &"lucky_strikes", "name": "Lucky Strikes", "text": "Critical hits can knock loose Bronze Fragments."},
	],
	"charm": [
		{"id": &"light_feet", "name": "Light Feet", "text": "+8% chance to evade attacks.", "mods": {"evade": 0.08}},
		{"id": &"perfect_dodge", "name": "Perfect Dodge", "text": "Dashing through an attack resets your dash."},
		{"id": &"second_wind", "name": "Second Wind", "text": "Once per run, a fatal blow leaves you at 30% HP."},
	],
}


## The trait a type unlocks at its n-th threshold (0-based), or {}.
static func trait_at(type: String, n: int) -> Dictionary:
	var list: Array = TRAITS[type]
	return list[n] if n < list.size() else {}


## The next trait a type would unlock with `points` chosen, and how many it needs.
static func next_trait(type: String, points: int) -> Dictionary:
	for i in THRESHOLDS.size():
		if points < THRESHOLDS[i]:
			var t := trait_at(type, i)
			return {"trait": t, "at": THRESHOLDS[i]} if not t.is_empty() else {}
	return {}


static func gain_text(type: String) -> String:
	var parts: PackedStringArray = []
	var gain: Dictionary = TYPES[type].gain
	for k: String in gain:
		parts.append("+%d %s" % [gain[k], k])
	return "  ".join(parts)


## Monster rows (MonsterParamEx2) name some stats MAXHP / MAXMP / MAXWT.
static func from_monster(row: Dictionary) -> Dictionary:
	var out := {}
	for k in KEYS:
		var src: String = {"HP": "MAXHP", "MP": "MAXMP", "WT": "MAXWT"}.get(k, k)
		out[k] = int(row.get(src, 0))
	return out
