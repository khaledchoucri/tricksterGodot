extends SmokeSection
## The worst-case pick lists fit on screen and can be left.


## The worst-case pick lists fit on screen and can be left.
func run() -> void:
	var Run := run_state()
	var saved_mats: Dictionary = Run.purse.materials.duplicate()
	for path in DirAccess.get_files_at("res://data/materials"):
		var m: MaterialData = load("res://data/materials/" + path.trim_suffix(".remap"))
		Run.purse.material_info[m.id] = m
		Run.purse.materials[m.id] = m.need + 2
	game._open_compounder()
	await wait(0.3)
	var all_ok := true
	for i: int in game._pick_options.size():
		all_ok = all_ok and game.hud.pick_reachable(i)
	check(all_ok and game.hud.pick_panel.get_global_rect().size.y <= 720.0,
		"a Compounder with %d materials fits on screen and every option is reachable" % (game._pick_options.size() - 1))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.2)
	check(not game.hud.pick_panel.visible or game._pick_kind != "compound_mat", "Esc leaves the Compounder")
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	Run.purse.materials = saved_mats
	var many: Array = []
	for i in 20:
		many.append({"title": "Option %d" % i, "text": "A long description that has to wrap onto a second line inside the pick panel without running under the icon or off the edge."})
	many.append({"title": "Leave", "text": "", "cancel": true})
	game.hud.show_pick("Twenty options", many)
	await wait(0.3)
	check(game.hud.pick_reachable(20) and game.hud.pick_panel.get_global_rect().end.y <= 720.0,
		"a 20-option list scrolls and its Leave option stays pinned on screen (reachable %s, bottom %d)"
		% [game.hud.pick_reachable(20), game.hud.pick_panel.get_global_rect().end.y])
	game.hud.pick_panel.visible = false

	# The character sheet's equipment window: the original's 13 slots and fashion grid, each
	# naming what it holds, and the window fits on screen.
	var hat := GearItem.roll(_item("candy_hat"), 0.0)
	var old_hat: GearItem = Run.gear.equipped("hat")
	Run.gear.equip(hat, "hat")
	game.hud.sheet.toggle()
	await wait(0.2)
	var window: EquipmentWindow = game.hud.sheet.get_node("%Equipment")
	var shown := window.shown()
	check(shown.size() == 23 and shown["hat"].contains(hat.title()) and shown["pet"] == "Pet: empty"
		and window.get_global_rect().end.y <= 720.0,
		"the equipment window shows 13 slots and the fashion grid, the hat in its slot (%d cells, bottom %d)"
		% [shown.size(), window.get_global_rect().end.y])
	game.hud.sheet.toggle()
	if old_hat:
		Run.gear.equip(old_hat, "hat")
	else:
		Run.gear.equipment.erase("hat")
	Run.stats_changed()
