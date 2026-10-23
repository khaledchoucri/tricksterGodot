class_name Game
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
	"compound", "compound", "shop", "shop", "dig", "dig", "heal", "galder", "shard"]
const CAMERA_MARGIN := 60
## MP restored on entering a room.
const ROOM_MP := 40
## The next card pick is a level-up's skill training (for its title).
var _skill_training := false
## Rewards that need a city system: reward -> Run.city.system_on() id.
## Gear is found from the first run (decided with the user, 2026-10-22: the loot loop starts at once).
const REWARD_SYSTEMS := {"anvil": &"smithing", "shop": &"smithing", "compound": &"compounding",
	"dig": &"drilling"}
## Misses at a Dig Site that wake an ambush.
const DIG_NOISE := 3
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
var _rune_from: EnemyData   # an Echo beaten in this room: offer its runes
var _boss_name := ""
var _ambush := false  # an ambush from a Dig Site is being fought
var _left_behind: Array[GearItem] = []  # a clear's finds that found no free shelf

@onready var hud: Hud = $Hud


func _ready() -> void:
	hud.picked.connect(_on_picked)
	hud.restart_requested.connect(_restart)
	Events.hitstop_requested.connect(_on_hitstop)
	Events.shake_requested.connect(func(amount: float) -> void: _shake = maxf(_shake, amount))
	Events.damage_shown.connect(_on_damage_shown)
	Events.text_shown.connect(func(at: Vector2, text: String, color: Color) -> void: _float_label(at, text, color, false))
	Events.loot_found.connect(func(text: String) -> void: hud.log_line("[System] " + text, INFO))
	Events.too_heavy.connect(func(item: String, left: int) -> void:
		hud.log_line("[System] Too heavy to carry: %d %s left behind (%d / %d)." % [left, item,
			Run.purse.carried_weight(), Run.purse.carry_limit()], Color("f07a62")))
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_died.connect(_on_enemy_died)
	Events.boss_health_changed.connect(_show_boss)
	Events.boss_intro.connect(hud.show_boss_intro)
	Events.boss_spoke.connect(func(text: String) -> void: hud.log_line("[%s] %s" % [_boss_name, text], Color("e0b54d")))
	Events.player_died.connect(_on_player_died)
	Events.revived.connect(func() -> void:
		hud.log_line("[System] You refused to log out.", Color("c9a4ff"))
		hud.notice("Saved from the rollback"))
	if not FileAccess.file_exists(Assets.actor_json(Run.chosen_class().actor)) \
			or not FileAccess.file_exists(Assets.map_dir("map_fd11d") + "map.json"):
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
	var plan := Run.route.current_room()
	room = Room.new()
	add_child(room)
	if not room.build(plan.data):
		phase = Phase.MISSING
		hud.center("Map %s is missing.\nRun tools/setup_assets.py." % plan.data.map)
		return
	room.cleared.connect(_on_room_cleared)
	room.door_entered.connect(_on_door_entered)
	_spawn_player(room.entry)
	Run.gain_mp(ROOM_MP + Run.city.room_mp_bonus())
	if Run.mod("room_heal%") > 0.0:
		Run.heal(int(Run.max_hp * (Run.mod("room_heal%") / 100.0)))
	if plan.rest:
		Audio.play_music(plan.rest.music)
		Audio.play_ambience(plan.rest.ambience)
	else:
		Audio.play_music(Run.route.region.boss_music if plan.boss else Run.route.region.field_music)
		Audio.play_ambience(Run.route.region.boss_ambience if plan.boss else Run.route.region.field_ambience)
	var heat := ServerSettings.heat()
	hud.set_room("%s  ·  %d / %d%s" % [plan.data.display_name, Run.route.depth + 1, Run.route.plan.size(),
		"  ·  Heat %d" % heat if heat > 0 else ""])
	hud.hide_boss()
	await hud.fade(0.0, 0.3)
	if plan.rest:
		_arrive_at_rest(plan)
		return
	if Run.city.bag_here():
		_place_lost_bag()
	if plan.boss:
		_boss_name = _region_boss_name()
	var title := _region_boss_name() if plan.boss else plan.data.display_name
	if plan.local_depth == 0 and not plan.boss:
		title = "%s\n%s" % [Run.route.region.display_name, title]
	if plan.elite:
		title += "\nElite monsters ahead"
	hud.center(title, 1.2)
	await get_tree().create_timer(0.9).timeout
	if room and room.is_inside_tree():
		phase = Phase.FIGHT
		room.start_encounter(Run.route.local_depth(), plan.elite, plan.boss)


