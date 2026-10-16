extends Node
## Everything that belongs to the current run (autoloaded as `Run`).
## A rollback (death) or a cleared run resets it. Values that will persist
## between runs later (TM, shards) are only tallied here for the results screen.

signal leveled_up(new_level: int)

const REGION_PATH := "res://data/coral_beach/region.tres"
const MONSTERS_PATH := "res://original_assets/data/monsters.json"
const STAT_KEYS: Array[String] = ["AP", "DX", "MA", "LK", "HP", "DP"]
const STATS := {
	"AP": {"name": "AP · Power", "text": "+8% attack damage"},
	"DX": {"name": "DX · Dexterity", "text": "+5% attack and movement speed"},
	"MA": {"name": "MA · Magic", "text": "+12% skill damage, skill cooldown −6%"},
	"LK": {"name": "LK · Luck", "text": "+5% critical hit chance, +10% Galder"},
	"HP": {"name": "HP · Vitality", "text": "+15 max HP, heal 15"},
	"DP": {"name": "DP · Defense", "text": "Take 6% less damage"},
}
const MAX_CARD_LEVEL := 5
const BASE_HP := 140
const MAX_MP := 100
const SLOTS := 3
## Skill every run starts with, in slot 1.
const STARTER_SKILL := &"lacerator"

var region: RegionData
var monster_data: Dictionary = {}  # original stats by monster id (generated, may be empty)

var depth := 0
var plan: Array[RoomPlan] = []
var level := 1
var xp := 0
var max_hp := BASE_HP
var hp := BASE_HP
var stats: Dictionary = {}
var cards: Dictionary = {}  # StringName card id -> level
## Skill card ids in slots 1-3 (RMB, Q, E); &"" is an empty slot.
var loadout: Array[StringName] = [&"", &"", &""]
var mp := MAX_MP
var galder := 0
var tm := 0
var shards := 0
var kills := 0
var time := 0.0
var won := false
var pending_levels := 0


## A room in this run's plan: which room, and how it's modified.
class RoomPlan:
	var data: RoomData
	var elite := false
	var boss := false

	func _init(p_data: RoomData, p_elite := false, p_boss := false) -> void:
		data = p_data
		elite = p_elite
		boss = p_boss


func _ready() -> void:
	region = load(REGION_PATH)
	if FileAccess.file_exists(MONSTERS_PATH):
		monster_data = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))


func new_run() -> void:
	depth = 0
	level = 1
	xp = 0
	max_hp = BASE_HP
	hp = max_hp
	stats = {}
	for k in STAT_KEYS:
		stats[k] = 0
	cards = {STARTER_SKILL: 1}
	loadout = [STARTER_SKILL, &"", &""]
	mp = MAX_MP
	galder = 0
	tm = 0
	shards = 0
	kills = 0
	time = 0.0
	won = false
	pending_levels = 0
	plan = _plan_rooms()


func _plan_rooms() -> Array[RoomPlan]:
	var pool := region.rooms.duplicate()
	pool.shuffle()
	var out: Array[RoomPlan] = []
	for i in region.run_length:
		out.append(RoomPlan.new(pool[i % pool.size()], i in region.elite_depths))
	out.append(RoomPlan.new(region.boss_room, false, true))
	return out


func current_room() -> RoomPlan:
	return plan[depth]


func monster_stats(enemy: EnemyData) -> Dictionary:
	return monster_data.get(enemy.monster_id, {})


# ---------------------------------------------------------------- growth

func exp_to_next() -> int:
	return 300 + 250 * level


func gain_exp(amount: int) -> void:
	xp += amount
	while xp >= exp_to_next():
		xp -= exp_to_next()
		level += 1
		pending_levels += 1
		leveled_up.emit(level)


func apply_stat(key: String) -> void:
	stats[key] += 1
	if key == "HP":
		max_hp += 15
		heal(15)


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	Events.player_hp_changed.emit()


## Learns a card or raises its level. A new skill goes in the first free
## slot, or in `slot` when given (replacing what was there).
func add_card(id: StringName, slot := -1) -> void:
	var is_new := card_level(id) == 0
	cards[id] = mini(card_level(id) + 1, MAX_CARD_LEVEL)
	var card := region.card(id)
	if not is_new or not card.is_skill():
		return
	if slot < 0:
		slot = loadout.find(&"")
	if slot >= 0:
		var old := loadout[slot]
		if old != &"":
			cards.erase(old)
		loadout[slot] = id


func free_slot() -> int:
	return loadout.find(&"")


func gain_mp(amount: int) -> void:
	mp = mini(mp + amount, MAX_MP)


func spend_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	return true


func card_level(id: StringName) -> int:
	return cards.get(id, 0)


func card_value(id: StringName) -> float:
	var card := region.card(id)
	return card.value_at(card_level(id)) if card else 0.0


## Up to `n` card offers: new cards, or upgrades of owned ones when `upgrade`
## is true. New-card offers lean on skills: at least two of three are skills
## while there are skills left to learn.
func card_offers(n: int, upgrade: bool) -> Array[CardData]:
	var skills: Array[CardData] = []
	var talents: Array[CardData] = []
	for card in region.cards:
		var lvl := card_level(card.id)
		if (upgrade and lvl > 0 and lvl < MAX_CARD_LEVEL) or (not upgrade and lvl == 0):
			(skills if card.is_skill() else talents).append(card)
	skills.shuffle()
	talents.shuffle()
	var out: Array[CardData] = []
	if upgrade:
		out.append_array(skills + talents)
		out.shuffle()
		return out.slice(0, n)
	var want_skills := mini(skills.size(), maxi(n - 1, 0) if talents.size() > 0 else n)
	out.append_array(skills.slice(0, want_skills))
	out.append_array(talents.slice(0, n - out.size()))
	out.append_array(skills.slice(want_skills, want_skills + n - out.size()))
	out.shuffle()
	return out


func stat_offers(n: int) -> Array[String]:
	var keys := STAT_KEYS.duplicate()
	keys.shuffle()
	return keys.slice(0, n)


# ---------------------------------------------------------------- combat numbers

func _stat(key: String) -> int:
	return stats.get(key, 0)


func _berserk_mult() -> float:
	return 1.0 + card_value(&"berserker") / 100.0 if hp * 2 < max_hp else 1.0


func attack_mult() -> float:
	return (1.0 + 0.08 * _stat("AP")) * _berserk_mult()


func skill_mult() -> float:
	return (1.0 + 0.12 * _stat("MA")) * _berserk_mult()


func skill_cooldown_mult() -> float:
	return pow(0.94, _stat("MA"))


func speed_mult() -> float:
	return 1.0 + 0.05 * _stat("DX")


func attack_speed_mult() -> float:
	return (1.0 + 0.05 * _stat("DX")) * (1.0 + card_value(&"hyper_beat") / 100.0)


func crit_chance() -> float:
	return 0.05 + 0.05 * _stat("LK")


func damage_taken_mult() -> float:
	return pow(0.94, _stat("DP")) * (1.0 - card_value(&"guard") / 100.0)


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	Events.player_hp_changed.emit()


func add_kill(exp_amount: int, tm_amount: int, galder_amount: int) -> void:
	kills += 1
	tm += tm_amount
	galder += int(galder_amount * (1.0 + 0.1 * _stat("LK")))
	if card_level(&"adrenaline") > 0:
		heal(int(card_value(&"adrenaline")))
	gain_exp(exp_amount)
