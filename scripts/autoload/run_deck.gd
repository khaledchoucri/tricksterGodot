class_name RunDeck
extends RefCounted
## Your cards (Run.deck): every card the game knows, the ones you hold and their levels, the
## loadout, a borrowed rune, offers, learning, mastery and the held talents.

const MAX_CARD_LEVEL := 5
## Master Louis masters a card this many times at most: a mastered card can start a run, at
## its mastery level. Deviation (user, 2026-10-21): the original's Skill Master raised a
## skill's level limit (LimitSkillMaster_*); here mastery is what you set out with.
const MAX_MASTERY := 3
const SLOTS := 3
var cards: Dictionary = {}  # StringName card id -> level
## Skill card ids in slots 1-3 (RMB, Q, E); &"" is an empty slot.
var loadout: Array[StringName] = [&"", &"", &""]
## The sky-blue rune's borrowed skill (slot 4, key F) and its level.
var rune: CardData
var rune_level := 0
## Every card the game knows, by id: from every region, job and echo.
var registry: Dictionary = {}


func index_cards() -> void:
	for r in Run.route.regions:
		for c in r.cards:
			registry[c.id] = c
	var jobs_left: Array[JobData] = []
	for c in Run.classes:
		jobs_left.append(c.start_job)
	while not jobs_left.is_empty():
		var j: JobData = jobs_left.pop_back()
		for c in j.cards:
			registry[c.id] = c
		if j.starter:
			registry[j.starter.id] = j.starter
		jobs_left.append_array(j.next_jobs)


func card(id: StringName) -> CardData:
	return registry.get(id)


## Takes a sky-blue rune: its skill goes in slot 4, stronger in later regions.
func take_rune(c: CardData) -> void:
	rune = c
	rune_level = 1 + 2 * Run.route.region_index()
	for e in Run.echoes:
		if c in e.runes:
			Profile.stats["runes_" + String(e.id)] = int(Profile.stats.get("runes_" + String(e.id), 0)) + 1
			Profile.save()


## Cards the jobs taken so far can offer.
func card_pool() -> Array[CardData]:
	var out: Array[CardData] = []
	for j in Run.jobs:
		for c in j.cards:
			if not c in out:
				out.append(c)
	return out


## Prerequisites count a skill as known at its level while you have it, or
## an advanced form of it (Tempest Strike still counts as Lacerator).
func requirements_met(card: CardData) -> bool:
	for id: StringName in card.requires:
		# A class can stand its own basic spell in for another (Sheep's Mana
		# Ring where the original asks for Mana Arrow).
		var need: StringName = Run.cls.swap_requires.get(id, id) if Run.cls else id
		if known_level(need) < int(card.requires[id]):
			return false
	return true


## A card's level, or that of the advanced form that replaced it.
func known_level(id: StringName) -> int:
	if card_level(id) > 0:
		return card_level(id)
	for owned: StringName in cards:
		var c := card(owned)
		var base := c.upgrades if c else &""
		while base != &"":
			if base == id:
				return cards[owned]
			base = card(base).upgrades if card(base) else &""
	return 0


## Whether a card can be offered as new: not known, prerequisites met, and
## for an advanced form, its base skill is in hand.
func can_learn(c: CardData) -> bool:
	if card_level(c.id) > 0 or not requirements_met(c):
		return false
	if Run.cls and c.id in Run.cls.excluded_cards:
		return false
	# A beast is offered only the skills it can use.
	if c.is_skill() and not Run.form_allows(c.id):
		return false
	if not c.jobs.is_empty() and Run.job and Run.job.id != &"trickster" and not Run.job.id in c.jobs:
		return false
	for other: StringName in c.excludes:
		if card_level(other) > 0:
			return false
	return c.upgrades == &"" or card_level(c.upgrades) > 0


