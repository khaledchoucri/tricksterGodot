extends Node
## UI audit: opens every screen with the most content it can hold (a full
## warehouse, every card, long item names, every pick list at its largest)
## at the shipped 1280x720 window, and checks that nothing is off screen,
## no option is out of reach and no clipped text is cut. Saves a screenshot
## of each screen for a human look.
##
##   godot res://tests/ui_audit.tscn -- out=C:/path/to/shots
## (Rendering is needed for screenshots, so run it windowed, not --headless.)

var out := "user://ui_audit"
var problems: PackedStringArray = []
var screens := 0


func _ready() -> void:
	var size := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a == "noscale":
			get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	get_window().size = size
	print("window %s, viewport %s" % [size, get_viewport().get_visible_rect().size])
	DirAccess.make_dir_recursive_absolute(out)
	Profile.use_path("user://ui_audit_profile.json", true)
	_run.call_deferred()


func _run() -> void:
	_fill_profile()
	await _audit_hub()
	await _audit_game()
	print("\n==== UI audit: %d screens, %d problem(s) ====" % [screens, problems.size()])
	for p in problems:
		print("PROBLEM  " + p)
	get_tree().quit(1 if problems.size() else 0)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


# ---------------------------------------------------------------- checks

## Checks every visible control on a CanvasLayer and saves a screenshot.
func audit(screen: String) -> void:
	await _wait(0.15)
	await RenderingServer.frame_post_draw
	screens += 1
	var view := get_viewport().get_visible_rect().grow(1.0)
	for c in _controls(get_tree().root):
		if not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0:
			continue
		var r := Rect2(c.get_global_transform_with_canvas().origin, c.size * c.get_global_transform_with_canvas().get_scale())
		var scroll := _scroll_parent(c)
		if scroll:
			continue  # scrolled content may extend past; its scroll area is checked
		if not view.encloses(r):
			problems.append("%s: %s is off screen (%s)" % [screen, _path(c), r])
		if c is PickOption:
			var need := 18.0
			for l: Label in [c.get_node("%Head"), c.get_node("%Body")]:
				if l.text != "":
					need += l.get_line_count() * l.get_line_height() + 4.0
			if c.size.y > need + 36.0:
				problems.append("%s: %s is %d px tall for %d px of text" % [screen, _path(c), c.size.y, need])
			elif c.size.y < need - 6.0:
				problems.append("%s: %s cuts its text (%d px for %d)" % [screen, _path(c), c.size.y, need])
		if c is RichTextLabel and not (c as RichTextLabel).scroll_active and not (c as RichTextLabel).fit_content 				and (c as RichTextLabel).get_content_height() > c.size.y + 2.0:
			problems.append("%s: text cut off at the bottom of %s" % [screen, _path(c)])
		if c is RichTextLabel and (c as RichTextLabel).scroll_active and (c as RichTextLabel).get_content_height() > c.size.y + 2.0:
			print("note  %s: %s scrolls (%d of %d px shown)" % [screen, _path(c), c.size.y, (c as RichTextLabel).get_content_height()])
		var trimmed := c is Label and (c as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		if c is Label and (c as Label).clip_text and (c as Label).text != "" and not trimmed:
			var l := c as Label
			var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size("font_size")).x
			if w > l.size.x + 2.0:
				problems.append("%s: text cut in %s ('%s')" % [screen, _path(c), l.text.left(40)])
	get_viewport().get_texture().get_image().save_png(out.path_join(screen + ".png"))


func _controls(n: Node) -> Array[Control]:
	var acc: Array[Control] = []
	_collect(n, acc, false)
	return acc


func _collect(n: Node, acc: Array[Control], on_layer: bool) -> void:
	var layer := on_layer or n is CanvasLayer
	if n is Control and layer:
		acc.append(n)
	for c in n.get_children():
		_collect(c, acc, layer)


