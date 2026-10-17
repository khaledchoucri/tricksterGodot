extends Node2D
## Megalopolis, between runs (scenes/hub.tscn). Builds the square from the
## hub's RoomData, places its people and the expedition gate, runs
## conversations from the story file, sells restorations, and reports how
## the last run ended. The game's main scene.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const DOOR_SCENE := preload("res://scenes/door.tscn")
const GAME_SCENE := "res://scenes/game.tscn"
const CAMERA_MARGIN := 40
const GATE_RANGE := 30.0

var hub: HubData
var room: Room
var player: Player
var npcs: Array[Npc] = []
var gate: Door
var story: Story
var talking := false
var leaving := false

var _portraits: Dictionary = {}

@onready var hud: Hud = $Hud
@onready var dialogue: DialogueBox = $Ui/DialogueBox


func _ready() -> void:
	hub = Run.hub
	if not FileAccess.file_exists("res://original_assets/maps/%s/map.json" % hub.room.map):
		hud.center("Original assets not found.\nRun tools/setup_assets.py (see docs/poc/README.md), then reopen the project.")
		return
	story = Story.new(hub.story)
	Run.new_run()  # fresh state for the HUD and the player's stats (and the chosen class's look)
	room = Room.new()
	add_child(room)
	room.build(hub.room)
	_spawn_player()
	for data in hub.npcs:
		if data.requires == &"" or Profile.level(data.requires) > 0:
			_add_npc(data)
	gate = DOOR_SCENE.instantiate()
	gate.reward = "expedition"
	gate.position = room.nearest_reachable(hub.gate_position)
	room.world.add_child(gate)
	hud.set_hub_mode(true)
	hud.set_room(hub.room.display_name)
	Audio.play_music(hub.music)
	Audio.play_ambience(hub.ambience)
	_welcome()


func _add_npc(data: NpcData) -> Npc:
	var npc: Npc = NPC_SCENE.instantiate()
	npc.data = data
	npc.position = data.position if room.is_walkable(data.position) else room.nearest_reachable(data.position)
	room.world.add_child(npc)
	npcs.append(npc)
	return npc


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.room = room
	player.position = room.nearest_reachable(hub.gate_position + Vector2(0, 160))
	room.player = player
	room.world.add_child(player)
	player.set_camera_limits(room.rect, CAMERA_MARGIN)


func _welcome() -> void:
	var r := Run.last_result
	Run.last_result = {}
	if Profile.is_new():
		hud.log_line("[Notice] Service has ended. Thank you for playing.", Color("f07a62"))
		hud.log_line("[Megalopolis] Players online: 1", Color("94a7b2"))
		await get_tree().create_timer(1.2).timeout
		var guide := _npc(&"cavalier")
		if guide and is_inside_tree():
			await talk(guide)
		return
	if r.is_empty():
		hud.log_line("[Megalopolis] Players online: 1", Color("94a7b2"))
		return
	if r.get("bounty", 0) > 0:
		hud.log_line("[System] New best Heat %d cleared: +%d Harkon Shard%s." % [r.heat, r.bounty, "" if r.bounty == 1 else "s"],
			Color("e0b54d"))
	if r.won:
		hud.log_line("[System] Expedition complete. Coral Beach is quiet, for now.", Color("e0b54d"))
	else:
		hud.log_line("[System] Rollback complete. You remember everything.", Color("c9a4ff"))
	hud.notice("Carried home: %d TM, %d Harkon Shard%s" % [r.tm, r.shards, "" if r.shards == 1 else "s"])
	if r.has("kept"):
		hud.log_line("[System] To the warehouse: %d Galder, %d Bronze Fragments, %d materials%s." % [r.kept.galder,
			r.kept.ore, r.kept.materials, "" if r.won else " (half was lost in the rollback)"], Color("a8d8da"))


func _npc(id: StringName) -> Npc:
	for n in npcs:
		if n.data.id == id:
			return n
	return null


