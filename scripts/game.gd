extends Node2D
## Runs one expedition through the regions (Coral Beach, then Desert Beach):
## loads rooms cut from the original maps,
## hands out rewards (skill cards, gear, anvils, the job change) and
## level-ups, and ends in a rollback or a clear, which banks the run into the
## Profile and returns to Megalopolis (scenes/hub.tscn). Presents combat
## feedback (hit-stop, shake, damage numbers) announced on the Events bus.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUB_SCENE := "res://scenes/hub.tscn"
## Door rewards, weighted by repetition (two different ones are offered).
const REWARD_POOL: Array[String] = ["card", "card", "card", "card", "upgrade", "upgrade", "gear", "gear", "anvil",
	"compound", "compound", "shop", "shop", "heal", "galder", "shard"]
const CAMERA_MARGIN := 60
## MP restored on entering a room.
const ROOM_MP := 40
## Rewards that need a city system: reward -> Run.system_on() id.
const REWARD_SYSTEMS := {"gear": &"smithing", "anvil": &"smithing", "shop": &"smithing", "compound": &"compounding"}
## Bronze Fragments waiting at an anvil, and Galder for scrapping gear.
const ANVIL_ORE := 2
const SCRAP_GALDER := 25
const MUTED := Color(1, 1, 1, 0.6)
const INFO := Color("a8d8da")

enum Phase { LOADING, FIGHT, REWARD, DOORS, DEAD, WON, MISSING }

var phase := Phase.LOADING
var room: Room
var player: Player
var reward_here := "card"   # reward granted when the current room is cleared

var _shake := 0.0
var _hitstop_id := 0
var _pick_kind := ""
var _pick_options: Array = []
var _pending_skill: CardData  # new skill waiting for a slot to replace
var _pending_gear: GearItem   # accessory waiting for a slot
var _steps: Array[String] = []  # reward steps left for this room
var _return_to := ""  # "shop" or "compound" while one of them is open
var _shop: Array[Dictionary] = []
var _pending_mat: MaterialData
var _legend: GearItem       # a boss's legendary drop, offered when the room is cleared
var _boss_name := ""

@onready var hud: Hud = $Hud


func _ready() -> void:
	hud.picked.connect(_on_picked)
	hud.restart_requested.connect(_restart)
	Events.hitstop_requested.connect(_on_hitstop)
	Events.shake_requested.connect(func(amount: float) -> void: _shake = maxf(_shake, amount))
	Events.damage_shown.connect(_on_damage_shown)
	Events.text_shown.connect(func(at: Vector2, text: String, color: Color) -> void: _float_label(at, text, color, false))
	Events.loot_found.connect(func(text: String) -> void: hud.log_line("[System] " + text, INFO))
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_died.connect(_on_enemy_died)
	Events.boss_health_changed.connect(func(e: Enemy) -> void: hud.show_boss(e.display_name, e.hp, e.max_hp))
	Events.boss_spoke.connect(func(text: String) -> void: hud.log_line("[%s] %s" % [_boss_name, text], Color("e0b54d")))
	Events.player_died.connect(_on_player_died)
	Events.revived.connect(func() -> void:
		hud.log_line("[System] You refused to log out.", Color("c9a4ff"))
		hud.notice("Saved from the rollback"))
	if not FileAccess.file_exists("res://original_assets/actors/buffalo/buffalo.json") \
			or not FileAccess.file_exists("res://original_assets/maps/map_fd11d/map.json"):
		phase = Phase.MISSING
		hud.center("Original assets not found.\nRun tools/setup_assets.py (see docs/poc/README.md), then reopen the project.")
		return
	Run.new_run()
	hud.log_line("[Notice] Trickster service has ended. Thank you for playing.", Color("f07a62"))
	hud.log_line("[Coral Beach] Players online: 1", Color("94a7b2"))
	_load_room()


## After a run: back to the city.
func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)


# ---------------------------------------------------------------- rooms

