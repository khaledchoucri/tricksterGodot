extends Node
## Autopilot playtest: a bot plays whole Coral Beach runs and reports how
## they went (depth reached, level, job, time, damage taken per room, gear,
## type points). Used to check balance after changes.
##
## Run it as fast as the CPU allows (fixed frame time):
##   godot --headless --fixed-fps 60 res://tests/playtest.tscn -- runs=5 build=power
## seed=N makes the runs reproducible: run i plays seed N + i, for the game and the bot alike.
## build: power | magic | sense | charm | mixed (how the bot spends type points)

const MOVES: Array[String] = ["move_left", "move_right", "move_up", "move_down"]
## Game seconds a room may take before the bot gives up on it.
const ROOM_LIMIT := 150.0
## Seconds a whole run may take, menus included, before the bot gives up (three regions of rooms
## take up to about 30 minutes; a capped run is reported as such, not as a death).
const RUN_LIMIT := 3600.0
## Rooms per band in the combat-feel report.
const FEEL_BAND := 4

var runs := 4
var build := "mixed"
## Heat to play at (Server Settings applied in order), and "full" to start
## with every system restored instead of earning them.
var heat := 0
## god=1: the bot is healed every frame, to measure the whole curve.
var god := false
## fresh=1: every run starts from a fresh profile (a first run of the game each time).
var fresh := false
## climb=1: after each clear the next run plays at one more point of Heat, as a player climbs.
var climb := false
## tag=x: separate profile file, so several bots can run at once.
var tag := ""
var city := "earn"
## seed=N: run i uses the run seed N + i; below 0, every run is random.
var seed_base := -1
## The class chosen before the profile is set up (kept for fresh=1 profiles).
var _chosen_class := ""
## Between runs: the city, crafting and the loadout (tests/playtest_city.gd).
var city_play := PlaytestCity.new(self)
## The bot's own choices (doors, picks, dodges), seeded with the run so a seed replays it.
var bot_rng := RandomNumberGenerator.new()
## class=trickster: its two trees (e.g. trees=knight+bard_tree).
var trees: PackedStringArray = ["knight", "bard_tree"]
var game: Game
var results: Array[Dictionary] = []

var _room_log: Array[Dictionary] = []
var _room_t := 0.0
var _room_hp := 0
var _path := PackedVector2Array()
var _path_t := 0.0
var _attack_t := 0.0
var _last_depth := -1
var _last_pos := Vector2.ZERO
var _stuck_t := 0.0
var _detour := Vector2.ZERO
var _detour_t := 0.0


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)  # the shipped window, not headless 1280x1280
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "runs":
			runs = int(kv[1])
		elif kv.size() == 2 and kv[0] == "build":
			build = kv[1]
		elif kv.size() == 2 and kv[0] == "heat":
			heat = int(kv[1])
		elif kv.size() == 2 and kv[0] == "fresh":
			fresh = kv[1] == "1"
		elif kv.size() == 2 and kv[0] == "climb":
			climb = kv[1] == "1"
		elif kv.size() == 2 and kv[0] == "city":
			city = kv[1]
		elif kv.size() == 2 and kv[0] == "class":
			Profile.class_id = kv[1]
		elif kv.size() == 2 and kv[0] == "tag":
			tag = kv[1]
		elif kv.size() == 2 and kv[0] == "god":
			god = kv[1] == "1"
		elif kv.size() == 2 and kv[0] == "trees":
			trees = kv[1].split("+")
		elif kv.size() == 2 and kv[0] == "seed":
			seed_base = int(kv[1])
	Events.enemy_died.connect(func(e: Enemy) -> void:
		if e.first_hit_at >= 0.0:
			kill_log.append({"region": Run.route.region_index(), "depth": Run.route.depth, "elite": e.is_elite or e.is_boss,
				"boss": e.is_boss, "ttk": e.now() - e.first_hit_at, "hits": e.hits_taken, "max_hp": e.max_hp}))
	# What the bot casts, and why a cast was refused (the caster's messages).
	Events.skill_cast.connect(func(slot: int) -> void:
		var c: CardData = game.player.skills.card_in(slot) if is_instance_valid(game) else null
		if c:
			_casts[c.id] = int(_casts.get(c.id, 0)) + 1)
	Events.text_shown.connect(func(_at: Vector2, text: String, _color: Color) -> void:
		if text in REFUSALS:
			_refused[text] = int(_refused.get(text, 0)) + 1)
	Events.player_hp_changed.connect(func() -> void:
		if _hp_seen > Run.hp and Run.max_hp > 0:
			hit_log.append({"region": Run.route.region_index(), "pct": 100.0 * (_hp_seen - Run.hp) / Run.max_hp})
		_hp_seen = Run.hp)
	_chosen_class = Profile.class_id
	_setup_profile()
	_play.call_deferred()