func _physics_process(_delta: float) -> void:
	if talking or leaving or not is_instance_valid(player):
		return
	var nearest: Npc = null
	for n in npcs:
		n.prompt.visible = false
		if n.in_range(player.global_position) and (nearest == null or \
				n.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position)):
			nearest = n
	if nearest:
		nearest.prompt.visible = true
		if Input.is_action_just_pressed("interact"):
			talk(nearest)
			return
	if gate.ready_to_enter() and Combat.ground(player.global_position - gate.global_position).length() < GATE_RANGE:
		if Run.classes.filter(func(c: ClassData) -> bool: return c.unlocked()).size() > 1 or Run.trickster_unlocked():
			_choose_character()
		else:
			_depart()


func _process(_delta: float) -> void:
	hud.refresh(player)


# ---------------------------------------------------------------- talking

## Plays the NPC's current conversation, then any follow-up (the restoration menu).
func talk(npc: Npc) -> void:
	var c := story.conversation_for(String(npc.data.id))
	if c.is_empty():
		return
	_set_talking(true)
	npc.prompt.visible = false
	var lines: Array = []
	for l: Array in c.get("lines", []):
		lines.append(_line(String(l[0]), String(l[1])))
	await dialogue.play(lines)
	story.finish(c)
	match c.get("then", ""):
		"restore":
			await _restore_menu(npc)
		"warehouse":
			await _warehouse_menu(npc)
		"server":
			await _server_menu(npc)
		"forge":
			await _forge_menu(npc)
		"cards":
			await _cards_menu(npc)
		"mastery":
			await _mastery_menu(npc)
		"drills":
			await _drill_menu(npc)
		"compound":
			await _compound_menu(npc)
	_set_talking(false)


func _line(speaker: String, text: String) -> Dictionary:
	if speaker == "system":
		return {"name": "", "portrait": null, "text": text}
	var npc := _npc(StringName(speaker))
	var data: NpcData = npc.data if npc else null
	return {"name": data.display_name if data else speaker.capitalize(), "portrait": _portrait(data), "text": text}


func _portrait(data: NpcData) -> Texture2D:
	if data == null or data.portrait.is_empty():
		return null
	if not _portraits.has(data.portrait):
		var path := "res://original_assets/portraits/%s.png" % data.portrait
		_portraits[data.portrait] = load(path) if ResourceLoader.exists(path) else null
	return _portraits[data.portrait]


func _set_talking(on: bool) -> void:
	talking = on
	hud.set_log_visible(not on)
	player.set_physics_process(not on)
	player.set_process_unhandled_input(not on)
	if on:
		player.velocity = Vector2.ZERO
		player.sprite.play_action("idle")


## The guide's menu: restore parts of the city with banked TM and shards.
func _restore_menu(npc: Npc) -> void:
	while true:
		var options: Array = []
		for r in hub.restorations:
			var lvl := Profile.level(r.id)
			var maxed := lvl >= r.max_level
			var cost := ""
			if not maxed:
				var parts: PackedStringArray = []
				if r.tm_cost(lvl + 1) > 0:
					parts.append("%d TM" % r.tm_cost(lvl + 1))
				if r.shard_cost(lvl + 1) > 0:
					parts.append("%d Shard%s" % [r.shard_cost(lvl + 1), "" if r.shard_cost(lvl + 1) == 1 else "s"])
				cost = " · ".join(parts)
			options.append({"title": "%s  (%d/%d)" % [r.display_name, lvl, r.max_level],
				"tag": "Restored" if maxed else cost, "text": r.describe(maxi(lvl, 1)),
				"disabled": maxed or not Profile.can_buy(r)})
		options.append({"title": "Leave", "tag": "", "text": "You have %d TM and %d Harkon Shards." % [Profile.tm, Profile.shards]})
		var pick := await dialogue.choose(_line(String(npc.data.id), "What shall we restore?"), options)
		if pick < 0 or pick >= hub.restorations.size():
			return
		var r: RestorationData = hub.restorations[pick]
		if Profile.buy(r):
			Audio.play("ui_unique_get.wav", -4.0)
			hud.log_line("[System] %s restored (%d/%d)." % [r.display_name, Profile.level(r.id), r.max_level], Color("e0b54d"))
			for data in hub.npcs:
				if data.requires == r.id and _npc(data.id) == null:
					_add_npc(data)
					hud.log_line("[Megalopolis] %s logged in." % data.display_name, Color("94a7b2"))


