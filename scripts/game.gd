extends Node2D
## Runs one Coral Beach expedition: loads rooms cut from the original maps,
## hands out rewards (skill cards, gear, anvils, the job change) and
## level-ups, and ends in a rollback or a clear, which banks the run into the
## Profile and returns to Megalopolis (scenes/hub.tscn). Presents combat
## feedback (hit-stop, shake, damage numbers) announced on the Events bus.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUB_SCENE := "res://scenes/hub.tscn"
const REWARD_POOL: Array[String] = ["card", "card", "upgrade", "gear", "gear", "anvil", "heal", "galder", "shard"]
const CAMERA_MARGIN := 60
## MP restored on entering a room.
const ROOM_MP := 40
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
	Events.boss_spoke.connect(func(text: String) -> void: hud.log_line("[Real Golden Mole] " + text, Color("e0b54d")))
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
	Audio.play_music(Run.region.boss_music if plan.boss else Run.region.field_music)
	Audio.play_ambience(Run.region.boss_ambience if plan.boss else Run.region.field_ambience)
	hud.set_room("%s  ·  %d / %d" % [plan.data.display_name, Run.depth + 1, Run.plan.size()])
	hud.hide_boss()
	await hud.fade(0.0, 0.3)
	var title := "Real Golden Mole" if plan.boss else plan.data.display_name
	if Run.depth == Run.region.job_change_depth:
		title += "\n%s's trial: clear it to change job" % Run.job.display_name
	elif plan.elite:
		title += "\nElite monsters ahead"
	hud.center(title, 1.2)
	await get_tree().create_timer(0.9).timeout
	if room and room.is_inside_tree():
		phase = Phase.FIGHT
		room.start_encounter(Run.depth, plan.elite, plan.boss)


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
	if Run.current_room().boss:
		_win()
		return
	phase = Phase.REWARD
	Audio.play("etc_monq_complete.wav", -4.0)
	hud.log_line("[System] Room cleared.", Color("94a7b2"))
	var cleared_room := room
	await get_tree().create_timer(0.6).timeout
	if room != cleared_room:
		return  # a different room loaded while we waited
	_steps.clear()
	if Run.job_change_due():
		_steps.append("job")
	_steps.append(reward_here)
	if Run.current_room().elite:
		_steps.append("gear")
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
			var opts := Run.card_offers(3, reward == "upgrade")
			if opts.is_empty():
				opts = Run.card_offers(3, reward != "upgrade")
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
	if Run.depth + 1 >= Run.plan.size() - 1:
		rewards = ["boss"]
	else:
		var pool := REWARD_POOL.duplicate()
		pool.shuffle()
		rewards.append(pool[0])
		for r in pool:
			if r != pool[0]:
				rewards.append(r)
				break
	room.open_doors(rewards)
	Audio.play("etc_warpzone.wav", -6.0)
	hud.log_line("[System] Exits opened.", Color("94a7b2"))


func _on_door_entered(reward: String) -> void:
	Audio.play("etc_warp.wav")
	Run.depth += 1
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
					var old := Run.region.card(Run.loadout[slot])
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
				shown.append({"title": j.display_name, "tag": "%s job" % ["1st", "2nd", "3rd"][j.tier - 1], "text": text})
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
		"anvil":
			var k: String = _pick_options[i]
			if k != "":
				_refine(Run.equipped(k))
				return
			Audio.play_ambience(Run.region.field_ambience)
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
	Run.finish(false)
	Audio.play("shchr002.wav")
	await get_tree().create_timer(1.2).timeout
	hud.log_line("[System] Connection lost.", Color("f07a62"))
	await hud.fade(0.85, 0.6)
	hud.log_line("[System] Rolling back server state...", Color("f07a62"))
	hud.show_results(false)


func _win() -> void:
	phase = Phase.WON
	Run.won = true
	Run.shards += 2
	Run.finish(true)
	Audio.play("guild_battlewin.wav")
	hud.log_line("[Notice] Coral Beach cleared. The Harkon Shards resonate.", Color("e0b54d"))
	await get_tree().create_timer(2.0).timeout
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
		hud.show_boss(e.display_name, e.hp, e.max_hp)


func _on_enemy_died(e: Enemy) -> void:
	Audio.play("sdmon103.wav" if e.is_boss else "etc_mon_death.wav", -4.0)
	var before := Run.level
	var ore := Run.add_kill(e.rewards.exp, e.rewards.tm, e.rewards.galder, e.is_elite, e.is_boss)
	if e.rewards.galder > 0:
		Audio.play("etc_money.wav", -10.0)
	if ore > 0:
		hud.log_line("[System] Picked up %d %s%s." % [ore, Run.ORE_NAME, "s" if ore > 1 else ""], INFO)
	if Run.level > before:
		Audio.play("etc_levelup.wav", -2.0)
		hud.notice("Level up! Lv %d  ·  invest in a type after the fight" % Run.level)
	if e.is_boss:
		hud.hide_boss()


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
