class_name GearItem
extends RefCounted
## One rolled piece of gear: an ItemData, maybe a Trickster prefix
## ("Sharp Wood Sword"), its stats rolled around the base values, its
## refine level, and what has been compounded into its slots.

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
## Compound slots, and what fills them: {"material", "stat", "value"}.
var slots := 0
var compounds: Array[Dictionary] = []
## The warehouse entry it's saved in (-1: not stored). A carried heirloom
## is level-synced: its refine counts up to `refine_cap` and its base stats
## scale down to `sync_level` (both -1: no sync).
var stored := -1
var refine_cap := -1
var sync_level := -1


static func make(p_data: ItemData, p_prefix := "", p_rolled := {}) -> GearItem:
	var g := GearItem.new()
	g.data = p_data
	g.prefix = p_prefix
	g.rolled = p_rolled if not p_rolled.is_empty() else p_data.stats.duplicate()
	g.slots = p_data.compound_slots
	return g


## Rolls a drop. `quality` (0..1, from DA) raises the stat rolls and the
## chance of a prefix.
static func roll(p_data: ItemData, quality: float) -> GearItem:
	var stats := {}
	for k: String in p_data.stats:
		var base: int = p_data.stats[k]
		var lo := 0.85 + 0.1 * quality
		var t := pow(Run.rng.randf(), 1.0 - 0.5 * quality)  # quality leans toward high rolls
		stats[k] = maxi(1, roundi(base * lerpf(lo, 1.15, t))) if base > 0 else base
	var p := ""
	var options: Array[String] = []
	for key: String in PREFIXES:
		if p_data.slot in PREFIXES[key].slots and not p_data.display_name.begins_with(PREFIXES[key].name):
			options.append(key)
	if options.size() > 0 and Run.rng.randf() < 0.3 + 0.4 * quality:
		p = options[Run.rng.randi() % options.size()]
		var info: Dictionary = PREFIXES[p]
		for k: String in info.get("scale", {}):
			if stats.has(k):
				stats[k] = roundi(stats[k] * (1.0 + info.scale[k]))
		for k: String in info.get("add", {}):
			var r: Array = info.add[k]
			stats[k] = stats.get(k, 0) + Run.rng.randi_range(r[0], r[1])
	var g := make(p_data, p, stats)
	if p == "shrewd" or Run.rng.randf() < 0.15 + 0.3 * quality:
		g.slots += 1
	return g


func title() -> String:
	var t := data.display_name
	if prefix != "":
		t = "%s %s" % [PREFIXES[prefix].name, t]
	if refine > 0:
		t += " +%d" % refine
		if effective_refine() < refine:
			t += " (synced to +%d)" % effective_refine()
	if sync_factor() < 1.0:
		t += " (synced %d%%)" % roundi(sync_factor() * 100)
	return t


## How much of its base stats a level-synced item keeps (1.0: all).
func sync_factor() -> float:
	if sync_level < 0 or sync_level >= data.level:
		return 1.0
	return clampf(float(sync_level) / data.level, 0.35, 1.0)


func is_synced() -> bool:
	return sync_factor() < 1.0 or effective_refine() < refine


## Refine level that counts, after level sync.
func effective_refine() -> int:
	return refine if refine_cap < 0 else mini(refine, refine_cap)


## Stats with the refine bonus and compounds applied (elements excluded).
func stats() -> Dictionary:
	var out := rolled.duplicate()
	var f := sync_factor()
	if f < 1.0:
		for k: String in out:
			if out[k] > 0:
				out[k] = maxi(1, roundi(out[k] * f))
	for c in compounds:
		if not c.stat in MaterialData.ELEMENTS:
			out[c.stat] = out.get(c.stat, 0) + c.value
	var r := effective_refine()
	if r > 0 and data.refine_stat != "" and out.has(data.refine_stat):
		var base: int = out[data.refine_stat]
		out[data.refine_stat] = base + roundi(base * REFINE_BONUS[r] / 100.0) + r * int(REFINE_FLAT.get(data.refine_stat, 1))
	return out


## Elemental attack from compounds: element -> value.
func elements() -> Dictionary:
	var out := {}
	for c in compounds:
		if c.stat in MaterialData.ELEMENTS:
			out[c.stat] = out.get(c.stat, 0) + c.value
	return out


func free_slots() -> int:
	return slots - compounds.size()


## Fills a slot with a material, rolling its value; `quality` (0..1, from DA)
## leans the roll upward. Returns the compound added.
func compound(mat: MaterialData, quality := 0.0) -> Dictionary:
	var t := clampf((Run.rng.randf() + Run.rng.randf()) / 2.0 + 0.25 * quality * Run.rng.randf(), 0.0, 1.0)
	var c := {"material": String(mat.id), "stat": mat.stat, "value": roundi(lerpf(mat.min_value, mat.max_value, t))}
	compounds.append(c)
	return c


func can_refine() -> bool:
	return data.refine_stat != "" and refine < MAX_REFINE


func refine_chance() -> float:
	return REFINE_CHANCE[refine] if refine < MAX_REFINE else 0.0


## Bronze Fragments and Galder one refine attempt costs.
func refine_cost() -> Dictionary:
	return {"ore": 1 + refine / 2, "galder": 50 + 40 * refine}


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
	var el := elements()
	for k: String in el:
		parts.append("%s %d" % [k, el[k]])
	if slots > 0:
		parts.append("slots %d/%d" % [compounds.size(), slots])
	var text := "  ·  ".join(parts)
	if data.legend and data.legend_text != "":
		text += "\n" + data.legend_text
	return text


## Rebuilds an item saved with to_dict(); `lookup` finds the ItemData by id.
static func from_dict(d: Dictionary, lookup: Callable) -> GearItem:
	var item_data: ItemData = lookup.call(StringName(d.get("id", "")))
	if item_data == null:
		return null
	var rolled := {}
	for k: String in d.get("rolled", {}):
		rolled[k] = int(d.rolled[k])
	var g := make(item_data, d.get("prefix", ""), rolled)
	g.refine = int(d.get("refine", 0))
	g.slots = int(d.get("slots", item_data.compound_slots))
	for c: Dictionary in d.get("compounds", []):
		g.compounds.append({"material": c.material, "stat": c.stat, "value": int(c.value)})
	return g


func to_dict() -> Dictionary:
	return {"id": String(data.id), "prefix": prefix, "rolled": rolled, "refine": refine, "slots": slots,
		"compounds": compounds}