func _load_room() -> void:
	phase = Phase.LOADING
	if room:
		# Leave the tree right away so nothing touches the old room again.
		remove_child(room)
		room.queue_free()
		room = null
		player = null
	var plan := Run.current_room()
	Run.sync_heirlooms()
	room = Room.new()
	add_child(room)
	if not room.build(plan.data):
		phase = Phase.MISSING
		hud.center("Map %s is missing.\nRun tools/setup_assets.py." % plan.data.map)
		return
	room.cleared.connect(_on_room_cleared)
	room.door_entered.connect(_on_door_entered)
	_spawn_player(room.entry)
	Run.gain_mp(ROOM_MP + Run.room_mp_bonus())
	if Run.quirk(&"well_rested"):
		Run.heal(int(Run.max_hp * 0.08))
	Audio.play_music(Run.region.boss_music if plan.boss else Run.region.field_music)
	Audio.play_ambience(Run.region.boss_ambience if plan.boss else Run.region.field_ambience)
	var heat := ServerSettings.heat()
	hud.set_room("%s  ·  %d / %d%s" % [plan.data.display_name, Run.depth + 1, Run.plan.size(),
		"  ·  Heat %d" % heat if heat > 0 else ""])
	hud.hide_boss()
	await hud.fade(0.0, 0.3)
	if plan.boss:
		_boss_name = _region_boss_name()
	var title := _region_boss_name() if plan.boss else plan.data.display_name
	if plan.local_depth == 0 and not plan.boss:
		title = "%s\n%s" % [Run.region.display_name, title]
	if Run.job_change_due():
		title += "\n%s's trial: clear it to change job" % Run.job.display_name
	elif plan.elite:
		title += "\nElite monsters ahead"
	hud.center(title, 1.2)
	await get_tree().create_timer(0.9).timeout
	if room and room.is_inside_tree():
		phase = Phase.FIGHT
		room.start_encounter(Run.local_depth(), plan.elite, plan.boss)


func _spawn_player(at: Vector2) -> void:
	player = PLAYER_SCENE.instantiate()
	player.room = room
	player.position = at
	room.player = player
	room.world.add_child(player)
	player.set_camera_limits(room.rect, CAMERA_MARGIN)


func _on_room_cleared() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		return
	if Run.final_boss():
		_win()
		return
	phase = Phase.REWARD
	Audio.play("etc_monq_complete.wav", -4.0)
	if Run.quirk(&"hearty"):
		Run.heal(int(Run.max_hp * 0.05))
	hud.log_line("[System] Room cleared.", Color("94a7b2"))
	var cleared_room := room
	await get_tree().create_timer(0.6).timeout
	if room != cleared_room:
		return  # a different room loaded while we waited
	_steps.clear()
	if Run.current_room().boss:
		_region_cleared()
	if _legend:
		_steps.append("legend")
	if Run.job_change_due():
		_steps.append("job")
	_steps.append(reward_here)
	if Run.current_room().elite and Run.system_on(&"smithing"):
		_steps.append("gear")
	if (Run.local_depth() == Run.region.job_change_depth or Run.current_room().boss) and Run.system_on(&"warehouse"):
		_steps.append("port")
	_next_step()


## Runs the next queued reward step; level-ups come after them, then the doors.
func _next_step() -> void:
	if not _steps.is_empty():
		_grant(_steps.pop_front())
		return
	if Run.pending_levels > 0:
		Run.pending_levels -= 1
		_start_pick("type", Stats.TYPE_ORDER.duplicate())
		return
	_open_doors()