## A new profile for the bot: its class, the city (earned or full) and the Heat it plays at.
func _setup_profile() -> void:
	var chosen := _chosen_class
	Profile.use_path("user://playtest_profile%s.json" % tag, true)
	Profile.class_id = chosen
	if chosen != "buffalo":
		Profile.stats["clears"] = maxi(1, int(Profile.stats.get("clears", 0)))  # the slot is open
	if chosen == "trickster":
		for k: String in ["clears_gladiator", "clears_champion", "runes_echo_bard", "runes_echo_explorer", "runes_echo_entertainer"]:
			Profile.stats[k] = 1
		Profile.custom = {"kit": "sword", "graph": "Balanced", "trees": Array(trees)}
	if city == "full":
		for r: RestorationData in Run.hub.restorations:
			Profile.restorations[String(r.id)] = r.max_level
		Profile.stats["clears"] = 1  # a veteran city: Echoes can appear
	_apply_heat(heat)


## Raises Server Settings, in order, until `target` points of Heat are on.
func _apply_heat(target: int) -> void:
	Profile.server_settings = {}
	var left := target
	while left > 0:
		var raised := false
		for id: String in ServerSettings.ORDER:
			var s: Dictionary = ServerSettings.SETTINGS[id]
			if left >= int(s.heat) and ServerSettings.rank(id) < int(s.max):
				Profile.server_settings[id] = ServerSettings.rank(id) + 1
				left -= int(s.heat)
				raised = true
		if not raised:
			break
	print("Heat %d: %s" % [ServerSettings.heat(), Profile.server_settings])


func _play() -> void:
	for i in runs:
		await _one_run(i)
	_report()
	get_tree().quit()


func _one_run(index: int) -> void:
	if fresh and index > 0:
		_setup_profile()
	var heat_here := ServerSettings.heat()
	var shelves_before := Profile.warehouse.size()
	_room_log.clear()
	_last_depth = -1
	_casts = {}
	_refused = {}
	if seed_base >= 0:
		Run.next_seed = seed_base + index
		bot_rng.seed = hash(seed_base + index)
	else:
		bot_rng.randomize()
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	var t := 0.0
	# The last HP losses, for a death's report: when, how much, and the nearest monster.
	var drops: PackedStringArray = []
	var last_hp := Run.hp
	while not game.hud.results_panel.visible and t < RUN_LIMIT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_tick(get_physics_process_delta_time())
		if Run.hp < last_hp:
			drops.append("%.1fs -%d (%d left, %s)" % [Run.time, last_hp - Run.hp, Run.hp, _nearest_foe()])
			if drops.size() > 6:
				drops.remove_at(0)
		last_hp = Run.hp
	_release()
	_end_room()
	var killers: PackedStringArray = []
	if is_instance_valid(game.room):
		for e: Enemy in game.room.enemies:
			if e.is_hittable():
				killers.append(e.display_name)
	var gear: PackedStringArray = []
	for k in Run.gear.EQUIP_SLOTS:
		if Run.gear.equipped(k):
			gear.append(Run.gear.equipped(k).title())
	var r := {"run": index + 1, "seed": Run.run_seed, "won": game.phase == game.Phase.WON, "depth": Run.route.depth + (1 if Run.won else 0),
		"level": Run.level, "job": Run.job.display_name, "time": Run.time, "kills": Run.kills,
		"types": Run.type_points.duplicate(), "gear": gear, "cards": Run.deck.cards.duplicate(), "rooms": _room_log.duplicate(),
		"ore": Run.purse.ore, "galder": Run.purse.galder, "around": killers, "materials": Run.purse.materials.duplicate(),
		"rune": Run.deck.rune.display_name if Run.deck.rune else "", "casts": _casts.duplicate(), "refused": _refused.duplicate(),
		"loadout": Run.deck.loadout.duplicate(), "heat": heat_here,
		"home": Profile.warehouse.size() - shelves_before, "shelves": Profile.warehouse.size(),
		"bag": Profile.lost_bag.get("items", []).size()}
	results.append(r)
	print("run %d: %s at room %d, Lv %d %s, %.0fs, %d kills" % [r.run, "CLEAR" if r.won else "died", r.depth,
		r.level, r.job, r.time, r.kills])
	if not r.won:
		print("   last HP losses: %s" % "; ".join(drops))
		if t >= RUN_LIMIT:
			print("   (stopped at the %d s run limit: not a death)" % int(RUN_LIMIT))
	if climb and r.won:
		heat = mini(heat + 1, 18)
		_apply_heat(heat)
	city_play.choose_loadout()
	city_play.restore_city()
	city_play.city_craft()
	get_tree().paused = false
	Engine.time_scale = 1.0
	game.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- the bot