## The warehouse: choose the heirloom to carry into runs, or clear shelves.
func _warehouse_menu(npc: Npc) -> void:
	while true:
		var items: Array[GearItem] = []
		var options: Array = []
		for i in Profile.warehouse.size():
			var g := GearItem.from_dict(Profile.warehouse[i], Run.item_by_id)
			items.append(g)
			if g == null:
				options.append({"title": "(unknown item)", "text": "", "disabled": true})
				continue
			options.append({"title": g.title(), "tag": "Carried" if Profile.heirloom == i else g.data.slot_name(),
				"icon": g.data.icon(), "text": g.summary()})
		options.append({"title": "Carry nothing", "tag": "", "text": "Head out with only the Rookie Sword."})
		options.append({"title": "Wardrobe", "tag": "%d pieces" % Profile.wardrobe.size(),
			"text": "Choose what to wear: ears, tails, hats, masks, capes and sprints."})
		options.append({"title": "Leave", "tag": "", "text": "%d / %d shelves used." % [Profile.warehouse.size(), Profile.WAREHOUSE_SIZE]})
		var line := "Which one goes out with you?" if items.size() else "Empty shelves. Send something home from a Portable Port."
		var pick := await dialogue.choose(_line(String(npc.data.id), line), options)
		if pick == items.size():
			Profile.set_heirloom(-1)
			continue
		if pick == items.size() + 1:
			await _wardrobe_menu(npc)
			continue
		if pick < 0 or pick > items.size() + 1:
			return
		var g := items[pick]
		var what := await dialogue.choose(_line(String(npc.data.id), "%s. What should I do with it?" % g.title()), [
			{"title": "Carry it as my heirloom", "tag": "", "text": "Equipped at the start of every run, synced to the area's level."},
			{"title": "Throw it away", "tag": "", "text": "Frees the shelf. It can't be undone."},
			{"title": "Back", "tag": "", "text": ""}])
		if what == 0:
			Profile.set_heirloom(pick)
			Audio.play("etc_item1.wav")
			hud.log_line("[System] You'll carry %s." % g.title(), Color("a8d8da"))
		elif what == 1:
			Profile.discard_item(pick)


func _stored_items() -> Array[GearItem]:
	var out: Array[GearItem] = []
	for d in Profile.warehouse:
		out.append(GearItem.from_dict(d, Run.item_by_id))
	return out


func _piece(id: String) -> WardrobeData:
	for w in hub.wardrobe:
		if String(w.id) == id:
			return w
	return null


## What's worn in each wardrobe slot; pick a slot to change it.
func _wardrobe_menu(npc: Npc) -> void:
	while true:
		var options: Array = []
		for slot: String in WardrobeData.SLOTS:
			var w := _piece(Profile.worn.get(slot, ""))
			options.append({"title": "%s: %s" % [WardrobeData.SLOT_NAMES[slot], w.display_name if w else "nothing"],
				"tag": "", "icon": w.icon() if w else null, "text": w.describe() if w else "Empty."})
		options.append({"title": "Done", "tag": "", "text": ""})
		var pick := await dialogue.choose(_line(String(npc.data.id), "Dress up. It's still a game."), options)
		if pick < 0 or pick >= WardrobeData.SLOTS.size():
			return
		var slot: String = WardrobeData.SLOTS[pick]
		var pieces: Array[WardrobeData] = []
		var choices: Array = []
		for w in hub.wardrobe:
			if w.slot == slot and Profile.owns(w.id):
				pieces.append(w)
				choices.append({"title": w.display_name, "tag": "Worn" if Profile.worn.get(slot, "") == String(w.id) else "",
					"icon": w.icon(), "text": w.describe()})
		choices.append({"title": "Wear nothing", "tag": "", "text": "" if pieces.size() else "You own nothing for this slot yet."})
		var c := await dialogue.choose(_line(String(npc.data.id), "Which one?"), choices)
		if c >= 0 and c < pieces.size():
			Profile.wear(slot, pieces[c].id)
			Audio.play("etc_item1.wav")
		elif c == pieces.size():
			Profile.wear(slot, &"")


