extends SmokeSection
## Map-independent checks that equipment capacity changes cannot create HP.

## Synchronous checks restore all replaced run fields and both seeded RNG values.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["gear", "deck", "_stats", "hp", "mp", "debuffs", "_baseline", "form", "level", "xp", "pending_levels"]:
		saved[key] = Run.get(key)
	var rng_seed: int = Run.rng.seed
	var rng_state: int = Run.rng.state
	var blocked: bool = Events.is_blocking_signals()
	var run_blocked: bool = Run.is_blocking_signals()
	Events.set_block_signals(true)
	Run.set_block_signals(true)
	Run.gear = RunGear.new()
	Run.deck = RunDeck.new()
	Run._stats = {}
	Run.debuffs = {}
	Run._baseline = true
	Run.form = &""
	Run.level = 1
	Run.xp = 0
	Run.pending_levels = 0
	_cycles()
	_level_up()
	for key: String in saved:
		Run.set(key, saved[key])
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state
	Run.set_block_signals(run_blocked)
	Events.set_block_signals(blocked)


func _cycles() -> void:
	var data := ItemData.new()
	data.slot = ItemData.Slot.HAT
	data.stats = {"HP": 500}
	var piece := GearItem.make(data)
	for fraction: float in [0.01, 0.5, 1.0]:
		Run.gear.equipment = {}
		Run.stats_changed()
		var base_max: int = Run.max_hp
		var hp: int = maxi(1, floori(base_max * fraction))
		Run.hp = hp
		Run.gear.equip(piece)
		check(Run.max_hp == base_max + 500 and Run.hp == hp,
			"HP piece increases capacity without healing at %.0f%% HP" % (fraction * 100))
		for cycle: int in 10:
			Run.gear.take_off(piece)
			Run.gear.equip(piece)
		check(Run.hp == hp, "ten HP equip cycles cannot heal at %.0f%% HP" % (fraction * 100))
		Run.gear.take_off(piece)
		check(Run.max_hp == base_max and Run.hp == hp, "unequip preserves HP below the smaller cap")
	Run.gear.equip(piece)
	Run.hp = Run.max_hp
	Run.gear.take_off(piece)
	var capped: int = Run.hp
	check(capped == Run.max_hp, "removing a full HP piece clamps to the smaller maximum")
	Run.gear.equip(piece)
	check(Run.hp == capped, "re-equipping after a cap clamp cannot restore the lost HP")
	Run.hp = 0
	Run.gear.take_off(piece)
	Run.gear.equip(GearItem.make(data))
	check(Run.hp == 0, "equipping cannot revive a zero-HP character")


func _level_up() -> void:
	Run.hp = 1
	var before: int = Run.max_hp
	Run.gain_exp(Run.exp_to_next())
	check(Run.level == 2 and Run.max_hp > before and Run.hp == 1 + Run.max_hp - before,
		"level-up HP gain still heals by the maximum increase")
