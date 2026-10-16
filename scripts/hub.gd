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
	Run.new_run()  # fresh state for the HUD and the player's stats
	room = Room.new()
	add_child(room)
	room.build(hub.room)
	_spawn_player()
	for data in hub.npcs:
		var npc: Npc = NPC_SCENE.instantiate()
		npc.data = data
		npc.position = data.position if room.is_walkable(data.position) else room.nearest_reachable(data.position)
		room.world.add_child(npc)
		npcs.append(npc)
	gate = DOOR_SCENE.instantiate()
	gate.reward = "expedition"
	gate.position = room.nearest_reachable(hub.gate_position)
	room.world.add_child(gate)
	hud.set_hub_mode(true)
	hud.set_room(hub.room.display_name)
	Audio.play_music(hub.music)
	Audio.play_ambience(hub.ambience)
	_welcome()


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
	if r.won:
		hud.log_line("[System] Expedition complete. Coral Beach is quiet, for now.", Color("e0b54d"))
	else:
		hud.log_line("[System] Rollback complete. You remember everything.", Color("c9a4ff"))
	hud.notice("Carried home: %d TM, %d Harkon Shard%s" % [r.tm, r.shards, "" if r.shards == 1 else "s"])


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
		options.append({"title": "Leave", "tag": "", "text": "%d / %d shelves used." % [Profile.warehouse.size(), Profile.WAREHOUSE_SIZE]})
		var line := "Which one goes out with you?" if items.size() else "Empty shelves. Send something home from a Portable Port."
		var pick := await dialogue.choose(_line(String(npc.data.id), line), options)
		if pick == items.size():
			Profile.set_heirloom(-1)
			continue
		if pick < 0 or pick > items.size():
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


# ---------------------------------------------------------------- expedition

func _depart() -> void:
	leaving = true
	Audio.play("etc_warp.wav")
	await hud.fade(1.0, 0.3)
	get_tree().change_scene_to_file(GAME_SCENE)