## Eugene's album: claim finished sets, or buy pieces with TM and shards.
func _cards_menu(npc: Npc) -> void:
	while true:
		var page := await dialogue.choose(_line(String(npc.data.id), "The album, or the shop?"), [
			{"title": "The album", "tag": "%d cards" % Profile.cards.size(), "text": "Card sets and their rewards."},
			{"title": "The shop", "tag": "%d TM" % Profile.tm, "text": "Wardrobe pieces for Time Marks and shards."},
			{"title": "Leave", "tag": "", "text": "Wear pieces through Keeper Julio's wardrobe."}])
		if page == 0:
			await _album(npc, true)
		elif page == 1:
			await _album(npc, false)
		else:
			return


func _album(npc: Npc, sets: bool) -> void:
	while true:
		var options: Array = []
		for s in (hub.card_sets if sets else []):
			var done := s.complete()
			var tag := "Claimed" if s.claimed() else ("Claim!" if done else "%d / %d" % [s.progress(), s.monsters.size()])
			var missing: PackedStringArray = []
			for m in s.monsters:
				if int(Profile.cards.get(String(m), 0)) == 0:
					missing.append(Run.monster_stats(Run.enemy(m)).get("name", String(m)))
			options.append({"title": "%s set  →  %s" % [s.display_name, s.reward.display_name], "tag": tag,
				"icon": s.reward.icon(), "text": s.reward.describe() + ("\nMissing: " + ", ".join(missing) if missing.size() else ""),
				"disabled": s.claimed() or not done})
		var shop: Array[WardrobeData] = []
		for w in ([] if sets else hub.wardrobe):
			if w.price_tm > 0 and not Profile.owns(w.id):
				shop.append(w)
				var price := "%d TM" % w.price_tm + (" + %d Shard%s" % [w.price_shards, "" if w.price_shards == 1 else "s"] if w.price_shards > 0 else "")
				options.append({"title": "Buy %s" % w.display_name, "tag": price, "icon": w.icon(), "text": w.describe(),
					"disabled": Profile.tm < w.price_tm or Profile.shards < w.price_shards})
		options.append({"title": "Back", "tag": "", "text": "%d TM, %d Harkon Shards." % [Profile.tm, Profile.shards]})
		var pick := await dialogue.choose(_line(String(npc.data.id), "The album, then." if sets else "Take your pick."), options)
		var n_sets := hub.card_sets.size() if sets else 0
		if pick < 0 or pick >= n_sets + shop.size():
			return
		var piece: WardrobeData
		if pick < n_sets:
			var s := hub.card_sets[pick]
			Profile.set_flag("set_" + String(s.id))
			piece = s.reward
		else:
			piece = shop[pick - n_sets]
			Profile.tm -= piece.price_tm
			Profile.shards -= piece.price_shards
		Profile.give_wardrobe(piece.id)
		if not Profile.worn.has(piece.slot):
			Profile.wear(piece.slot, piece.id)
		Audio.play("ui_unique_get.wav", -4.0)
		hud.log_line("[System] %s added to your wardrobe." % piece.display_name, Color("e0b54d"))


