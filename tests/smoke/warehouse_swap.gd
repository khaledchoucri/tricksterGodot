extends SmokeSection
## Real gun/weapon/shield swaps: capacity rejection and all-or-nothing banking.

class RejectSecond extends RunCity:
	var banks := 0
	## Reject the second write to exercise transaction rollback.
	func bank(g: GearItem) -> bool:
		banks += 1
		return false if banks == 2 else super.bank(g)


## Synchronous fixture isolates persistence, modules, stats, signals and run RNG.
func run() -> void:
	var saved_profile: Dictionary = {}
	for property: Dictionary in Profile.get_script().get_script_property_list():
		saved_profile[property.name] = Profile.get(property.name)
	var saved: Dictionary = {}
	for key: String in ["gear", "city", "deck", "_stats", "hp", "mp", "debuffs", "_baseline", "form"]:
		saved[key] = Run.get(key)
	var rng_seed: int = Run.rng.seed
	var rng_state: int = Run.rng.state
	var blocked: bool = Events.is_blocking_signals()
	Events.set_block_signals(true)
	Run.gear = RunGear.new()
	Run.gear.items = saved.gear.items
	Run.city = RunCity.new()
	Run.deck = RunDeck.new()
	var carrier := CardData.new()
	carrier.id = &"fixture_carrier"
	carrier.tags = [&"carries_guns"]
	Run.deck.registry[carrier.id] = carrier
	Run.deck.cards[carrier.id] = 1
	Run.debuffs = {}
	Run._baseline = true
	Run.form = &""
	_checks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	for key: String in saved_profile:
		Profile.set(key, saved_profile[key])
	for key: String in saved:
		Run.set(key, saved[key])
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state
	Events.set_block_signals(blocked)


func _checks() -> void:
	var shelf := _setup(1)
	var worn: Dictionary = Run.gear.equipment.duplicate()
	var shelves: Array = Profile.warehouse.duplicate(true)
	var hp: int = Run.hp
	check(not Run.city.swap_from_shelf(shelf), "gun swap rejects one free shelf for two found pieces")
	check(Run.gear.equipment == worn and Profile.warehouse == shelves and Run.hp == hp,
		"capacity rejection changes neither equipment, warehouse nor HP")
	check(worn.weapon.stored == -1 and worn.shield.stored == -1,
		"rejected swap does not falsely mark outgoing pieces as stored")
	Profile.discard_item(Profile.warehouse.size() - 1)
	check(Run.city.swap_from_shelf(shelf), "two free shelves permit the whole gun swap")
	check(Run.gear.carries_gun() and Run.gear.equipped("shield") == null,
		"accepted gun swap equips the gun and displaces the shield")
	check(worn.weapon.stored >= 0 and worn.shield.stored >= 0 and Profile.warehouse_full(),
		"both displaced finds reach the warehouse")
	Profile.load_profile()
	check(Profile.warehouse_full(), "both banked pieces persist across reload")
	check(not Run.city.swap_from_shelf(shelf), "already-worn shelf remains unavailable")
	shelf = _setup(0)
	var sword: GearItem = Run.gear.equipment.weapon
	var shield: GearItem = Run.gear.equipment.shield
	# Replacing stored pieces needs no new shelf.
	# The setup is full, so use two existing filler shelves as the stored pieces.
	Profile.update_item(1, sword.to_dict())
	Profile.update_item(2, shield.to_dict())
	Run.gear.equipment = {"weapon": Run.city.from_shelf(1), "shield": Run.city.from_shelf(2)}
	check(Run.city.swap_from_shelf(shelf) and Profile.warehouse_full(),
		"stored outgoing pieces require no new shelves")
	shelf = _setup(2)
	worn = Run.gear.equipment.duplicate()
	shelves = Profile.warehouse.duplicate(true)
	hp = Run.hp
	Run.city = RejectSecond.new()
	check(not Run.city.swap_from_shelf(shelf), "a later banking failure rejects the entire swap")
	check(Run.gear.equipment == worn and Run.hp == hp and Profile.warehouse == shelves,
		"later banking failure restores equipment, HP and earlier warehouse writes")
	check(worn.weapon.stored == -1 and worn.shield.stored == -1,
		"rollback restores outgoing storage markers")
	Profile.load_profile()
	check(JSON.parse_string(JSON.stringify(Profile.warehouse)) == JSON.parse_string(JSON.stringify(shelves)), "rollback is persisted to disk")


func _setup(free_shelves: int) -> int:
	Profile.use_path("user://warehouse_swap_test.json", true)
	Run.city = RunCity.new()
	var gun: ItemData = _item("wood_gun")
	var shelf := Profile.store_item(GearItem.make(gun).to_dict())
	while Profile.warehouse.size() < Profile.warehouse_size() - free_shelves:
		Profile.store_item(GearItem.make(_item("candy_hat")).to_dict())
	Run.gear.equipment = {"weapon": GearItem.make(_item("wood_sword")),
		"shield": GearItem.make(_item("candy_shield"))}
	Run._stats = {}
	Run.hp = 1
	return shelf
