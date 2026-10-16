class_name GearItem
extends RefCounted
## One rolled piece of gear: an ItemData, maybe a Trickster prefix
## ("Sharp Wood Sword"), its stats rolled around the base values, and its
## refine level.

## Prefixes from the original item variants (Sharp. Wood Sword, Shrd. Wood
## Sword, Sen. Bronze Sword, Solid / Clever Wood Helmet, Spell Wood Buckler...).
## "scale" multiplies a base stat, "add" adds a rolled [min, max].
const PREFIXES := {
	"sharp": {"name": "Sharp", "slots": [ItemData.Slot.WEAPON], "scale": {"AP": 0.3}},
	"shrewd": {"name": "Shrewd", "slots": [ItemData.Slot.WEAPON, ItemData.Slot.HAT], "add": {"AC": [2, 4]}},
	"sensible": {"name": "Sensible", "slots": [ItemData.Slot.WEAPON, ItemData.Slot.ACCESSORY], "add": {"DA": [1, 3]}},
	"solid": {"name": "Solid", "slots": [ItemData.Slot.HAT, ItemData.Slot.SHIELD, ItemData.Slot.INNERWEAR],
		"scale": {"DP": 0.25}},
	"clever": {"name": "Clever", "slots": [ItemData.Slot.HAT, ItemData.Slot.SHIELD], "add": {"HV": [1, 3]}},
	"spell": {"name": "Spell", "slots": [ItemData.Slot.HAT, ItemData.Slot.SHIELD], "add": {"MD": [4, 8]}},
	"lucky": {"name": "Lucky", "slots": [ItemData.Slot.ACCESSORY, ItemData.Slot.INNERWEAR], "add": {"LK": [1, 3]}},
}

## Bonus to the refine stat at each refine level, in % of its rolled value
## (the original RefineLevelTable curve, a little steeper), plus a flat
## amount per level so low-level gear is worth refining too.
const REFINE_BONUS: Array[int] = [0, 4, 9, 15, 23, 33, 45, 60, 78, 98, 120]
const REFINE_FLAT := {"AP": 2, "DP": 2, "MA": 1, "MD": 2}
## Chance to succeed going to +1 ... +10.
const REFINE_CHANCE: Array[float] = [0.95, 0.88, 0.76, 0.62, 0.48, 0.36, 0.26, 0.18, 0.12, 0.08]
const MAX_REFINE := 10

var data: ItemData
var prefix := ""
var rolled: Dictionary = {}
var refine := 0


static func make(p_data: ItemData, p_prefix := "", p_rolled := {}) -> GearItem:
	var g := GearItem.new()
	g.data = p_data
	g.prefix = p_prefix
	g.rolled = p_rolled if not p_rolled.is_empty() else p_data.stats.duplicate()
	return g


## Rolls a drop. `quality` (0..1, from DA) raises the stat rolls and the
## chance of a prefix.
static func roll(p_data: ItemData, quality: float) -> GearItem:
	var stats := {}
	for k: String in p_data.stats:
		var base: int = p_data.stats[k]
		var lo := 0.85 + 0.1 * quality
		var t := pow(randf(), 1.0 - 0.5 * quality)  # quality leans toward high rolls
		stats[k] = maxi(1, roundi(base * lerpf(lo, 1.15, t))) if base > 0 else base
	var p := ""
	var options: Array[String] = []
	for key: String in PREFIXES:
		if p_data.slot in PREFIXES[key].slots:
			options.append(key)
	if options.size() > 0 and randf() < 0.3 + 0.4 * quality:
		p = options[randi() % options.size()]
		var info: Dictionary = PREFIXES[p]
		for k: String in info.get("scale", {}):
			if stats.has(k):
				stats[k] = roundi(stats[k] * (1.0 + info.scale[k]))
		for k: String in info.get("add", {}):
			var r: Array = info.add[k]
			stats[k] = stats.get(k, 0) + randi_range(r[0], r[1])
	return make(p_data, p, stats)


func title() -> String:
	var t := data.display_name
	if prefix != "":
		t = "%s %s" % [PREFIXES[prefix].name, t]
	if refine > 0:
		t += " +%d" % refine
	return t


## Stats with the refine bonus applied.
func stats() -> Dictionary:
	var out := rolled.duplicate()
	if refine > 0 and data.refine_stat != "" and out.has(data.refine_stat):
		var base: int = out[data.refine_stat]
		out[data.refine_stat] = base + roundi(base * REFINE_BONUS[refine] / 100.0) + refine * int(REFINE_FLAT.get(data.refine_stat, 1))
	return out


func can_refine() -> bool:
	return data.refine_stat != "" and refine < MAX_REFINE


func refine_chance() -> float:
	return REFINE_CHANCE[refine] if refine < MAX_REFINE else 0.0


## Bronze Fragments and Galder one refine attempt costs.
func refine_cost() -> Dictionary:
	return {"ore": 1 + refine / 2, "galder": 30 + 25 * refine}


## "AP 26  ·  AC 2", with the change from `other` when given.
func summary(other: GearItem = null) -> String:
	var mine := stats()
	var theirs := other.stats() if other else {}
	var parts: PackedStringArray = []
	for k in Stats.KEYS:
		if not mine.has(k) and not theirs.has(k):
			continue
		var v: int = mine.get(k, 0)
		var s := "%s %d" % [k, v]
		if other:
			var d: int = v - int(theirs.get(k, 0))
			if d != 0:
				s += " (%s%d)" % ["+" if d > 0 else "", d]
		parts.append(s)
	return "  ·  ".join(parts)


func to_dict() -> Dictionary:
	return {"id": String(data.id), "prefix": prefix, "rolled": rolled, "refine": refine}