## Driller Marky: the first drill is free; buy deeper ones, choose which to carry.
func _drill_menu(npc: Npc) -> void:
	if not hub.drills.is_empty() and not String(hub.drills[0].id) in Profile.drills:
		Profile.drills.append(String(hub.drills[0].id))
		Profile.drill = String(hub.drills[0].id)
		Profile.save()
		hud.log_line("[System] You got a %s." % hub.drills[0].display_name, Color("e0b54d"))
	while true:
		var options: Array = []
		for d in hub.drills:
			var owned := String(d.id) in Profile.drills
			var tag := "Carried" if Profile.drill == String(d.id) else ("Owned" if owned else "%d TM%s" % [d.price_tm,
				" + %d Shard%s" % [d.price_shards, "" if d.price_shards == 1 else "s"] if d.price_shards else ""])
			options.append({"title": d.display_name, "tag": tag, "icon": d.icon(), "text": d.describe(),
				"disabled": not owned and (Profile.tm < d.price_tm or Profile.shards < d.price_shards)})
		options.append({"title": "Leave", "tag": "", "text": "%d TM, %d Harkon Shards." % [Profile.tm, Profile.shards]})
		var pick := await dialogue.choose(_line(String(npc.data.id), "Pick a drill. Carry one at a time!"), options)
		if pick < 0 or pick >= hub.drills.size():
			return
		var d := hub.drills[pick]
		if not String(d.id) in Profile.drills:
			Profile.tm -= d.price_tm
			Profile.shards -= d.price_shards
			Profile.drills.append(String(d.id))
			Audio.play("etc_money.wav")
		Profile.drill = String(d.id)
		Profile.save()


## Master Louis raises skill card caps with banked materials and Galder.
func _mastery_menu(npc: Npc) -> void:
	while true:
		var cards: Array[CardData] = []
		var options: Array = []
		for c in Run.all_cards():
			if c.master_material == null:
				continue
			cards.append(c)
			var lvl := int(Profile.mastery.get(String(c.id), 0))
			var maxed := lvl >= Run.MAX_MASTERY
			var cost := Run.mastery_cost(c)
			var have := int(Profile.materials.get(String(cost.material.id), 0))
			options.append({"title": "%s  ·  cap Lv %d%s" % [c.display_name, Run.card_cap(c.id), "" if maxed else " → %d" % (Run.card_cap(c.id) + 1)],
				"tag": "Mastered" if maxed else "%d %s (%d)  ·  %d G" % [cost.count, cost.material.display_name, have, cost.galder],
				"icon": cost.material.icon(), "text": c.describe(Run.card_cap(c.id)), "disabled": not Run.can_master(c)})
		options.append({"title": "Leave", "tag": "", "text": "%d Galder banked." % Profile.galder})
		var pick := await dialogue.choose(_line(String(npc.data.id), "Which technique do you want to take further?"), options)
		if pick < 0 or pick >= cards.size():
			return
		Run.master_card(cards[pick])
		Audio.play("ui_unique_get.wav", -4.0)
		hud.log_line("[System] %s can now reach Lv %d." % [cards[pick].display_name, Run.card_cap(cards[pick].id)], Color("e0b54d"))


## Marx refines stored items with banked Galder and Bronze Fragments.
func _forge_menu(npc: Npc) -> void:
	while true:
		var items := _stored_items()
		var options: Array = []
		for g in items:
			if g == null or not g.can_refine():
				options.append({"title": g.title() if g else "(unknown item)", "tag": "",
					"text": "Can't be refined." if g else "", "disabled": true})
				continue
			var cost := Run.city_refine_cost(g)
			options.append({"title": "%s  →  +%d" % [g.title(), g.refine + 1], "tag": g.data.refine_stat,
				"icon": g.data.icon(), "text": "%d%% chance  ·  %d Bronze, %d Galder%s" % [roundi(g.refine_chance() * 100),
					cost.ore, cost.galder, "  ·  failing may lose a level" if g.refine >= 4 else ""],
				"disabled": not Run.can_city_refine(g)})
		options.append({"title": "Leave", "tag": "", "text": "%d Galder and %d Bronze Fragments banked." % [Profile.galder, Profile.ore]})
		var pick := await dialogue.choose(_line(String(npc.data.id), "Bring it to the anvil."), options)
		if pick < 0 or pick >= items.size():
			return
		Audio.play("ui_refine_proceed.wav")
		var result := Run.city_refine(pick)
		var g := GearItem.from_dict(Profile.warehouse[pick], Run.item_by_id)
		match result:
			"success":
				Audio.play("ui_refine_success.wav")
				hud.log_line("[System] Marx refined it: %s." % g.title(), Color("e0b54d"))
			"drop":
				Audio.play("ui_refine_fail.wav")
				hud.log_line("[System] The refine failed. %s lost a level." % g.title(), Color("f07a62"))
			_:
				Audio.play("ui_refine_fail.wav")
				hud.log_line("[System] The refine failed. The materials are gone.", Color("f07a62"))