func _scroll_parent(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


func _path(c: Node) -> String:
	var parts: PackedStringArray = []
	var n := c
	for _i in 4:
		if n == null:
			break
		parts.insert(0, n.name)
		n = n.get_parent()
	return "/".join(parts)


# ---------------------------------------------------------------- content

## The fullest profile the game allows.
func _fill_profile() -> void:
	Profile.set_flag("met_cavalier")
	Profile.tm = 99999
	Profile.shards = 99
	Profile.galder = 99999
	Profile.ore = 999
	for r: RestorationData in Run.hub.restorations:
		Profile.restorations[String(r.id)] = r.max_level
	for region in Run.route.regions:
		for e in region.enemies:
			Profile.cards[String(e.id)] = 9
	for f in DirAccess.get_files_at("res://data/wardrobe"):
		var w: WardrobeData = load("res://data/wardrobe/" + f.trim_suffix(".remap"))
		Profile.give_wardrobe(w.id)
	for f in DirAccess.get_files_at("res://data/drills"):
		var d: DrillData = load("res://data/drills/" + f.trim_suffix(".remap"))
		if not String(d.id) in Profile.drills:
			Profile.drills.append(String(d.id))
	for f in DirAccess.get_files_at("res://data/materials"):
		var m: MaterialData = load("res://data/materials/" + f.trim_suffix(".remap"))
		Profile.materials[String(m.id)] = 99
	for g in _longest_items(Profile.WAREHOUSE_SIZE):
		Profile.store_item(g.to_dict())
	Profile.save()


## Items with the longest names, prefixed, refined and compounded.
func _longest_items(n: int) -> Array[GearItem]:
	var all: Array[ItemData] = []
	for f in DirAccess.get_files_at("res://data/items"):
		all.append(load("res://data/items/" + f.trim_suffix(".remap")))
	all.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name.length() > b.display_name.length())
	var out_items: Array[GearItem] = []
	for i in mini(n, all.size()):
		var g := GearItem.roll(all[i], 1.0)
		var longest := ""
		for k: String in GearItem.PREFIXES:
			if all[i].slot in GearItem.PREFIXES[k].slots and String(GearItem.PREFIXES[k].name).length() > longest.length():
				longest = k
		g.prefix = longest
		g.refine = 7
		g.slots = 3
		var mats: Array[MaterialData] = []
		for f in DirAccess.get_files_at("res://data/materials"):
			mats.append(load("res://data/materials/" + f.trim_suffix(".remap")))
		for j in 3:
			g.compound(mats[(i + j * 5) % mats.size()], 1.0)
		out_items.append(g)
	return out_items


# ---------------------------------------------------------------- hub

func _audit_hub() -> void:
	Run.new_run()
	var hub: Hub = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await _wait(1.5)
	await audit("hub_city")
	for npc: Npc in hub.talker.npcs.duplicate():
		var id := String(npc.data.id)
		var top := await _talk(hub, npc, [], "hub_%s" % id)
		for i in top.size():
			if top[i]:
				await _talk(hub, npc, [i], "hub_%s_%d" % [id, i + 1])
	# Character select at the gate.
	Profile.stats["clears"] = 1
	Profile.stats["clears_gladiator"] = 1
	Profile.stats["clears_champion"] = 1
	hub._choose_character()
	await _choices_open(hub)
	await _check_choices(hub, "hub_character_select")
	hub.dialogue._chosen.emit(hub.dialogue._cancel)
	await _wait(0.4)
	hub.queue_free()
	await _wait(0.3)


## Talks to `npc`, follows `path` through its menus, audits the menu it
## lands on and backs out. Returns which options of that menu can be
## explored (enabled and not the exit).
func _talk(hub: Hub, npc: Npc, path: Array, screen: String) -> Array[bool]:
	var explorable: Array[bool] = []
	hub.talker.talking = false
	hub.player.global_position = npc.global_position + Vector2(-40, 30)
	hub.talk(npc)
	var d: DialogueBox = hub.dialogue
	var step := 0
	var audited := false
	for _i in 400:
		await _wait(0.05)
		if not d.visible:
			if not hub.talker.talking:
				break
			continue
		if not d._scroll.visible:
			d._typing = false
			d._advanced.emit()
			continue
		await _wait(0.1)
		if step < path.size():
			d._chosen.emit(path[step])
			step += 1
			continue
		if not audited:
			audited = true
			await _check_choices(hub, screen)
			for i in d._buttons.size():
				explorable.append(i != d._cancel and not d._buttons[i].disabled)
		# Back out: the exit if there is one, else the last option.
		d._chosen.emit(d._cancel if d._cancel >= 0 else d._buttons.size() - 1)
	await _wait(0.3)
	return explorable