## The lost bag of the last death lies in this room.
func _place_lost_bag() -> void:
	var bag := LostBag.new()
	bag.room = room
	bag.position = room.nearest_reachable(Vector2(float(Profile.lost_bag.x), float(Profile.lost_bag.y)))
	bag.picked_up.connect(func(names: Array[String]) -> void:
		Audio.play("etc_item1.wav")
		hud.log_line("[System] You found your lost bag: %s went back on your shelves." % ", ".join(names), Color("e0b54d")))
	room.world.add_child(bag)
	hud.log_line("[System] Your lost bag is in this room.", Color("f0c070"))


## A rest stop: nothing to fight. Heal, meet its people, and the way on is open.
func _arrive_at_rest(plan: RoomPlan) -> void:
	var stop := RestStop.new()
	room.add_child(stop)
	stop.arrive(plan.rest, room, player, hud)
	hud.center("%s\nRest stop" % plan.data.display_name, 1.2)
	phase = Phase.REWARD
	_open_doors()


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
	if _ambush:
		_ambush = false
		phase = Phase.REWARD
		hud.log_line("[System] The Dig Site is quiet again.", Color("94a7b2"))
		_next_step()
		return
	if Run.route.final_boss():
		_win()
		return
	phase = Phase.REWARD
	Audio.play("etc_monq_complete.wav", -4.0)
	if Run.mod("clear_heal%") > 0.0:
		Run.heal(int(Run.max_hp * (Run.mod("clear_heal%") / 100.0)))
	hud.log_line("[System] Room cleared.", Color("94a7b2"))
	var cleared_room := room
	await get_tree().create_timer(0.6).timeout
	if room != cleared_room:
		return  # a different room loaded while we waited
	_steps.clear()
	if Run.route.current_room().boss:
		_region_cleared()
	if _legend:
		_steps.append("legend")
	if _rune_from:
		_steps.append("rune")
	_steps.append(reward_here)
	if Run.route.current_room().elite:
		_steps.append("gear")
	if Run.route.local_depth() == Run.route.region.port_depth or Run.route.current_room().boss:
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
			var n := 3 + int(Run.mod("card_choices"))
			var opts := Run.deck.card_offers(n, reward == "upgrade")
			if opts.is_empty():
				opts = Run.deck.card_offers(n, reward != "upgrade")
			if not opts.is_empty():
				_start_pick("card", opts)
				return
		"skill_level":
			# Trickster levels skills with the TM points play earns; here each
			# character level also trains one skill you have.
			var opts := Run.deck.card_offers(3, true)
			if not opts.is_empty():
				_skill_training = true
				_start_pick("card", opts)
				return
		"gear":
			var offers := Run.gear.gear_offers(1 + int(Run.mod("gear_choices")))
			if not offers.is_empty():
				Audio.play("etc_item1.wav", -4.0)
				_start_pick("gear", offers)
				return
		"anvil":
			Run.purse.add_ore(ANVIL_ORE)
			hud.log_line("[System] The smith left %d %ss by the anvil." % [ANVIL_ORE, Run.purse.ORE_NAME], INFO)
			Audio.play_ambience("bgs_blacksmith.wav")
			_open_anvil()
			return
		"compound":
			_return_to = "compound"
			_open_compounder()
			return
		"shop":
			_shop = Run.gear.shop_offers()
			_return_to = "shop"
			Audio.play("ui_card.wav")
			_open_shop()
			return
		"port":
			_open_port()
			return
		"dig":
			var d := Run.purse.drill()
			if d:
				Audio.play_ambience("")
				hud.drill.start(d, Run.stat("DA") / 400.0)
				get_tree().paused = true
				var result: Array = await hud.drill.finished
				get_tree().paused = false
				Audio.play_ambience(Run.route.region.field_ambience)
				_dug(result[0], result[1])
				return
		"rune":
			var options: Array = _rune_from.runes.duplicate()
			_rune_from = null
			options.append(null)
			_start_pick("rune", options)
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
			var g := Run.rng.randi_range(120, 220)
			var o := Run.rng.randi_range(1, 2)
			Run.purse.galder += g
			Run.purse.add_ore(o)
			Audio.play("etc_money.wav")
			hud.notice("+%d Galder  ·  +%d %s" % [g, o, Run.purse.ORE_NAME])
		"shard":
			Run.purse.shards += 1
			Audio.play("ui_unique_get.wav", -4.0)
			hud.notice("Harkon Shard found")
			hud.log_line("[System] A Harkon Shard hums faintly in your inventory.", Color("c9a4ff"))
	_next_step()