## Paul compounds banked materials into stored items.
func _compound_menu(npc: Npc) -> void:
	while true:
		var mats: Array[MaterialData] = []
		var options: Array = []
		for id: String in Profile.materials:
			var m := Run.material_by_id(StringName(id))
			if m == null or Profile.materials[id] <= 0:
				continue
			mats.append(m)
			options.append({"title": m.display_name, "tag": "%d / %d" % [Profile.materials[id], m.need], "icon": m.icon(),
				"text": "Compounds %s into a free slot of a stored item." % m.describe(),
				"disabled": Profile.materials[id] < m.need})
		options.append({"title": "Leave", "tag": "", "text": "" if mats.size() else "No materials banked yet."})
		var pick := await dialogue.choose(_line(String(npc.data.id), "What are we setting today?"), options)
		if pick < 0 or pick >= mats.size():
			return
		var m := mats[pick]
		var items := _stored_items()
		var targets: Array[int] = []
		var item_opts: Array = []
		for i in items.size():
			if items[i] and items[i].free_slots() > 0:
				targets.append(i)
				item_opts.append({"title": items[i].title(), "tag": "%d free" % items[i].free_slots(),
					"icon": items[i].data.icon(), "text": items[i].summary()})
		item_opts.append({"title": "Back", "tag": "", "text": "" if targets.size() else "No stored item has a free slot."})
		var t := await dialogue.choose(_line(String(npc.data.id), "Into which piece?"), item_opts)
		if t < 0 or t >= targets.size():
			continue
		var g := items[targets[t]]
		var c := Run.city_compound(targets[t], m)
		Audio.play("ui_compose_success.wav")
		hud.log_line("[System] Paul set %s into %s: %s +%d." % [m.display_name, g.title(),
			c.stat + (" attack" if m.is_element() else ""), c.value], Color("e0b54d"))


## The GM console: raise or lower each Server Setting.
func _server_menu(npc: Npc) -> void:
	while true:
		var options: Array = []
		for id: String in ServerSettings.ORDER:
			var s: Dictionary = ServerSettings.SETTINGS[id]
			var r := ServerSettings.rank(id)
			options.append({"title": "%s  %d / %d" % [s.name, r, s.max],
				"tag": "+%d Heat per rank" % s.heat, "text": s.text})
		var heat := ServerSettings.heat()
		options.append({"title": "Done", "tag": "Heat %d" % heat,
			"text": "+%d%% TM per run. Best Heat cleared: %s." % [roundi(heat * ServerSettings.TM_PER_HEAT * 100),
				str(Profile.best_heat) if Profile.best_heat >= 0 else "none"]})
		var pick := await dialogue.choose(_line(String(npc.data.id),
			"Server settings. Heat %d. Clear a run at a new best Heat and I'll find you a Harkon Shard per level." % heat),
			options)
		if pick < 0 or pick >= ServerSettings.ORDER.size():
			return
		ServerSettings.cycle(ServerSettings.ORDER[pick])
		Audio.play("ui_btn_ok.wav")


# ---------------------------------------------------------------- expedition