## Learns a card or raises its level. A new skill goes in the first free
## slot, or in `slot` when given (replacing what was there). An advanced form
## replaces its base skill: it takes the base's slot and level, and the base
## is forgotten (in Trickster both are kept, the new one from Lv 1; with a
## single slot to fill here, a Lv 1 upgrade would be a step down).
func add_card(id: StringName, slot := -1) -> void:
	var is_new := card_level(id) == 0
	var c := card(id)
	if is_new and c.upgrades != &"" and card_level(c.upgrades) > 0:
		var at := loadout.find(c.upgrades)
		var base_level := card_level(c.upgrades)
		cards.erase(c.upgrades)
		cards[id] = mini(base_level, card_cap(id))
		if at >= 0:
			loadout[at] = id
		Run.stats_changed()
		return
	cards[id] = mini(card_level(id) + 1, card_cap(id))
	if c.form_actor != "":
		Run.form = id
		Run.instinct = false
	Run.stats_changed()
	if not is_new or not c.is_skill() or is_basic(id):
		return
	if slot < 0:
		slot = loadout.find(&"")
	if slot >= 0:
		var old := loadout[slot]
		if old != &"":
			cards.erase(old)
		loadout[slot] = id


## Whether a card is the class's basic spell (cast from the attack button,
## never put in a slot).
func is_basic(id: StringName) -> bool:
	return Run.cls != null and Run.cls.basic_skill != null and Run.cls.basic_skill.id == id


func free_slot() -> int:
	return loadout.find(&"")


## A card's level cap: 5, or the original's cap when lower.
func card_cap(id: StringName) -> int:
	var c := card(id)
	if c and c.max_level > 0:
		return c.max_level
	return MAX_CARD_LEVEL


## Whether this character could start a run with `c`: masterable, one of its own cards
## (card_pool, as the offers use), and one the starting job could take in the first room
## (Run.new_run() sets that state up).
func can_start_with(c: CardData) -> bool:
	return c.master_material != null and c.max_level == 0 and not is_basic(c.id) \
		and not c.id in Run.cls.start_cards and c in card_pool() and can_learn(c)


## The level a card starts the run at: its mastery level (0: not mastered).
func start_level(id: StringName) -> int:
	return int(Profile.mastery.get(String(id), 0))


## Learns the character's chosen starting skill at its mastery level.
func carry_start_skill() -> void:
	var c := card(StringName(Profile.start_skills.get(String(Run.cls.id), "")))
	if c == null or not Run.city.system_on(&"mastery") or start_level(c.id) <= 0 or not can_start_with(c):
		return
	for _i in start_level(c.id):
		add_card(c.id)


## What the next master level of a card costs: materials and Galder.
func mastery_cost(c: CardData) -> Dictionary:
	var lvl := int(Profile.mastery.get(String(c.id), 0)) + 1
	return {"material": c.master_material, "count": 6 * lvl, "galder": 500 * lvl}


func can_master(c: CardData) -> bool:
	if c.master_material == null or c.max_level > 0 or int(Profile.mastery.get(String(c.id), 0)) >= MAX_MASTERY:
		return false
	var cost := mastery_cost(c)
	return int(Profile.materials.get(String(cost.material.id), 0)) >= cost.count and Profile.galder >= cost.galder


func master_card(c: CardData) -> void:
	var cost := mastery_cost(c)
	Profile.materials[String(cost.material.id)] = int(Profile.materials.get(String(cost.material.id), 0)) - cost.count
	Profile.galder -= cost.galder
	Profile.mastery[String(c.id)] = int(Profile.mastery.get(String(c.id), 0)) + 1
	Profile.save()


## Every card in the game (for the Skill Master's list).
func all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for c: CardData in registry.values():
		out.append(c)
	out.sort_custom(func(a: CardData, b: CardData) -> bool: return a.display_name < b.display_name)
	return out


## Reading: a borrowed rune may strengthen a learned skill, never lower its effective level.
func card_level(id: StringName) -> int:
	if rune and id == rune.id:
		return maxi(rune_level, int(cards.get(id, 0)))
	return cards.get(id, 0)


## The cards held now (a borrowed rune too), in skill-id order: the order the original's
## tables list them, so effects that stack apply in a fixed order.
func held_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for id: StringName in cards:
		if card_level(id) > 0 and card(id):
			out.append(card(id))
	if rune and not cards.has(rune.id):
		out.append(rune)
	out.sort_custom(func(a: CardData, b: CardData) -> bool: return a.skill_id < b.skill_id)
	return out