func _grant(reward: String) -> void:
	match reward:
		"card", "upgrade":
			var n := 4 if Run.quirk(&"sunshine") else 3
			var opts := Run.card_offers(n, reward == "upgrade")
			if opts.is_empty():
				opts = Run.card_offers(n, reward != "upgrade")
			if not opts.is_empty():
				_start_pick("card", opts)
				return
		"job":
			_start_pick("job", Run.job.next_jobs.duplicate())
			return
		"job_skill":
			var opts := Run.card_offers(3, false, Run.job)
			if not opts.is_empty():
				_start_pick("card", opts)
				return
		"gear":
			var offers := Run.gear_offers(2 if Run.has_trait(&"treasure_sense") else 1)
			if not offers.is_empty():
				Audio.play("etc_item1.wav", -4.0)
				_start_pick("gear", offers)
				return
		"anvil":
			Run.ore += ANVIL_ORE
			hud.log_line("[System] The smith left %d %ss by the anvil." % [ANVIL_ORE, Run.ORE_NAME], INFO)
			Audio.play_ambience("bgs_blacksmith.wav")
			_open_anvil()
			return
		"compound":
			_return_to = "compound"
			_open_compounder()
			return
		"shop":
			_shop = Run.shop_offers()
			_return_to = "shop"
			Audio.play("ui_card.wav")
			_open_shop()
			return
		"port":
			_open_port()
			return
		"legend":
			var g := _legend
			_legend = null
			if g:
				_start_pick("gear", [g])
				return
		"heal":
			var amount := int(Run.max_hp * 0.35)
			Run.heal(amount)
			Audio.play("eff_healing1.wav", -4.0)
			hud.notice("Recovered %d HP" % amount)
		"galder":
			var g := randi_range(120, 220)
			var o := randi_range(1, 2)
			Run.galder += g
			Run.ore += o
			Audio.play("etc_money.wav")
			hud.notice("+%d Galder  ·  +%d %s" % [g, o, Run.ORE_NAME])
		"shard":
			Run.shards += 1
			Audio.play("ui_unique_get.wav", -4.0)
			hud.notice("Harkon Shard found")
			hud.log_line("[System] A Harkon Shard hums faintly in your inventory.", Color("c9a4ff"))
	_next_step()


func _open_doors() -> void:
	phase = Phase.DOORS
	var rewards: Array[String] = []
	var next: Run.RoomPlan = Run.plan[mini(Run.depth + 1, Run.plan.size() - 1)]
	if next.boss:
		rewards = ["boss"]
	else:
		var pool := REWARD_POOL.filter(func(r: String) -> bool:
			if r == "heal" and ServerSettings.hardcore():
				return false
			return not REWARD_SYSTEMS.has(r) or Run.system_on(REWARD_SYSTEMS[r]))
		pool.shuffle()
		rewards.append(pool[0])
		for r in pool:
			if r != pool[0]:
				rewards.append(r)
				break
	var features: Array[StringName] = []
	var pool: Array[EnemyData] = []
	for e in next.region.enemies:
		if not e.is_boss and e.min_depth <= next.local_depth:
			pool.append(e)
	for r in rewards:
		features.append(&"" if r == "boss" or pool.is_empty() else pool[randi() % pool.size()].id)
	room.open_doors(rewards, features)
	Audio.play("etc_warpzone.wav", -6.0)
	hud.log_line("[System] Exits opened.", Color("94a7b2"))


func _on_door_entered(reward: String, feature: StringName) -> void:
	Audio.play("etc_warp.wav")
	Run.depth += 1
	Run.current_room().feature = feature
	reward_here = "card" if reward == "boss" else reward
	await hud.fade(1.0, 0.25)
	_load_room()


# ---------------------------------------------------------------- picks