func _open_doors() -> void:
	phase = Phase.DOORS
	var rewards: Array[String] = []
	var next: RoomPlan = Run.route.plan[mini(Run.route.depth + 1, Run.route.plan.size() - 1)]
	if next.boss:
		rewards = ["boss"]
	elif next.rest:
		rewards = ["rest"]  # a rest stop is never cleared, so its door carries no reward
	else:
		var pool := REWARD_POOL.filter(func(r: String) -> bool:
			if r == "heal" and ServerSettings.hardcore():
				return false
			return not REWARD_SYSTEMS.has(r) or Run.city.system_on(REWARD_SYSTEMS[r]))
		Run.shuffle(pool)
		rewards.append(pool[0])
		for r: String in pool:
			if r != pool[0]:
				rewards.append(r)
				break
	var features: Array[StringName] = []
	var pool: Array[EnemyData] = []
	for e in next.region.enemies:
		if not e.is_boss and e.min_depth <= next.local_depth:
			pool.append(e)
	for r in rewards:
		features.append(&"" if r == "boss" or pool.is_empty() else pool[Run.rng.randi() % pool.size()].id)
	room.open_doors(rewards, features)
	Audio.play("etc_warpzone.wav", -6.0)
	hud.log_line("[System] Exits opened.", Color("94a7b2"))


func _on_door_entered(reward: String, feature: StringName) -> void:
	Audio.play("etc_warp.wav")
	Run.route.depth += 1
	Run.route.current_room().feature = feature
	reward_here = "card" if reward == "boss" else reward
	await hud.fade(1.0, 0.25)
	_load_room()


# ---------------------------------------------------------------- picks

## Picks pause the game. kind "card": CardData options. "replace": skill
## slot indices, -1 keeps the current skills. "type": type keys.
## "gear": GearItems, then null to leave it. "gear_slot": accessory
## slot keys, "" keeps both. "anvil": equipment slot keys to refine, "" leaves.
func _start_pick(kind: String, options: Array) -> void:
	_pick_kind = kind
	_pick_options = options
	var shown: Array[Dictionary] = []
	var title := ""
	match kind:
		"card":
			for card: CardData in options:
				var lvl := Run.deck.card_level(card.id)
				var tag := ("New skill" if card.is_skill() else "New talent") if lvl == 0 else "Lv %d → %d" % [lvl, lvl + 1]
				var text := card.describe(lvl + 1)
				if lvl == 0 and card.upgrades != &"":
					var base := Run.deck.card(card.upgrades)
					text = card.describe(mini(Run.deck.card_level(base.id), Run.deck.card_cap(card.id)))
					tag = "Upgrade"
					text += "