## The held talents' behaviours (Talent), one per card for the run, in skill-id order.
func talents() -> Array[Talent]:
	var out: Array[Talent] = []
	for c in held_cards():
		if c.talent == null:
			continue
		if not _talents.has(c.id):
			var t: Talent = c.talent.new()
			t.card = c
			_talents[c.id] = t
		out.append(_talents[c.id])
	return out


var _talents: Dictionary = {}  # card id -> Talent, for this run


## Forgets the talents' behaviours (a new run starts them afresh).
func clear_talents() -> void:
	_talents.clear()


## Whether any held card has `tag`.
func holds_tag(tag: StringName) -> bool:
	return held_cards().any(func(c: CardData) -> bool: return c.has_tag(tag))


func card_value(id: StringName) -> float:
	var c := card(id)
	return c.value_at(card_level(id)) if c else 0.0


## Ours: cards up to this original TM level (CardData.tm_level) are offered from room 1. The
## original's first 20 TM levels pass in its first hours; here they give room 1 a choice (six
## of a Fighter's eleven cards).
const TM_OPEN := 20
## Ours: past TM_OPEN, a card comes this many run levels per original TM level. The original
## spreads a 1st job's cards over TM levels 1-50 (Sense's to 70) and chunk 1 runs from Lv 1 to
## about 54: a Fighter's last card (TM 50) comes at Lv 18 in Desert Beach, Sense's TM 70 ones
## at Lv 30 in the Relics. Reading: one run level stands for both the original's character and
## TM levels. A later chunk will need its own start (its 2nd-job cards begin at TM 41).
const TM_PACE := 0.6


## The run level `c` is first offered at.
func unlock_level(c: CardData) -> int:
	return maxi(1, ceili((c.tm_level - TM_OPEN) * TM_PACE))


## Whether the run is far enough along for `c` to be offered.
func level_reached(c: CardData) -> bool:
	return Run.level >= unlock_level(c)


## Up to `n` card offers from the current jobs' trees (or only `from_job`'s):
## new cards whose prerequisites and level are met, or upgrades of owned ones when
## `upgrade` is true. New-card offers lean on skills: at least two of three
## while there are skills left to learn.
func card_offers(n: int, upgrade: bool, from_job: JobData = null) -> Array[CardData]:
	var skills: Array[CardData] = []
	var talents: Array[CardData] = []
	for c in (from_job.cards if from_job else card_pool()):
		var lvl := card_level(c.id)
		# Training can also teach what grows the basic spell (Arrow Rush).
		if (upgrade and lvl > 0 and lvl < card_cap(c.id)) or ((not upgrade or grows_basic(c)) and can_learn(c) and level_reached(c)):
			(skills if c.is_skill() else talents).append(c)
	Run.shuffle(skills)
	Run.shuffle(talents)
	var out: Array[CardData] = []
	# A mage's basic spell is its main weapon: its level-ups and the cards that
	# grow it (Arrow Rush, Mana Ring Booster) are always among the offers.
	for c: CardData in skills + talents:
		if out.size() < n and grows_basic(c):
			out.append(c)
			skills.erase(c)
			talents.erase(c)
	if upgrade:
		var rest := skills + talents
		Run.shuffle(rest)
		out.append_array(rest.slice(0, n - out.size()))
		Run.shuffle(out)
		return out
	var want_skills := mini(skills.size(), maxi(n - 1 - out.size(), 0) if talents.size() > 0 else n - out.size())
	out.append_array(skills.slice(0, want_skills))
	out.append_array(talents.slice(0, n - out.size()))
	out.append_array(skills.slice(want_skills, want_skills + n - out.size()))
	Run.shuffle(out)
	return out


## The class's basic spell, or a talent that improves it.
func grows_basic(c: CardData) -> bool:
	if Run.cls == null or Run.cls.basic_skill == null:
		return false
	# The gun's own talents grow a gunner's basic shot, so they're offered like the cards
	# that build on a basic skill.
	if Run.cls.basic_skill.has_tag(&"gun") and c.has_tag(&"grows_gun"):
		return true
	return c.id == Run.cls.basic_skill.id or (not c.is_skill() and c.requires.has(Run.cls.basic_skill.id))