## The nearest live monster and its distance, or "none".
func _nearest_foe() -> String:
	var best: Enemy = null
	var player: Player = game.player
	for e: Enemy in game.room.enemies:
		if e.is_hittable() and (best == null or e.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
			best = e
	return "none" if best == null else "%s at %.0f px" % [best.display_name, best.global_position.distance_to(player.global_position)]


func _tick(delta: float) -> void:
	if game.hud.drill.visible:
		_dig(game.hud.drill)
		return
	if game.hud.pick_panel.visible:
		_release()
		_choose()
		return
	if god and Run.hp > 0:
		Run.hp = Run.max_hp
		_hp_seen = Run.hp
	var player: Player = game.player
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		_release()
		return
	if Run.route.depth != _last_depth:
		_end_room()
		_last_depth = Run.route.depth
		_room_t = 0.0
		_room_hp = Run.hp
	match game.phase:
		game.Phase.FIGHT:
			_room_t += delta
			if _room_t > ROOM_LIMIT:
				print("  stuck in room %d (%s); clearing it" % [Run.route.depth + 1, game.room.data.id])
				for e: Enemy in game.room.enemies:
					print("    %s state %d at %s reachable %s path %d  player at %s" % [e.data.id, e.state, e.global_position,
						game.room.is_walkable(e.global_position), game.room.find_path(player.global_position, e.global_position).size(),
						player.global_position])
				print("    wave %d/%d alive %d pending %d" % [game.room.wave, game.room.waves.size(), game.room.alive, game.room.pending])
				print("    player state %d t %.1f vel %s walkable %s vault %s mask %d input %s" % [player.state, player._t, player.velocity,
					game.room.is_walkable(player.global_position), player._vaulting, player.collision_mask, player.move_input()])
				for e: Enemy in game.room.enemies.duplicate():
					if e.is_hittable():
						e.take_hit(99999, Vector2.RIGHT, 0.0, true)
				_room_t = 0.0
			_fight(player, delta)
		game.Phase.DOORS:
			_release()
			var bag := _lost_bag()
			if bag:
				player.global_position = bag.global_position  # a player picks the bag up before leaving
			elif not game.room.doors.is_empty():
				var d: Door = game.room.doors[bot_rng.randi() % game.room.doors.size()]
				if d.ready_to_enter():
					player.global_position = d.global_position
		_:
			_release()


## The lost bag lying in this room, or null.
func _lost_bag() -> LostBag:
	for c in game.room.world.get_children():
		if c is LostBag and not c.is_queued_for_deletion():
			return c
	return null


func _fight(player: Player, delta: float) -> void:
	var room: Room = game.room
	var target: Enemy = null
	var best := INF
	for e in room.enemies:
		if e.is_hittable():
			var d: float = Combat.ground(e.global_position - player.global_position).length()
			if d < best:
				best = d
				target = e
	if target == null:
		_release()
		return
	player.aim = Combat.ground(target.global_position - player.global_position).normalized()
	# Sidestep a shot that will reach us soon.
	for n in room.world.get_children():
		var shot := n as Projectile
		if shot == null or not player.can_dash():
			continue
		var to_me := Combat.ground(player.global_position - shot.position)
		var dir := Combat.ground(shot.direction).normalized()
		var along := to_me.dot(dir)
		if along > 0.0 and along < shot.speed * 0.45 and absf(to_me.dot(dir.orthogonal())) < 30.0:
			var side := dir.orthogonal() * (1.0 if to_me.dot(dir.orthogonal()) >= 0.0 else -1.0)
			_press(Combat.screen(side).normalized())
			player.buffer_action("dash")
			return
	# Dodge a wind-up aimed at us.
	for e in room.enemies:
		if e.state == Enemy.State.WINDUP and e._t > e._state_len * 0.45:
			var reach: float = e.attack.range + (40.0 if e.attack.shape == "lane" else e.attack.radius) + 10.0
			if Combat.ground(e.global_position - player.global_position).length() < reach and player.can_dash():
				var away := (player.global_position - e.global_position).normalized().rotated(bot_rng.randf_range(-0.6, 0.6))
				_press(away)
				player.buffer_action("dash")
				return
	# Skills when they're ready and something is close.
	for i in SkillCaster.SLOT_ACTIONS.size():
		var id: StringName = Run.deck.loadout[i] if i < Run.deck.loadout.size() else (Run.deck.rune.id if Run.deck.rune else &"")
		if id == &"clinch_release" or (id == &"chakra_balance" and Run.hp > Run.max_hp * 0.6):
			continue  # Clinch Release is for staggers; Chakra Balance for when hurt
		# Like a player, it doesn't press a skill the caster would refuse (wrong form, short of
		# Galder): pressing it again every frame left the bot standing still, not fighting.
		if id != &"" and best < (200.0 if Run.cls.basic_skill else 140.0) and player.now() >= player.skills.slot_ready_at[i] \
				and Run.mp >= Run.deck.card(id).mp_at(Run.deck.card_level(id)) \
				and player.skills.charm_block(Run.deck.card(id), maxi(Run.deck.card_level(id), 1), i) == "":
			player.buffer_action(SkillCaster.SLOT_ACTIONS[i])
			_release()
			return
	if Run.cls.basic_skill:
		_kite(player, target, best, delta)
		return
	if best > 48.0:
		_path_t -= delta
		if _path_t <= 0.0 or _path.size() < 2:
			_path = room.find_path(player.global_position, target.global_position)
			_path_t = 0.4
		var next := target.global_position
		while _path.size() > 1 and _path[0].distance_to(player.global_position) < 12.0:
			_path.remove_at(0)
		if _path.size() > 0:
			next = _path[0]
		var dir := (next - player.global_position).normalized()
		# Snagged on a corner: sidestep for a moment, or dash toward the target.
		if player.global_position.distance_to(_last_pos) < 1.0:
			_stuck_t += delta
		else:
			_stuck_t = 0.0
		_last_pos = player.global_position
		if _detour_t > 0.0:
			_detour_t -= delta
			dir = _detour
		elif _stuck_t > 0.4:
			_stuck_t = 0.0
			_path_t = 0.0
			if player.can_dash() and bot_rng.randf() < 0.5:
				player.buffer_action("dash")
			else:
				_detour = dir.rotated(PI / 2.0 * (1 if bot_rng.randf() < 0.5 else -1))
				_detour_t = 0.35
				dir = _detour
		_press(dir)
	else:
		_release()
		_attack_t -= delta
		if _attack_t <= 0.0:
			player.buffer_action("attack")
			_attack_t = 0.08


func _press(dir: Vector2) -> void:
	_release()
	if dir.x < 0.0:
		Input.action_press("move_left", -dir.x)
	elif dir.x > 0.0:
		Input.action_press("move_right", dir.x)
	if dir.y < 0.0:
		Input.action_press("move_up", -dir.y)
	elif dir.y > 0.0:
		Input.action_press("move_down", dir.y)


func _release() -> void:
	for a in MOVES:
		Input.action_release(a)


## Strikes when the marker is in the sweet spot (a decent player's timing).
var digs := 0
## Combat feel samples: per kill {region, depth, elite, ttk, hits, max_hp}
## and per hit taken {region, pct of max HP}.
var kill_log: Array[Dictionary] = []
var hit_log: Array[Dictionary] = []
var _hp_seen := -1
## Per run: casts by card, and refused casts by the caster's reason.
const REFUSALS := ["Not enough Galder", "Beast form only", "Not in Evolution", "Not in Metamorphosis",
	"Needs 80% HP", "Needs four enemies", "No skills in Beast's Instinct", "No gun"]
var _casts := {}
var _refused := {}
## Picks whose chosen option a player could not have clicked.
var ui_bugs: PackedStringArray = []


func _dig(p: DrillPanel) -> void:
	if p._left == p._drill.strikes and p._t < 0.02:
		digs += 1
	if p._left > 0 and absf(p._marker() - p._spot) < p._zone * (0.35 if bot_rng.randf() < 0.7 else 0.9):
		p._strike()


# ---------------------------------------------------------------- choices

func _choose() -> void:
	var opts: Array = game._pick_options
	var pick := 0
	match game._pick_kind:
		"card":
			pick = bot_rng.randi() % opts.size()
			for i in opts.size():
				if opts[i].is_skill() and Run.deck.free_slot() >= 0:
					pick = i
			for i in opts.size():
				if Run.deck.grows_basic(opts[i]):
					pick = i  # a mage grows its main weapon first
		"replace":
			# Make room for the new job's skills by dropping the lowest-level one.
			pick = opts.size() - 1
			if game._pending_skill in Run.job.cards:
				var low := 99
				for i in opts.size() - 1:
					var lvl := Run.deck.card_level(Run.deck.loadout[opts[i]])
					if lvl < low:
						low = lvl
						pick = i
		"type":
			pick = _type_pick(opts)
		"gear":
			pick = opts.size() - 1
			var best := 0.0
			for i in opts.size() - 1:
				var gain := _gear_gain(opts[i])
				if gain > best:
					best = gain
					pick = i
		"gear_slot":
			pick = 0 if _score(Run.gear.equipped("acc1")) <= _score(Run.gear.equipped("acc2")) else 1
		"compound_mat":
			pick = opts.size() - 1
			for i in opts.size() - 1:
				var m: MaterialData = opts[i]
				if Run.purse.material_count(m) >= m.need and not Run.gear.compound_targets().is_empty():
					pick = i
					break
		"compound_target":
			pick = 0
		"rune":
			pick = 0
		"port":
			# A careful player: banks the best find at the Port after a boss (giving up its power for
			# the rest of the run); keeps everything on otherwise. A clear brings all of it home.
			pick = opts.size() - 1
			if Run.route.current_room().boss:
				var best_score := 0.0
				for i in opts.size() - 1:
					var g: GearItem = opts[i]
					if g.stored < 0 and _score(g) > best_score:
						best_score = _score(g)
						pick = i
		"make_room":
			pick = opts.size() - 1  # full shelves after a clear: log out without the rest
		"shop":
			pick = opts.size() - 1
			for i in opts.size() - 1:
				var o: Dictionary = opts[i]
				if Run.purse.galder < o.price:
					continue
				if (o.kind == "potion" and Run.hp < Run.max_hp * 0.6) or (o.kind == "gear" and _gear_gain(o.item) > 5.0) 						or (o.kind == "ore" and Run.purse.galder > 400):
					pick = i
					break
		"anvil":
			pick = opts.size() - 1
			for i in opts.size() - 1:
				var g := Run.gear.equipped(opts[i])
				if Run.gear.can_afford_refine(g) and Run.gear.refine_chance(g) >= 0.45:
					pick = i
					break
	# A player can't press a disabled option (a locked job): take the first one that isn't.
	var buttons: Array[PickOption] = game.hud._pick_buttons
	if pick < buttons.size() and buttons[pick].disabled:
		for i in buttons.size():
			if not buttons[i].disabled:
				pick = i
				break
	if not game.hud.pick_reachable(pick):
		var bug := "%s option %d of %d is off screen" % [game._pick_kind, pick + 1, opts.size()]
		if not bug in ui_bugs:
			ui_bugs.append(bug)
			print("UI BUG: " + bug)
	game.hud._on_pick(pick)


func _type_pick(opts: Array) -> int:
	if build in opts:
		return opts.find(build)
	return bot_rng.randi() % opts.size()


## How much better an item is than what it would replace, by a rough score.
func _gear_gain(g: GearItem) -> float:
	var worst := INF
	for k in Run.gear.slot_keys_for(g.data):
		worst = minf(worst, _score(Run.gear.equipped(k)))
	return _score(g) - worst


func _score(g: GearItem) -> float:
	if g == null:
		return 0.0
	var s := g.stats()
	return s.get("AP", 0) * 1.0 + s.get("DP", 0) * 0.8 + s.get("HP", 0) * 0.15 + s.get("MD", 0) * 0.3 \
		+ s.get("LK", 0) * 2.0 + s.get("DA", 0) * 1.5 + s.get("AC", 0) * 0.5 + s.get("HV", 0) * 2.0 \
		+ s.get("MA", 0) * 2.0 + s.get("MP", 0) * 0.1 + s.get("WT", 0) * 0.03


# ---------------------------------------------------------------- report

func _end_room() -> void:
	if _last_depth < 0:
		return
	_room_log.append({"room": _last_depth + 1, "time": _room_t, "hp_lost": _room_hp - Run.hp, "hp": Run.hp,
		"max_hp": Run.max_hp})
	var mons: Array = kill_log.filter(func(k: Dictionary) -> bool: return k.depth == _last_depth and not k.elite)
	var avg_hp := 0.0
	for k: Dictionary in mons:
		avg_hp += k.max_hp / float(mons.size())
	print("  room %2d  Lv %2d  AP %3d  atk x%.2f  maxHP %4d  DP %3d  dmg-taken x%.2f  mob HP %4.0f  hp lost %d" % [_last_depth + 1,
		Run.level, Run.stat("AP"), Run.formulas.attack_mult(), Run.max_hp, Run.stat("DP"), Run.formulas.damage_taken_mult(), avg_hp, _room_hp - Run.hp])


## Hits and seconds to kill, and how hard monsters hit, by depth band.
func _feel_report() -> void:
	print("---- combat feel ----")
	for first: int in range(0, Run.route.plan.size(), FEEL_BAND):
		var band: Array[int] = [first, first + FEEL_BAND - 1]
		var n := []
		var e := []
		for k in kill_log:
			if k.depth >= band[0] and k.depth <= band[1] and not k.boss:
				(e if k.elite else n).append(k)
		print("rooms %d-%d  normal: %s   elite: %s" % [band[0] + 1, band[1] + 1, _kill_stats(n), _kill_stats(e)])
	for r in Run.route.regions.size():
		var pcts: Array = hit_log.filter(func(h: Dictionary) -> bool: return h.region == r).map(func(h: Dictionary) -> float: return h.pct)
		if pcts.size():
			pcts.sort()
			print("region %d: hits taken %d, median %.1f%% of max HP, 90th pct %.1f%%" % [r + 1, pcts.size(),
				pcts[pcts.size() / 2], pcts[int(pcts.size() * 0.9)]])
	for k in kill_log:
		if k.boss:
			print("boss r%d: %.1fs, %d hits" % [k.region + 1, k.ttk, k.hits])


func _kill_stats(a: Array) -> String:
	if a.is_empty():
		return "-"
	var t: Array = a.map(func(k: Dictionary) -> float: return k.ttk)
	var h: Array = a.map(func(k: Dictionary) -> int: return k.hits)
	t.sort(); h.sort()
	return "n=%d  median %.1fs / %d hits (90th %.1fs / %d)" % [a.size(), t[t.size() / 2], h[h.size() / 2],
		t[int(t.size() * 0.9)], h[int(h.size() * 0.9)]]


func _report() -> void:
	print("\n==== playtest: %d runs, build %s ====" % [results.size(), build])
	var clears := 0
	var depth := 0.0
	for r in results:
		clears += 1 if r.won else 0
		depth += r.depth
		print("run %d  %s  room %d  Lv %d %s  %.0fs  kills %d  types %s  seed %d  heat %d  home %+d  shelves %d  bag %d" % [
			r.run, "CLEAR" if r.won else "died ", r.depth, r.level, r.job, r.time, r.kills, r.types, r.seed, r.heat, r.home,
			r.shelves, r.bag])
		print("   gear: %s" % ", ".join(r.gear))
		if not r.won:
			print("   died near: %s" % ", ".join(r.around))
		print("   cards: %s   rune %s   ore %d  galder %d" % [r.cards, r.rune, r.ore, r.galder])
		print("   loadout %s  casts %s  refused %s" % [r.loadout, r.casts, r.refused])
		var rooms: PackedStringArray = []
		for room: Dictionary in r.rooms:
			rooms.append("%d:%.0fs/-%d" % [room.room, room.time, room.hp_lost])
		print("   rooms (time/hp lost): %s" % "  ".join(rooms))
	print("clears %d / %d, average room reached %.1f, dig sites %d" % [clears, results.size(), depth / maxf(results.size(), 1), digs])
	_feel_report()
	print("ui bugs: %s" % (", ".join(ui_bugs) if ui_bugs.size() else "none"))


## Mages keep their distance: back off when a monster comes close, close in
## when it's out of reach, and cast the basic spell in between.
func _kite(player: Player, target: Enemy, best: float, delta: float) -> void:
	var room: Room = game.room
	var reach := Run.cls.basic_skill.param("range", maxi(Run.deck.card_level(Run.cls.basic_skill.id), 1)) * 0.85
	var gunner := player.gun.has_gun()
	if gunner:
		reach = player.gun.range() * 0.85
		# Without Quick Reload the gun reloads only standing still (the
		# client's rule): such a gunner stands its ground through the reload.
		if not player.gun.loaded() and best <= reach and Run.deck.card_level(&"quick_reload") <= 0:
			_release()
			return
	# Ranged bots always back away from a close monster. Kiting rules decide ranged clear rates
	# more than the game's numbers do (2026-10-21: attack-when-ready and flee-then-fight each
	# swung Dragon, Lion and Sheep by several clears in 5), so their clears aren't a balance signal.
	if best < 95.0 and not (gunner and Run.deck.card_level(&"quick_reload") <= 0):
		var away := (player.global_position - target.global_position).normalized()
		for turn: float in [0.0, 0.7, -0.7, 1.4, -1.4]:
			var dir := away.rotated(turn)
			if room.is_walkable(player.global_position + dir * 30.0):
				_press(dir)
				return
		player.buffer_action("dash")
		return
	if best > reach or not room.line_clear(player.global_position, target.global_position):
		_path_t -= delta
		if _path_t <= 0.0 or _path.size() < 2:
			_path = room.find_path(player.global_position, target.global_position)
			_path_t = 0.4
		while _path.size() > 1 and _path[0].distance_to(player.global_position) < 12.0:
			_path.remove_at(0)
		var next := _path[0] if _path.size() > 0 else target.global_position
		_press((next - player.global_position).normalized())
		return
	_release()
	_attack_t -= delta
	if _attack_t <= 0.0:
		player.buffer_action("attack")
		_attack_t = 0.08
