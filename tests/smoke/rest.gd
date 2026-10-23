extends SmokeSection
## Rest stops: where they fall in the run, arriving (the heal, Julio, the way on), his
## conversation and the warehouse swap.


func run() -> void:
	var Run := run_state()
	var P := profile()
	var stops: Array[int] = []
	for d: int in Run.route.plan.size():
		if Run.route.plan[d].rest:
			stops.append(d)
	var after_bosses := stops.all(func(d: int) -> bool: return Run.route.plan[d - 1].boss)
	check(Run.route.plan.size() == 32 and stops.size() == 2 and after_bosses and Run.route.plan[-1].boss,
		"a run is 32 rooms: a rest stop after each of the first two bosses (rooms %s)" % str(stops.map(func(d: int) -> int: return d + 1)))

	# Arriving at the Gate of Desert Beach: no fight, half of max HP and MP back, Julio, doors.
	# The city is fully restored for it, then put back as it was for the sections after.
	var restorations: Dictionary = P.restorations.duplicate()
	var flags: Dictionary = P.flags.duplicate()
	await _arrive(Run, P, stops)
	P.restorations = restorations
	P.flags = flags


func _arrive(Run: Node, P: Node, stops: Array[int]) -> void:
	await clear_room()
	_restore_all(Run)
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	Run.hp = int(Run.max_hp * 0.1)
	Run.mp = 0
	Run.route.depth = stops[0]
	game._load_room()
	await wait(2.5)
	var stop: RestStop = null
	for c in game.room.get_children():
		if c is RestStop:
			stop = c
	check(stop != null and game.room.data.map == "mapg01" and enemies().is_empty() and game.phase == game.Phase.DOORS,
		"the first rest stop is the Gate of Desert Beach: nothing to fight, the way on is open")
	check(Run.hp >= int(Run.max_hp * 0.59) and Run.mp >= int(Run.max_mp * 0.5),
		"arriving heals half of max HP and MP (HP %d / %d, MP %d / %d)" % [Run.hp, Run.max_hp, Run.mp, Run.max_mp])
	if stop == null:
		return
	Run.route.depth = stops[0] - 1  # as if the boss before it had just fallen
	game._open_doors()
	check(game.room.doors.any(func(d: Door) -> bool: return d.reward == "rest"), "the boss room's way out is the Rest Stop door")
	Run.route.depth = stops[0]
	var julio := stop.talker.npc(&"julio")
	check(julio != null and stop.talker.story.conversation_for("julio").get("then") == "warehouse",
		"Keeper Julio keeps the gate, and his conversation opens the shelves")

	# The swap: a stored hat goes on, and the found hat it replaces goes home.
	var before: int = P.warehouse.size()
	var shelf: int = P.store_item(GearItem.roll(_item("steel_helmet"), 0.0).to_dict())
	var found := GearItem.roll(_item("candy_hat"), 0.0)
	Run.gear.equip(found, "hat")
	var swapped: bool = Run.city.swap_from_shelf(shelf)
	var worn: GearItem = Run.gear.equipped("hat")
	check(swapped and worn != null and worn.stored == P.item_uid(shelf) and found.stored >= 0 and P.warehouse.size() == before + 2,
		"swapping at the gate wears the stored hat and sends the found one home")
	check(not Run.city.swap_from_shelf(shelf), "an item already worn can't be taken off the shelf again")
	for i in range(P.warehouse.size() - 1, before - 1, -1):
		P.discard_item(i)
	Run.gear.equipment.erase("hat")
	Run.stats_changed()