Replaces %s and keeps its Lv %d." % [base.display_name, Run.deck.card_level(base.id)]
				if lvl == 0 and card.form_actor != "":
					text += _beast_warning(card.id)
				shown.append({"title": card.display_name, "tag": tag, "text": text})
			title = "Level %d  ·  Train a skill" % (Run.level - Run.pending_levels) if _skill_training else "Choose a %s skill card" % Run.job.display_name
			_skill_training = false
			Audio.play("ui_card.wav")
		"replace":
			for slot: int in options:
				if slot < 0:
					shown.append({"title": "Keep my skills", "tag": "", "text": "Skip %s." % _pending_skill.display_name, "cancel": true})
				else:
					var old := Run.deck.card(Run.deck.loadout[slot])
					var tag := "[%s]" % Hud.SLOT_KEYS[slot]
					if not Run.form_allows(old.id):
						tag += "  unusable in %s" % Run.deck.card(Run.form).display_name
					shown.append({"title": "Replace %s" % old.display_name, "tag": tag,
						"text": "%s takes this slot (Lv %d is lost)." % [_pending_skill.display_name, Run.deck.card_level(old.id)]})
			title = "Skill slots are full"
		"type":
			for t: String in options:
				shown.append(_type_option(t))
			title = "Level %d  ·  Invest in a type" % (Run.level - Run.pending_levels)
			Audio.play("etc_levelup.wav")
		"gear":
			for g: GearItem in options:
				shown.append(_gear_option(g))
			shown.append({"title": "Leave it", "tag": "", "text": "Scrap it for %d Galder." % SCRAP_GALDER, "cancel": true})
			_pick_options = options + [null]
			title = "Equipment found"
		"gear_slot":
			for k: String in options:
				if k == "":
					shown.append({"title": "Keep my accessories", "tag": "", "cancel": true,
						"text": "Scrap %s for %d Galder." % [_pending_gear.title(), SCRAP_GALDER]})
				else:
					var old := Run.gear.equipped(k)
					shown.append({"title": "Replace %s" % old.title(), "tag": "", "icon": old.data.icon(),
						"text": _pending_gear.summary(old)})
			title = "Both accessory slots are full"
		"anvil":
			for k: String in options:
				if k == "":
					shown.append({"title": "Leave the anvil", "tag": "", "cancel": true,
						"text": "%d %ss and %d Galder left." % [Run.purse.ore, Run.purse.ORE_NAME, Run.purse.galder]})
					continue
				var g := Run.gear.equipped(k)
				var cost := g.refine_cost()
				var text := "%d%% chance  ·  %d %s%s, %d Galder" % [roundi(Run.gear.refine_chance(g) * 100), cost.ore,
					Run.purse.ORE_NAME, "s" if cost.ore != 1 else "", cost.galder]
				if g.refine >= 4:
					text += "  ·  failing may lose a level"
				shown.append({"title": "%s  →  +%d" % [g.title(), g.refine + 1], "tag": g.data.refine_stat,
					"icon": g.data.icon(), "text": text, "disabled": not Run.gear.can_afford_refine(g)})
			title = "Anvil  ·  refine your gear"
		"compound_mat":
			for m: MaterialData in options:
				if m == null:
					shown.append({"title": "Leave the Compounder", "tag": "", "text": _materials_text(), "cancel": true})
					continue
				var have := Run.purse.material_count(m)
				shown.append({"title": m.display_name, "tag": "%d / %d" % [have, m.need], "icon": m.icon(),
					"text": "Compounds %s into a free slot." % m.describe(),
					"disabled": have < m.need or Run.gear.compound_targets().is_empty()})
			title = "Compounder  ·  choose a material" if Run.gear.compound_targets().size() else "Compounder  ·  no free compound slots"
		"compound_target":
			for k: String in options:
				if k == "":
					shown.append({"title": "Back", "tag": "", "text": "Choose another material.", "cancel": true})
					continue
				var g := Run.gear.equipped(k)
				shown.append({"title": g.title(), "tag": "%d free slot%s" % [g.free_slots(), "s" if g.free_slots() > 1 else ""],
					"icon": g.data.icon(), "text": g.summary()})
			title = "Compound %s into..." % _pending_mat.display_name
		"shop":
			for o: Dictionary in options:
				if o.is_empty():
					shown.append({"title": "Leave the shop", "tag": "", "text": "%d Galder left." % Run.purse.galder, "cancel": true})
					continue
				var entry := _shop_entry(o)
				entry.tag = "%d G" % o.price
				entry.disabled = Run.purse.galder < o.price
				shown.append(entry)
			title = "Shop  ·  %d Galder" % Run.purse.galder
		"port":
			var full := Profile.warehouse_full()
			for g: GearItem in options:
				if g == null:
					shown.append({"title": "Go on", "tag": "", "cancel": true,
						"text": "What you wear stays at stake: a death leaves it in a lost bag."})
					continue
				shown.append({"title": "Send %s home" % g.title(), "tag": "On a shelf" if g.stored >= 0 else g.data.slot_name(), "icon": g.data.icon(),
					"text": g.summary() + ("
The warehouse is full." if full else "
Safe on a shelf, refines and compounds included; you stop wearing it."),
					"disabled": full and g.stored < 0})
			title = "Portable Port  ·  save your progress"
		"make_room":
			var keep: GearItem = _left_behind[0]
			for i: Variant in options:
				if i == null:
					shown.append({"title": "Log out", "tag": "", "cancel": true, "text": "Leave %s behind." % ", ".join(
						_left_behind.map(func(x: GearItem) -> String: return x.title()))})
					continue
				var stored := GearItem.from_dict(Profile.warehouse[i], Run.gear.item_by_id)
				shown.append({"title": "Throw away %s" % (stored.title() if stored else "(unknown item)"),
					"tag": "Worn" if Profile.worn_in(i) != "" else (stored.data.slot_name() if stored else ""),
					"icon": stored.data.icon() if stored else null, "text": "Frees its shelf for %s." % keep.title()})
			title = "Your shelves are full  ·  make room for %s" % keep.title()
		"rune":
			for c: CardData in options:
				if c == null:
					shown.append({"title": "Keep %s" % (Run.deck.rune.display_name if Run.deck.rune else "nothing"), "tag": "", "cancel": true,
						"text": "Leave the rune where it fell."})
					continue
				shown.append({"title": c.display_name, "tag": "Rune · Lv %d · [F]" % (1 + 2 * Run.route.region_index()),
					"text": c.describe(1 + 2 * Run.route.region_index()) + ("\nReplaces %s." % Run.deck.rune.display_name if Run.deck.rune else "")})
			title = "A sky-blue rune  ·  borrow a skill"
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
	for k in Run.gear.slot_keys_for(g.data):
		current = Run.gear.equipped(k)
		if current == null:
			break
	var text := g.summary(current)
	var tag := g.data.slot_name()
	if g.data.family != "":
		tag += " · " + g.data.family
	if current:
		tag += " · replaces " + current.title()
	return {"title": g.title(), "tag": tag, "text": text, "icon": g.data.icon()}


## A beast form's offer names the slotted skills it would shut off.
func _beast_warning(form: StringName) -> String:
	var lost: Array[String] = []
	for id: StringName in Run.deck.loadout:
		if id != &"" and not Run.form_allows(id, form):
			lost.append(Run.deck.card(id).display_name)
	if lost.is_empty():
		return "
You can't turn back."
	return "
You can't turn back. Stops working: %s." % ", ".join(lost)


func _on_picked(i: int) -> void:
	get_tree().paused = false
	Audio.play("ui_btn_ok.wav")
	match _pick_kind:
		"card":
			var card: CardData = _pick_options[i]
			if card.is_skill() and Run.deck.card_level(card.id) == 0 and card.upgrades == &"" and Run.deck.free_slot() < 0:
				_pending_skill = card
				_start_pick("replace", [0, 1, 2, -1])
				return
			var was_beast := Run.form != &""
			Run.deck.add_card(card.id)
			hud.log_line("[System] %s learned (Lv %d)." % [card.display_name, Run.deck.card_level(card.id)], INFO)
			if Run.form != &"" and not was_beast:
				player.become_beast()
		"replace":
			var slot: int = _pick_options[i]
			if slot >= 0:
				Run.deck.add_card(_pending_skill.id, slot)
				hud.log_line("[System] %s learned." % _pending_skill.display_name, INFO)
			_pending_skill = null
		"type":
			var t: String = _pick_options[i]
			var unlocked := Run.apply_type(t)
			_steps.push_front("skill_level")
			if not unlocked.is_empty():
				hud.notice("%s unlocked" % unlocked.name)
				hud.log_line("[System] %s %d: %s. %s" % [Stats.TYPES[t].name, Run.type_points[t], unlocked.name,
					unlocked.text], Stats.TYPES[t].color)
				player.refresh_gear()
		"gear":
			var g: GearItem = _pick_options[i]
			if g == null:
				_scrap(null)
			else:
				var keys := Run.gear.slot_keys_for(g.data)
				if keys.size() > 1 and keys.all(func(k: String) -> bool: return Run.gear.equipped(k) != null):
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
				var keys: Array = Run.gear.compound_targets()
				keys.append("")
				_start_pick("compound_target", keys)
				return
		"compound_target":
			var k: String = _pick_options[i]
			if k != "":
				var g := Run.gear.equipped(k)
				var c := Run.gear.compound(g, _pending_mat)
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
				Run.purse.galder -= o.price
				Audio.play("etc_money.wav")
				if _buy(o):
					return
				_open_shop()
				return
		"port":
			var g: GearItem = _pick_options[i]
			if g and Run.city.bank(g):
				Audio.play("ui_unique_get.wav", -4.0)
				hud.notice("%s sent home" % g.title())
				hud.log_line("[System] %s is safe in the Megalopolis warehouse." % g.title(), Color("e0b54d"))
				player.dress()
				player.refresh_gear()
		"make_room":
			if _pick_options[i] == null:
				_left_behind.clear()
			else:
				Profile.discard_item(int(_pick_options[i]))
				Run.city.save_point(_left_behind.pop_front())
			_make_room()
			return
		"rune":
			var c: CardData = _pick_options[i]
			if c:
				Run.deck.take_rune(c)
				Audio.play("ui_unique_get.wav", -4.0)
				hud.log_line("[System] The rune teaches you %s. Press F to cast it." % c.display_name, Color("8fd8ff"))
		"anvil":
			var k: String = _pick_options[i]
			if k != "":
				_refine(Run.gear.equipped(k))
				return
			Audio.play_ambience(Run.route.region.field_ambience)
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
	if not Run.gear.can_equip(g):
		hud.log_line("[System] A gun needs both hands: no shield while you carry one.", MUTED)
		_scrap(g)
		return
	var old := Run.gear.equip(g, slot_key)
	player.refresh_gear()
	Audio.play("etc_item1.wav", -2.0)
	hud.log_line("[System] Equipped %s." % g.title(), INFO)
	if old:
		_scrap(old)
	for d in Run.gear.displaced:
		hud.log_line("[System] A gun needs both hands: %s put away." % d.title(), MUTED)
		_scrap(d)


func _scrap(g: GearItem) -> void:
	Run.purse.galder += SCRAP_GALDER
	if g:
		hud.log_line("[System] Scrapped %s for %d Galder." % [g.title(), SCRAP_GALDER], MUTED)


func _open_compounder() -> void:
	var mats: Array = []
	for id: StringName in Run.purse.materials:
		var m: MaterialData = Run.purse.material_info[id]
		if Run.purse.materials[id] >= m.need:
			mats.append(m)
	mats.sort_custom(func(a: MaterialData, b: MaterialData) -> bool: return a.display_name < b.display_name)
	mats.append(null)
	_start_pick("compound_mat", mats)


func _materials_text() -> String:
	var parts: PackedStringArray = []
	for id: StringName in Run.purse.materials:
		var m: MaterialData = Run.purse.material_info[id]
		if Run.purse.materials[id] > 0 and Run.purse.materials[id] < m.need:
			parts.append("%s %d/%d" % [m.display_name, Run.purse.materials[id], m.need])
	if parts.is_empty():
		return "Nothing else in your pack." if Run.purse.materials.size() else "You carry no monster materials yet."
	return "Not enough yet: " + ", ".join(parts)


func _open_shop() -> void:
	var opts: Array = _shop.duplicate()
	opts.append({})
	_start_pick("shop", opts)


func _shop_entry(o: Dictionary) -> Dictionary:
	match o.kind:
		"gear":
			return _gear_option(o.item)
		"ore":
			return {"title": "%d %ss" % [o.count, Run.purse.ORE_NAME], "text": "For refining at anvils."}
		"material":
			var m: MaterialData = o.material
			return {"title": "%d %s" % [o.count, m.display_name], "icon": m.icon(), "text": "Compounds %s." % m.describe()}
	return {"title": "Pink Potion", "text": "Recover %d%% of your HP." % roundi(o.heal * 100)}


## Gives a bought item. Returns true if a follow-up pick (an accessory slot) is open.
func _buy(o: Dictionary) -> bool:
	match o.kind:
		"gear":
			var g: GearItem = o.item
			var keys := Run.gear.slot_keys_for(g.data)
			if keys.size() > 1 and keys.all(func(k: String) -> bool: return Run.gear.equipped(k) != null):
				_pending_gear = g
				var slot_options: Array = keys.duplicate()
				slot_options.append("")
				_start_pick("gear_slot", slot_options)
				return true
			_equip(g, "")
		"ore":
			Run.purse.add_ore(o.count)
		"material":
			Run.purse.add_material(o.material, o.count)
		"potion":
			Run.heal(int(Run.max_hp * o.heal))
			Audio.play("eff_healing1.wav", -4.0)
	return false


## The Portable Port: send one item home (anything not already stored), or just save.
func _open_port() -> void:
	var opts: Array = []
	for k in Run.gear.EQUIP_SLOTS:
		var g := Run.gear.equipped(k)
		if g and not (g.stored < 0 and g.data == Run.cls.start_weapon):
			opts.append(g)
	opts.append(null)
	_start_pick("port", opts)


## Hands out what the dig brought up, or wakes an ambush.
func _dug(depth: int, misses: int) -> void:
	var r := Run.purse.dig_rewards(depth)
	var found: PackedStringArray = []
	if r.ore > 0:
		Run.purse.add_ore(r.ore)
		found.append("%d %s%s" % [r.ore, Run.purse.ORE_NAME, "s" if r.ore > 1 else ""])
	if r.material:
		Run.purse.add_material(r.material, r.count)
		found.append("%d %s" % [r.count, r.material.display_name])
	if r.shard > 0:
		Run.purse.shards += r.shard
		found.append("a Harkon Shard")
	hud.log_line("[System] Dug %d deep: %s." % [depth, ", ".join(found) if found.size() else "nothing but dirt"], INFO)
	if found.size():
		hud.notice("Dug up " + ", ".join(found))
	if misses >= DIG_NOISE:
		_start_ambush()
		return
	if r.gear:
		Audio.play("etc_item1.wav", -4.0)
		_start_pick("gear", [r.gear])
		return
	_next_step()


## Too much noise at a Dig Site: something climbs out.
func _start_ambush() -> void:
	_ambush = true
	phase = Phase.FIGHT
	Audio.play("snd_ui_crazydrill_boom.wav")
	Events.shake_requested.emit(6.0)
	hud.notice("You woke something up!")
	hud.log_line("[System] The noise woke the monsters below!", Color("f07a62"))
	var wave := room._make_waves(Run.route.local_depth(), true)
	room.waves = [wave[wave.size() - 1]]
	room.wave = -1
	room._cleared = false
	room._next_wave()


func _open_anvil() -> void:
	var keys: Array = []
	for k in Run.gear.EQUIP_SLOTS:
		var g := Run.gear.equipped(k)
		if g and g.can_refine():
			keys.append(k)
	keys.append("")
	_start_pick("anvil", keys)


## One refine attempt at the anvil, then back to the anvil.
func _refine(g: GearItem) -> void:
	Audio.play("ui_refine_proceed.wav")
	var result := Run.gear.try_refine(g)
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

## A terminal outcome is accepted once, before presentation can yield.
func _on_player_died() -> void:
	if phase in [Phase.DEAD, Phase.WON] or Run.city.finished:
		return
	phase = Phase.DEAD
	var fall := Run.city.drop_bag(player.global_position)
	var bagged: Array[String] = fall.bag
	var saved: Array[String] = fall.home
	Run.last_bag = bagged
	Run.last_saved = saved
	Run.city.finish(false)
	_present_death(saved, bagged)


## Presentation follows settlement; it cannot accept another outcome while waiting.
func _present_death(saved: Array[String], bagged: Array[String]) -> void:
	Audio.play("shchr002.wav")
	await get_tree().create_timer(1.2).timeout
	hud.log_line("[System] Connection lost.", Color("f07a62"))
	await hud.fade(0.85, 0.6)
	hud.log_line("[System] Rolling back server state...", Color("f07a62"))
	if not saved.is_empty():
		hud.log_line("[System] You carried out %s (WT): back on your shelves." % ", ".join(saved), Color("a8d8da"))
	if not bagged.is_empty():
		hud.log_line("[System] Your gear fell in a lost bag here: %s. Reach this room again to pick it up."
			% ", ".join(bagged), Color("f07a62"))
	hud.show_results(false)


## Reading: death wins if HP is already zero when victory arrives (including a double KO).
## Once a live victory settles, later damage cannot convert it into a rollback.
func _win() -> void:
	if phase in [Phase.DEAD, Phase.WON] or Run.city.finished:
		return
	if Run.hp <= 0:
		_on_player_died()
		return
	phase = Phase.WON
	Run.won = true
	Run.purse.shards += 2
	Run.city.finish(true)
	_present_win()


## The victory presentation starts only after its rewards have settled.
func _present_win() -> void:
	Audio.play("guild_battlewin.wav")
	hud.log_line("[Notice] %s cleared. The Harkon Shards resonate." % Run.route.region.display_name, Color("e0b54d"))
	await get_tree().create_timer(2.0).timeout
	if _legend:
		_return_to = "win"
		var g := _legend
		_legend = null
		_start_pick("gear", [g])
		return
	_finish_win()


## A clear: everything you wear goes home; finds that don't fit ask for room on the shelves.
func _finish_win() -> void:
	_left_behind = Run.city.bring_home()
	hud.log_line("[System] You logged out with everything you wore.", Color("e0b54d"))
	_make_room()


## Full shelves: throw away a stored item to keep the next find, or log out without the rest.
func _make_room() -> void:
	if _left_behind.is_empty():
		_show_win_results()
		return
	var shelves: Array = []
	for i in Profile.warehouse.size():
		shelves.append(i)
	shelves.append(null)
	_start_pick("make_room", shelves)


## A region's boss (not the last) is down: a shard, then on to the next region.
func _region_cleared() -> void:
	Run.purse.shards += 1
	Audio.play("guild_battlewin.wav", -4.0)
	var next: RoomPlan = Run.route.plan[Run.route.depth + 1]
	hud.center("%s cleared\n%s ahead" % [Run.route.region.display_name, next.region.display_name], 2.0)
	hud.log_line("[Notice] %s cleared. A Harkon Shard hums. %s lies ahead." % [Run.route.region.display_name,
		next.region.display_name], Color("e0b54d"))


## The boss's HP on the HUD, in its bars.
func _show_boss(e: Enemy) -> void:
	hud.show_boss(e.display_name, e.hp, e.max_hp, (e as Boss).bars if e is Boss else 1)


func _region_boss_name() -> String:
	for e in Run.route.region.enemies:
		if e.is_boss:
			return Run.formulas.monster_name(e)
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
		_show_boss(e)


func _on_enemy_died(e: Enemy) -> void:
	Audio.play("sdmon103.wav" if e.is_boss else "etc_mon_death.wav", -4.0)
	var before := Run.level
	var drop := Run.purse.add_kill(e.rewards.exp, e.rewards.tm, e.rewards.galder, e.is_elite, e.is_boss,
		e.data.material, e.data.material_chance)
	if e.rewards.galder > 0:
		Audio.play("etc_money.wav", -10.0)
	if drop.ore > 0:
		hud.log_line("[System] Picked up %d %s%s." % [drop.ore, Run.purse.ORE_NAME, "s" if drop.ore > 1 else ""], INFO)
	if not e.data.echo and Run.purse.roll_card(e.data.id, e.is_elite, e.is_boss):
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
			Run.purse.material_count(m), m.need], INFO)
	if Run.level > before:
		Audio.play("etc_levelup.wav", -2.0)
		hud.notice("Level up! Lv %d  ·  invest in a type after the fight" % Run.level)
	if e.data.echo:
		_rune_from = e.data
		hud.log_line("[System] The %s fades. A sky-blue rune is left behind." % e.display_name, Color("8fd8ff"))
	if e.is_boss:
		hud.hide_boss()
		if e.data.drop_item and Run.rng.randf() < e.data.drop_chance:
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