func _choices_open(hub: Hub) -> void:
	for _i in 100:
		await _wait(0.05)
		if hub.dialogue._scroll.visible:
			return


func _check_choices(hub: Hub, screen: String) -> void:
	var d: DialogueBox = hub.dialogue
	await audit(screen)
	for i in d._buttons.size():
		if not d.choice_reachable(i):
			problems.append("%s: option %d of %d can't be reached" % [screen, i + 1, d._buttons.size()])


# ---------------------------------------------------------------- run

func _audit_game() -> void:
	Profile.heirloom = -1
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(2.5)
	if is_instance_valid(game.player):
		game.player.invulnerable_until = game.player.now() + 9999.0
	# Every card at its cap, a full loadout, the rune, the longest gear.
	for c: CardData in Run.deck.card_pool():
		Run.deck.cards[c.id] = Run.deck.card_cap(c.id) if Run.has_method("card_cap") else 5
	var skills: Array[StringName] = []
	for c: CardData in Run.deck.card_pool():
		if c.is_skill() and skills.size() < 3:
			skills.append(c.id)
	Run.deck.loadout = skills
	Run.deck.take_rune(Run.echoes[0].runes[0])
	var items := _longest_items(60)
	for k in Run.gear.EQUIP_SLOTS:
		for g in items:
			if k in Run.gear.slot_keys_for(g.data):
				Run.gear.equip(g, k)
				break
	Run.level = 99
	Run.purse.galder = 999999
	Run.purse.ore = 999
	for f in DirAccess.get_files_at("res://data/materials"):
		var m: MaterialData = load("res://data/materials/" + f.trim_suffix(".remap"))
		Run.purse.material_info[m.id] = m
		Run.purse.materials[m.id] = 99
	Run.stats_changed()
	game.player.refresh_gear()
	await _wait(0.5)
	await audit("run_hud_full")
	game.hud.sheet.toggle()
	await audit("run_character_sheet")
	game.hud.sheet.toggle()
	var picks := {
		"card": Run.deck.card_pool().slice(0, 4),
		"replace": [0, 1, 2, -1],
		"type": Stats.TYPE_ORDER.duplicate(),
		"job": Run.job.next_jobs.duplicate() if Run.job.next_jobs.size() else [Run.job],
		"gear": Run.gear.gear_offers(3),
		"gear_slot": ["acc1", "acc2", ""],
		"rune": Run.echoes[0].runes + [null],
	}
	game._pending_skill = Run.deck.card_pool()[0]
	game._pending_gear = items[0]
	game._pending_mat = Run.purse.material_info.values()[0]
	for kind: String in picks:
		await _pick(game, kind, picks[kind])
	game._open_anvil()
	await _check_pick(game, "run_pick_anvil")
	game._open_compounder()
	await _check_pick(game, "run_pick_compound_mat")
	game._start_pick("compound_target", Run.gear.compound_targets() + [""])
	await _check_pick(game, "run_pick_compound_target")
	game._shop = Run.gear.shop_offers()
	game._open_shop()
	await _check_pick(game, "run_pick_shop")
	game._open_port()
	await _check_pick(game, "run_pick_port")
	Profile.restorations["drill_shop"] = 1
	game.hud.drill.start(Run.purse.drill(), 0.0)
	await audit("run_drill")
	game.hud.drill.visible = false
	game.hud.show_results(true)
	await audit("run_results_clear")
	game.hud.results_panel.visible = false
	game.hud.show_results(false)
	await audit("run_results_rollback")
	game.queue_free()


func _pick(game: Game, kind: String, options: Array) -> void:
	game._start_pick(kind, options)
	await _check_pick(game, "run_pick_" + kind)


func _check_pick(game: Game, screen: String) -> void:
	await audit(screen)
	for i: int in game._pick_options.size():
		if not game.hud.pick_reachable(i):
			problems.append("%s: option %d of %d can't be reached" % [screen, i + 1, game._pick_options.size()])
	game.hud.pick_panel.visible = false
	get_tree().paused = false
