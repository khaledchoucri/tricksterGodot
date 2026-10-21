class_name RestStop
extends Node
## A rest stop in the run (RestStopData): heals on arrival, places its people, and
## runs their conversations. A conversation that leads to the warehouse lets you swap
## what you wear with what's on the shelves, or send a find home. The game opens the
## way on as soon as you arrive; nothing here is fought.

const NPC_SCENE := preload("res://scenes/npc.tscn")
const DIALOGUE_SCENE := preload("res://scenes/ui/dialogue_box.tscn")

var data: RestStopData
var room: Room
var talker: Talker


## Heals, places the people and readies the dialogue box.
func arrive(p_data: RestStopData, p_room: Room, player: Player, hud: Hud) -> void:
	data = p_data
	room = p_room
	var ui := CanvasLayer.new()
	add_child(ui)
	var dialogue: DialogueBox = DIALOGUE_SCENE.instantiate()
	ui.add_child(dialogue)
	talker = Talker.new(Story.new(data.story), dialogue, hud)
	talker.player = player
	for n in data.npcs:
		if n.requires != &"" and Profile.level(n.requires) <= 0:
			continue  # as in the hub: Julio keeps the shelves once the warehouse is restored
		var npc: Npc = NPC_SCENE.instantiate()
		npc.data = n
		npc.position = n.position if room.is_walkable(n.position) else room.nearest_reachable(n.position)
		room.world.add_child(npc)
		talker.npcs.append(npc)
		hud.log_line("[%s] %s is here." % [data.room.display_name, n.display_name], Color("a8d8da"))
	Run.heal(int(Run.max_hp * data.heal_share))
	Run.gain_mp(int(Run.max_mp * data.heal_share))
	Audio.play("eff_healing1.wav", -4.0)
	hud.log_line("[System] You rest at the gate: %d%% of your HP and MP come back." % roundi(data.heal_share * 100),
		Color("94a7b2"))


func _physics_process(_delta: float) -> void:
	if talker == null or talker.talking or not is_instance_valid(talker.player):
		return
	var nearest := talker.nearest(talker.player.global_position)
	if nearest and Input.is_action_just_pressed("interact"):
		talk(nearest)


## Plays the person's conversation, then the warehouse if it leads there.
func talk(npc: Npc) -> void:
	var c := await talker.converse(npc)
	if c.is_empty():
		return
	if c.get("then", "") == "warehouse":
		await _warehouse_menu(npc)
	talker.set_talking(false)


## The shelves: put on a stored item (what it replaces goes home), or send a find home.
func _warehouse_menu(npc: Npc) -> void:
	while true:
		var options: Array = []
		var actions: Array[Callable] = []
		var full := Profile.warehouse_full()
		for i in Profile.warehouse.size():
			var g := Run.city.from_shelf(i)
			if g == null:
				continue
			var worn := Run.city.worn_from_shelf(i)
			options.append({"title": g.title(), "icon": g.data.icon(), "tag": "Worn" if worn else g.data.slot_name(),
				"text": g.summary(), "disabled": worn})
			actions.append(Run.city.swap_from_shelf.bind(i))
		for key: String in RunGear.EQUIP_SLOTS:
			var g := Run.gear.equipped(key)
			if g and not (g.stored < 0 and g.data == Run.cls.start_weapon):
				var no_room := full and g.stored < 0
				options.append({"title": "Send home: " + g.title(), "icon": g.data.icon(), "tag": "Shelves full" if no_room else "",
					"text": "Safe on a shelf, but you stop wearing it for the rest of the run.", "disabled": no_room})
				actions.append(Run.city.bank.bind(g))
		options.append({"title": "Leave", "cancel": true, "tag": "",
			"text": "%d / %d shelves used." % [Profile.warehouse.size(), Profile.warehouse_size()]})
		var line := "Swap what you carry for what's on the shelves." if not Profile.warehouse.is_empty() \
			else "Empty shelves. Anything you send home stays put."
		var pick := await talker.dialogue.choose(talker.line(String(npc.data.id), line), options)
		if pick < 0 or pick >= actions.size():
			return
		if actions[pick].call():
			Audio.play("etc_item1.wav")
			talker.player.dress()
			talker.player.refresh_gear()
		else:
			Audio.play("ui_btn_ok.wav", -8.0)
