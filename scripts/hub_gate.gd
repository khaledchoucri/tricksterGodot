class_name HubGate
extends RefCounted
## The expedition gate in Megalopolis (Hub.gate_menu): who logs in (the classes, the custom
## Trickster and its creation) and into which chunk, then the departure.

var hub: Hub


func _init(p_hub: Hub) -> void:
	hub = p_hub


## With more than one character slot, the gate asks who logs in.
func choose_character() -> void:
	hub.talker.set_talking(true)
	var options: Array = []
	for c in Run.classes:
		options.append({"title": c.display_name, "tag": "Playing" if String(c.id) == Profile.class_id else "",
			"text": c.text if c.unlocked() else "Locked. " + c.unlock_text, "disabled": not c.unlocked()})
	var made := not Profile.custom.is_empty()
	options.append({"title": "Trickster" if made else "Create a Trickster",
		"tag": "Playing" if Profile.class_id == "trickster" else "",
		"text": ("Your own class: %s kit, %s, trees: %s." % [Profile.custom.get("kit", ""), Profile.custom.get("graph", ""),
			", ".join(Profile.custom.get("trees", []))]) if made else
			("The server's class data has started to bleed together. Build a class of your own." if Run.city.trickster_unlocked()
			else "Locked. Reach a 3rd job and clear a run with both Buffalo and Bunny."),
		"disabled": not Run.city.trickster_unlocked()})
	if made:
		options.append({"title": "Remake the Trickster", "tag": "", "text": "Choose a new kit, graph and trees."})
	options.append({"title": "Not yet", "cancel": true, "tag": "", "text": "Stay in the city."})
	var pick := await hub.dialogue.choose({"name": "Character select", "portrait": null,
		"text": "Who logs in to Coral Beach?"}, options)
	var n := Run.classes.size()
	if pick == n or (made and pick == n + 1):
		if not made or pick == n + 1:
			if not await _create_trickster():
				hub.talker.set_talking(false)
				hub.player.global_position += Vector2(0, 60)
				return
		Profile.class_id = "trickster"
		Profile.save()
		hub.talker.set_talking(false)
		depart_to_chunk()
		return
	hub.talker.set_talking(false)
	if pick < 0 or pick >= n:
		hub.player.global_position += Vector2(0, 60)
		return
	Profile.class_id = String(Run.classes[pick].id)
	Profile.save()
	depart_to_chunk()


## Asks which chunk to set out into when the character has a later one open and built (chunk 1
## otherwise, without asking), then departs.
func depart_to_chunk() -> void:
	var options := chunk_options()
	if options.filter(func(o: Dictionary) -> bool: return not o.get("disabled", false)).size() <= 1:
		hub.depart()
		return
	var cls := Run.chosen_class()
	var playable := Run.route.chunks.filter(func(c: ChunkData) -> bool: return c.playable())
	hub.talker.set_talking(true)
	options.append({"title": "Not yet", "cancel": true, "tag": "", "text": "Stay in the city."})
	var pick := await hub.dialogue.choose({"name": "Server select", "portrait": null,
		"text": "Where does the %s log in?" % cls.display_name}, options)
	hub.talker.set_talking(false)
	if pick < 0 or pick >= playable.size():
		hub.player.global_position += Vector2(0, 60)
		return
	Profile.chunk_choice[String(cls.id)] = (playable[pick] as ChunkData).number
	Profile.save()
	hub.depart()


## The gate's chunk menu for the chosen character: every built chunk, the ones it hasn't opened
## disabled, with the level and job it sets out as.
func chunk_options() -> Array:
	var cls := Run.chosen_class()
	var cls_id := String(cls.id)
	var options: Array = []
	for c: ChunkData in Run.route.chunks:
		if not c.playable():
			continue
		var job: JobData = Run.veteran.job_path(c, cls)[-1]
		options.append({"title": "Chunk %d  ·  %s" % [c.number, c.route_text()],
			"tag": "Lv %d %s" % [c.start_level, job.display_name] if c.open_for(cls_id) else "Locked",
			"text": ("Set out as a %s." % job.display_name) if c.open_for(cls_id)
				else "Clear chunk %d with the %s to open it." % [c.opened_by, cls.display_name],
			"disabled": not c.open_for(cls_id)})
	return options


## Character creation for the custom class: kit, type graph, two trees.
func _create_trickster() -> bool:
	var line := {"name": "Character creation", "portrait": null, "text": "Choose a fighting style."}
	var kits := ["sword", "hammer", "fists"]
	var k := await hub.dialogue.choose(line, [
		{"title": "Sword", "tag": "", "text": "Buffalo's look and the sword combo."},
		{"title": "Hammer", "tag": "", "text": "Buffalo's look and the heavy hammer combo."},
		{"title": "Fists", "tag": "", "text": "Bunny's look and the punch combo, weapon sheathed."},
		{"title": "Cancel", "cancel": true, "tag": "", "text": ""}])
	if k < 0 or k >= kits.size():
		return false
	var graphs: Array = Run.city.TRICKSTER_GRAPHS.keys()
	var g_opts: Array = []
	for name: String in graphs:
		var parts: PackedStringArray = []
		var gr: Dictionary = Run.city.TRICKSTER_GRAPHS[name]
		for t: String in Stats.TYPE_ORDER:
			parts.append("%s %d%%" % [Stats.TYPES[t].name, roundi(float(gr[t]) * 100)])
		g_opts.append({"title": name, "tag": "", "text": "Grows: " + "  ·  ".join(parts)})
	line.text = "Draw the type graph: how the class grows on its own."
	var g := await hub.dialogue.choose(line, g_opts)
	if g < 0 or g >= graphs.size():
		return false
	var trees := Run.city.trickster_trees()
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
		var pick := await hub.dialogue.choose(line, t_opts)
		if pick < 0 or pick >= trees.size():
			return false
		chosen.append(String(trees[pick].id))
	Profile.custom = {"kit": kits[k], "graph": graphs[g], "trees": chosen}
	Profile.save()
	Audio.play("ui_unique_get.wav", -4.0)
	hub.hud.log_line("[System] A Trickster logs in for the first time.", Color("e0b54d"))
	return true