## With more than one character slot, the gate asks who logs in.
func _choose_character() -> void:
	_set_talking(true)
	var options: Array = []
	for c in Run.classes:
		options.append({"title": c.display_name, "tag": "Playing" if String(c.id) == Profile.class_id else "",
			"text": c.text if c.unlocked() else "Locked. " + c.unlock_text, "disabled": not c.unlocked()})
	var made := not Profile.custom.is_empty()
	options.append({"title": "Trickster" if made else "Create a Trickster",
		"tag": "Playing" if Profile.class_id == "trickster" else "",
		"text": ("Your own class: %s kit, %s, trees: %s." % [Profile.custom.get("kit", ""), Profile.custom.get("graph", ""),
			", ".join(Profile.custom.get("trees", []))]) if made else
			("The server's class data has started to bleed together. Build a class of your own." if Run.trickster_unlocked()
			else "Locked. Reach a 3rd job and clear a run with both Buffalo and Bunny."),
		"disabled": not Run.trickster_unlocked()})
	if made:
		options.append({"title": "Remake the Trickster", "tag": "", "text": "Choose a new kit, graph and trees."})
	options.append({"title": "Not yet", "tag": "", "text": "Stay in the city."})
	var pick := await dialogue.choose({"name": "Character select", "portrait": null,
		"text": "Who logs in to Coral Beach?"}, options)
	var n := Run.classes.size()
	if pick == n or (made and pick == n + 1):
		if not made or pick == n + 1:
			if not await _create_trickster():
				_set_talking(false)
				player.global_position += Vector2(0, 60)
				return
		Profile.class_id = "trickster"
		Profile.save()
		_set_talking(false)
		_depart()
		return
	_set_talking(false)
	if pick < 0 or pick >= n:
		player.global_position += Vector2(0, 60)
		return
	Profile.class_id = String(Run.classes[pick].id)
	Profile.save()
	_depart()


## Character creation for the custom class: kit, type graph, two trees.
func _create_trickster() -> bool:
	var line := {"name": "Character creation", "portrait": null, "text": "Choose a fighting style."}
	var kits := ["sword", "hammer", "fists"]
	var k := await dialogue.choose(line, [
		{"title": "Sword", "tag": "", "text": "Buffalo's look and the sword combo."},
		{"title": "Hammer", "tag": "", "text": "Buffalo's look and the heavy hammer combo."},
		{"title": "Fists", "tag": "", "text": "Bunny's look and the punch combo, weapon sheathed."},
		{"title": "Cancel", "tag": "", "text": ""}])
	if k < 0 or k >= kits.size():
		return false
	var graphs: Array = Run.TRICKSTER_GRAPHS.keys()
	var g_opts: Array = []
	for name: String in graphs:
		var parts: PackedStringArray = []
		var gr: Dictionary = Run.TRICKSTER_GRAPHS[name]
		for t: String in Stats.TYPE_ORDER:
			parts.append("%s %d%%" % [Stats.TYPES[t].name, roundi(float(gr[t]) * 100)])
		g_opts.append({"title": name, "tag": "", "text": "Grows: " + "  ·  ".join(parts)})
	line.text = "Draw the type graph: how the class grows on its own."
	var g := await dialogue.choose(line, g_opts)
	if g < 0 or g >= graphs.size():
		return false
	var trees := Run.trickster_trees()
	var chosen: Array = []
	for round_i in 2:
		var t_opts: Array = []
		for t in trees:
			var names: PackedStringArray = []
			for c in t.cards:
				names.append(c.display_name)
			t_opts.append({"title": "%s tree" % t.display_name, "tag": "Chosen" if String(t.id) in chosen else "",
				"text": ", ".join(names) if t.unlocked() else "Locked. " + t.unlock_text,
				"disabled": not t.unlocked() or String(t.id) in chosen})
		line.text = "Pick the %s skill tree. The Fighter's tree comes with every Trickster." % ["first", "second"][round_i]
		var pick := await dialogue.choose(line, t_opts)
		if pick < 0 or pick >= trees.size():
			return false
		chosen.append(String(trees[pick].id))
	Profile.custom = {"kit": kits[k], "graph": graphs[g], "trees": chosen}
	Profile.save()
	Audio.play("ui_unique_get.wav", -4.0)
	hud.log_line("[System] A Trickster logs in for the first time.", Color("e0b54d"))
	return true


func _depart() -> void:
	leaving = true
	Audio.play("etc_warp.wav")
	await hud.fade(1.0, 0.3)
	get_tree().change_scene_to_file(GAME_SCENE)