## Picks pause the game. kind "card": CardData options. "replace": skill
## slot indices, -1 keeps the current skills. "type": type keys. "job":
## JobData. "gear": GearItems, then null to leave it. "gear_slot": accessory
## slot keys, "" keeps both. "anvil": equipment slot keys to refine, "" leaves.
func _start_pick(kind: String, options: Array) -> void:
	_pick_kind = kind
	_pick_options = options
	var shown: Array[Dictionary] = []
	var title := ""
	match kind:
		"card":
			for card: CardData in options:
				var lvl := Run.card_level(card.id)
				shown.append({"title": card.display_name,
					"tag": ("New skill" if card.is_skill() else "New talent") if lvl == 0 else "Lv %d → %d" % [lvl, lvl + 1],
					"text": card.describe(lvl + 1)})
			title = "Choose a %s skill card" % Run.job.display_name
			Audio.play("ui_card.wav")
		"replace":
			for slot: int in options:
				if slot < 0:
					shown.append({"title": "Keep my skills", "tag": "", "text": "Skip %s." % _pending_skill.display_name})
				else:
					var old := Run.card(Run.loadout[slot])
					shown.append({"title": "Replace %s" % old.display_name, "tag": "[%s]" % Hud.SLOT_KEYS[slot],
						"text": "%s takes this slot (Lv %d is lost)." % [_pending_skill.display_name, Run.card_level(old.id)]})
			title = "Skill slots are full"
		"type":
			for t: String in options:
				shown.append(_type_option(t))
			title = "Level %d  ·  Invest in a type" % (Run.level - Run.pending_levels)
			Audio.play("etc_levelup.wav")
		"job":
			for j: JobData in options:
				var text := j.text
				if j.passive != &"":
					text += "\n%s: %s" % [j.passive_name, j.passive_text]
				if not j.unlocked():
					text = "Locked. " + j.unlock_text
				shown.append({"title": j.display_name, "tag": "%s job" % ["1st", "2nd", "3rd"][j.tier - 1], "text": text,
					"disabled": not j.unlocked()})
			title = "Job change  ·  the %s's trial is passed" % Run.job.display_name
			Audio.play("ui_unique_get.wav", -4.0)
		"gear":
			for g: GearItem in options:
				shown.append(_gear_option(g))
			shown.append({"title": "Leave it", "tag": "", "text": "Scrap it for %d Galder." % SCRAP_GALDER})
			_pick_options = options + [null]
			title = "Equipment found"
		"gear_slot":
			for k: String in options:
				if k == "":
					shown.append({"title": "Keep my accessories", "tag": "",
						"text": "Scrap %s for %d Galder." % [_pending_gear.title(), SCRAP_GALDER]})
				else:
					var old := Run.equipped(k)
					shown.append({"title": "Replace %s" % old.title(), "tag": "", "icon": old.data.icon(),
						"text": _pending_gear.summary(old)})
			title = "Both accessory slots are full"
		"anvil":
			for k: String in options:
				if k == "":
					shown.append({"title": "Leave the anvil", "tag": "",
						"text": "%d %ss and %d Galder left." % [Run.ore, Run.ORE_NAME, Run.galder]})
					continue
				var g := Run.equipped(k)
				var cost := g.refine_cost()
				var text := "%d%% chance  ·  %d %s%s, %d Galder" % [roundi(Run.refine_chance(g) * 100), cost.ore,
					Run.ORE_NAME, "s" if cost.ore != 1 else "", cost.galder]
				if g.refine >= 4:
					text += "  ·  failing may lose a level"
				shown.append({"title": "%s  →  +%d" % [g.title(), g.refine + 1], "tag": g.data.refine_stat,
					"icon": g.data.icon(), "text": text, "disabled": not Run.can_afford_refine(g)})
			title = "Anvil  ·  refine your gear"
		"compound_mat":
			for m: MaterialData in options:
				if m == null:
					shown.append({"title": "Leave the Compounder", "tag": "", "text": _materials_text()})
					continue
				var have := Run.material_count(m)
				shown.append({"title": m.display_name, "tag": "%d / %d" % [have, m.need], "icon": m.icon(),
					"text": "Compounds %s into a free slot." % m.describe(),
					"disabled": have < m.need or Run.compound_targets().is_empty()})
			title = "Compounder  ·  choose a material"
		"compound_target":
			for k: String in options:
				if k == "":
					shown.append({"title": "Back", "tag": "", "text": "Choose another material."})
					continue
				var g := Run.equipped(k)
				shown.append({"title": g.title(), "tag": "%d free slot%s" % [g.free_slots(), "s" if g.free_slots() > 1 else ""],
					"icon": g.data.icon(), "text": g.summary()})
			title = "Compound %s into..." % _pending_mat.display_name
		"shop":
			for o: Dictionary in options:
				if o.is_empty():
					shown.append({"title": "Leave the shop", "tag": "", "text": "%d Galder left." % Run.galder})
					continue
				var entry := _shop_entry(o)
				entry.tag = "%d G" % o.price
				entry.disabled = Run.galder < o.price
				shown.append(entry)
			title = "Shop  ·  %d Galder" % Run.galder
		"port":
			var full := Profile.warehouse.size() >= Profile.WAREHOUSE_SIZE
			for g: GearItem in options:
				if g == null:
					shown.append({"title": "Save and go on" if phase != Phase.WON else "Save and log out", "tag": "",
						"text": "Saves your heirloom's progress. Dying rolls back to the last save."})
					continue
				shown.append({"title": "Send %s home" % g.title(), "tag": g.data.slot_name(), "icon": g.data.icon(),
					"text": g.summary() + ("
The warehouse is full." if full else "
Kept in the Megalopolis warehouse, refines and compounds included."),
					"disabled": full})
			title = "Portable Port  ·  save your progress"
	hud.show_pick(title, shown)
	get_tree().paused = true


func _type_option(t: String) -> Dictionary:
	var info: Dictionary = Stats.TYPES[t]
	var pts: int = Run.type_points[t]
	var text := Stats.gain_text(t)
	var unlock := Stats.THRESHOLDS.find(pts + 1)
	if unlock >= 0 and not Stats.trait_at(t, unlock).is_empty():
		var tr := Stats.trait_at(t, unlock)
		text += "\nUnlocks %s: %s" % [tr.name, tr.text]
	else:
		var nxt := Stats.next_trait(t, pts + 1)
		text += "\n" + info.text
		if not nxt.is_empty():
			text += "  Next: %s at %d." % [nxt.trait.name, nxt.at]
	return {"title": info.name, "tag": "%d → %d" % [pts, pts + 1], "text": text}


func _gear_option(g: GearItem) -> Dictionary:
	var current: GearItem = null
	for k in Run.slot_keys_for(g.data):
		current = Run.equipped(k)
		if current == null:
			break
	var load_after := Run.equip_load() + g.data.weight - (current.data.weight if current else 0)
	var text := g.summary(current) + "\nWeight %d  ·  Load %d / %d" % [g.data.weight, load_after, Run.load_limit()]
	if load_after > Run.load_limit():
		text += "  ·  overweight"
	var tag := g.data.slot_name()
	if g.data.family != "":
		tag += " · " + g.data.family
	if current:
		tag += " · replaces " + current.title()
	return {"title": g.title(), "tag": tag, "text": text, "icon": g.data.icon()}


func _on_picked(i: int) -> void:
	get_tree().paused = false
	Audio.play("ui_btn_ok.wav")
	match _pick_kind:
		"card":
			var card: CardData = _pick_options[i]
			if card.is_skill() and Run.card_level(card.id) == 0 and Run.free_slot() < 0:
				_pending_skill = card
				_start_pick("replace", [0, 1, 2, -1])
				return
			Run.add_card(card.id)
			hud.log_line("[System] %s learned (Lv %d)." % [card.display_name, Run.card_level(card.id)], INFO)
		"replace":
			var slot: int = _pick_options[i]
			if slot >= 0:
				Run.add_card(_pending_skill.id, slot)
				hud.log_line("[System] %s learned." % _pending_skill.display_name, INFO)
			_pending_skill = null
		"type":
			var t: String = _pick_options[i]
			var unlocked := Run.apply_type(t)
			if not unlocked.is_empty():
				hud.notice("%s unlocked" % unlocked.name)
				hud.log_line("[System] %s %d: %s. %s" % [Stats.TYPES[t].name, Run.type_points[t], unlocked.name,
					unlocked.text], Stats.TYPES[t].color)
				player.refresh_gear()
		"job":
			var j: JobData = _pick_options[i]
			Run.start_job(j)
			player.refresh_gear()
			hud.center("%s advanced to %s" % [Run.cls.display_name, j.display_name], 1.6)
			hud.log_line("[Notice] %s has advanced to %s. Congratulations!" % [Run.cls.display_name, j.display_name],
				Color("e0b54d"))
			_steps.push_front("job_skill")
		"gear":
			var g: GearItem = _pick_options[i]
			if g == null:
				_scrap(null)
			else:
				var keys := Run.slot_keys_for(g.data)
				if keys.size() > 1 and keys.all(func(k: String) -> bool: return Run.equipped(k) != null):
					_pending_gear = g
					var slot_options: Array = keys.duplicate()
					slot_options.append("")
					_start_pick("gear_slot", slot_options)
					return
				_equip(g, "")
		"gear_slot":
			var k: String = _pick_options[i]
			if k == "":
				_scrap(_pending_gear)
			else:
				_equip(_pending_gear, k)
			_pending_gear = null
		"compound_mat":
			var m: MaterialData = _pick_options[i]
			if m == null:
				_return_to = ""
			else:
				_pending_mat = m
				var keys: Array = Run.compound_targets()
				keys.append("")
				_start_pick("compound_target", keys)
				return
		"compound_target":
			var k: String = _pick_options[i]
			if k != "":
				var g := Run.equipped(k)
				var c := Run.compound(g, _pending_mat)
				Audio.play("ui_compose_success.wav")
				var what: String = c.stat + (" attack" if _pending_mat.is_element() else "")
				hud.notice("%s +%d on %s" % [what, c.value, g.title()])
				hud.log_line("[System] Compounded %s into %s: %s +%d." % [_pending_mat.display_name, g.title(), what, c.value],
					Color("e0b54d"))
			_pending_mat = null
			_open_compounder()
			return
		"shop":
			var o: Dictionary = _pick_options[i]
			if o.is_empty():
				_return_to = ""
			else:
				_shop.erase(o)
				Run.galder -= o.price
				Audio.play("etc_money.wav")
				if _buy(o):
					return
				_open_shop()
				return
		"port":
			var g: GearItem = _pick_options[i]
			Run.save_point(g)
			Audio.play("ui_unique_get.wav", -4.0)
			if g:
				hud.notice("%s sent home" % g.title())
				hud.log_line("[System] %s was sent to the Megalopolis warehouse." % g.title(), Color("e0b54d"))
			hud.log_line("[System] Progress saved.", Color("c9a4ff"))
			if phase == Phase.WON:
				_show_win_results()
				return
		"anvil":
			var k: String = _pick_options[i]
			if k != "":
				_refine(Run.equipped(k))
				return
			Audio.play_ambience(Run.region.field_ambience)
	_resume()


## After a pick: back to an open shop or compounder, or on to the next step.
func _resume() -> void:
	match _return_to:
		"shop":
			_open_shop()
		"compound":
			_open_compounder()
		"win":
			_return_to = ""
			_finish_win()
		_:
			_next_step()


func _equip(g: GearItem, slot_key: String) -> void:
	var old := Run.equip(g, slot_key)
	player.refresh_gear()
	Audio.play("etc_item1.wav", -2.0)
	hud.log_line("[System] Equipped %s." % g.title(), INFO)
	if old:
		_scrap(old)


func _scrap(g: GearItem) -> void:
	Run.galder += SCRAP_GALDER
	if g:
		hud.log_line("[System] Scrapped %s for %d Galder." % [g.title(), SCRAP_GALDER], MUTED)


func _open_compounder() -> void:
	var mats: Array = []
	for id: StringName in Run.materials:
		if Run.materials[id] > 0:
			mats.append(Run.material_info[id])
	mats.append(null)
	_start_pick("compound_mat", mats)


func _materials_text() -> String:
	var parts: PackedStringArray = []
	for id: StringName in Run.materials:
		if Run.materials[id] > 0:
			parts.append("%s %d" % [Run.material_info[id].display_name, Run.materials[id]])
	return ("Carrying: " + ", ".join(parts)) if parts.size() else "You carry no monster materials yet."


func _open_shop() -> void:
	var opts: Array = _shop.duplicate()
	opts.append({})
	_start_pick("shop", opts)


func _shop_entry(o: Dictionary) -> Dictionary:
	match o.kind:
		"gear":
			return _gear_option(o.item)
		"ore":
			return {"title": "%d %ss" % [o.count, Run.ORE_NAME], "text": "For refining at anvils."}
		"material":
			var m: MaterialData = o.material
			return {"title": "%d %s" % [o.count, m.display_name], "icon": m.icon(), "text": "Compounds %s." % m.describe()}
	return {"title": "Pink Potion", "text": "Recover %d%% of your HP." % roundi(o.heal * 100)}


## Gives a bought item. Returns true if a follow-up pick (an accessory slot) is open.
func _buy(o: Dictionary) -> bool:
	match o.kind:
		"gear":
			var g: GearItem = o.item
			var keys := Run.slot_keys_for(g.data)
			if keys.size() > 1 and keys.all(func(k: String) -> bool: return Run.equipped(k) != null):
				_pending_gear = g
				var slot_options: Array = keys.duplicate()
				slot_options.append("")
				_start_pick("gear_slot", slot_options)
				return true
			_equip(g, "")
		"ore":
			Run.ore += o.count
		"material":
			Run.add_material(o.material, o.count)
		"potion":
			Run.heal(int(Run.max_hp * o.heal))
			Audio.play("eff_healing1.wav", -4.0)
	return false


## The Portable Port: send one item home (anything not already stored), or just save.
func _open_port() -> void:
	var opts: Array = []
	for k in Run.EQUIP_SLOTS:
		var g := Run.equipped(k)
		if g and g.stored < 0 and g.data != Run.cls.start_weapon:
			opts.append(g)
	opts.append(null)
	_start_pick("port", opts)


func _open_anvil() -> void:
	var keys: Array = []
	for k in Run.EQUIP_SLOTS:
		var g := Run.equipped(k)
		if g and g.can_refine():
			keys.append(k)
	keys.append("")
	_start_pick("anvil", keys)


## One refine attempt at the anvil, then back to the anvil.
func _refine(g: GearItem) -> void:
	Audio.play("ui_refine_proceed.wav")
	var result := Run.try_refine(g)
	await get_tree().create_timer(0.5).timeout
	match result:
		"success":
			Audio.play("ui_refine_success.wav")
			hud.notice("Success!  %s" % g.title())
			hud.log_line("[System] Refining succeeded: %s." % g.title(), Color("e0b54d"))
		"drop":
			Audio.play("ui_refine_fail.wav")
			hud.notice("Failed. It dropped to +%d" % g.refine)
			hud.log_line("[System] Refining failed. %s lost a level." % g.title(), Color("f07a62"))
		_:
			Audio.play("ui_refine_fail.wav")
			hud.notice("Refining failed")
			hud.log_line("[System] Refining failed. The materials are gone.", Color("f07a62"))
	if is_instance_valid(player):
		player.refresh_gear()
	_open_anvil()


# ---------------------------------------------------------------- end of run

func _on_player_died() -> void:
	phase = Phase.DEAD
	var lost := Run.unsaved_changes()
	Run.finish(false)
	Audio.play("shchr002.wav")
	await get_tree().create_timer(1.2).timeout
	hud.log_line("[System] Connection lost.", Color("f07a62"))
	await hud.fade(0.85, 0.6)
	hud.log_line("[System] Rolling back server state...", Color("f07a62"))
	for t in lost:
		hud.log_line("[System] %s rolled back to its last save." % t, Color("f07a62"))
	hud.show_results(false)


func _win() -> void:
	phase = Phase.WON
	Run.won = true
	Run.shards += 2
	Run.finish(true)
	Audio.play("guild_battlewin.wav")
	hud.log_line("[Notice] %s cleared. The Harkon Shards resonate." % Run.region.display_name, Color("e0b54d"))
	await get_tree().create_timer(2.0).timeout
	if _legend:
		_return_to = "win"
		var g := _legend
		_legend = null
		_start_pick("gear", [g])
		return
	_finish_win()


func _finish_win() -> void:
	if Run.system_on(&"warehouse"):
		_open_port()
	else:
		_show_win_results()


## A region's boss (not the last) is down: a shard, then on to the next region.
func _region_cleared() -> void:
	Run.shards += 1
	Audio.play("guild_battlewin.wav", -4.0)
	var next: Run.RoomPlan = Run.plan[Run.depth + 1]
	hud.center("%s cleared\n%s ahead" % [Run.region.display_name, next.region.display_name], 2.0)
	hud.log_line("[Notice] %s cleared. A Harkon Shard hums. %s lies ahead." % [Run.region.display_name,
		next.region.display_name], Color("e0b54d"))


func _region_boss_name() -> String:
	for e in Run.region.enemies:
		if e.is_boss:
			return Run.monster_stats(e).get("name", String(e.id).capitalize())
	return "Boss"


func _show_win_results() -> void:
	await hud.fade(0.85, 0.6)
	hud.show_results(true)


func _process(delta: float) -> void:
	if phase in [Phase.FIGHT, Phase.REWARD, Phase.DOORS]:
		Run.time += delta
	if is_instance_valid(player):
		_shake = move_toward(_shake, 0.0, delta * 30.0)
		player.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	hud.refresh(player)


# ---------------------------------------------------------------- feedback

func _on_enemy_spawned(e: Enemy) -> void:
	if e.is_boss:
		_boss_name = e.display_name
		hud.show_boss(e.display_name, e.hp, e.max_hp)


func _on_enemy_died(e: Enemy) -> void:
	Audio.play("sdmon103.wav" if e.is_boss else "etc_mon_death.wav", -4.0)
	var before := Run.level
	var drop := Run.add_kill(e.rewards.exp, e.rewards.tm, e.rewards.galder, e.is_elite, e.is_boss,
		e.data.material, e.data.material_chance)
	if e.rewards.galder > 0:
		Audio.play("etc_money.wav", -10.0)
	if drop.ore > 0:
		hud.log_line("[System] Picked up %d %s%s." % [drop.ore, Run.ORE_NAME, "s" if drop.ore > 1 else ""], INFO)
	if Run.roll_card(e.data.id, e.is_elite, e.is_boss):
		var card_name := "%s Card" % e.display_name.trim_prefix("Elite ")
		if Profile.add_card(e.data.id):
			Audio.play("ui_card.wav")
			hud.notice("New card: " + card_name)
			hud.log_line("[System] %s added to Eugene's album!" % card_name, Color("e0b54d"))
		else:
			hud.log_line("[System] Picked up a %s." % card_name, INFO)
	if drop.material:
		var m: MaterialData = drop.material
		hud.log_line("[System] Picked up %s%s (%d / %d)." % ["%d " % drop.count if drop.count > 1 else "", m.display_name,
			Run.material_count(m), m.need], INFO)
	if Run.level > before:
		Audio.play("etc_levelup.wav", -2.0)
		hud.notice("Level up! Lv %d  ·  invest in a type after the fight" % Run.level)
	if e.is_boss:
		hud.hide_boss()
		if e.data.drop_item and Run.system_on(&"smithing") and randf() < e.data.drop_chance:
			_legend = GearItem.roll(e.data.drop_item, clampf(Run.stat("DA") / 60.0, 0.0, 1.0))
			Audio.play("ui_unique_get.wav")
			hud.log_line("[Notice] %s dropped the legendary %s!" % [e.display_name, _legend.title()], Color("e0b54d"))


func _on_hitstop(duration: float) -> void:
	_hitstop_id += 1
	var id := _hitstop_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _hitstop_id:
		Engine.time_scale = 1.0


func _on_damage_shown(at: Vector2, amount: int, color: Color, big: bool) -> void:
	_float_label(at, str(amount) + ("!" if big else ""), color, big)


func _float_label(at: Vector2, text: String, color: Color, big: bool) -> void:
	if room == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18 if big else 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 50
	l.position = at + Vector2(randf_range(-10, 4), 0)
	room.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.tween_callback(l.queue_free)
