extends Node
## Autopilot playtest: a bot plays whole Coral Beach runs and reports how
## they went (depth reached, level, job, time, damage taken per room, gear,
## type points). Used to check balance after changes.
##
## Run it as fast as the CPU allows (fixed frame time):
##   godot --headless --fixed-fps 60 res://tests/playtest.tscn -- runs=5 build=power
## build: power | magic | sense | charm | mixed (how the bot spends type points)

const MOVES: Array[String] = ["move_left", "move_right", "move_up", "move_down"]
## Game seconds a room may take before the bot gives up on it.
const ROOM_LIMIT := 150.0

var runs := 4
var build := "mixed"
## Heat to play at (Server Settings applied in order), and "full" to start
## with every system restored instead of earning them.
var heat := 0
var city := "earn"
var game
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
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "runs":
			runs = int(kv[1])
		elif kv.size() == 2 and kv[0] == "build":
			build = kv[1]
		elif kv.size() == 2 and kv[0] == "heat":
			heat = int(kv[1])
		elif kv.size() == 2 and kv[0] == "city":
			city = kv[1]
	Profile.use_path("user://playtest_profile.json", true)
	if city == "full":
		for r: RestorationData in Run.hub.restorations:
			Profile.restorations[String(r.id)] = r.max_level
	var left := heat
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
	_play.call_deferred()


func _play() -> void:
	for i in runs:
		await _one_run(i)
	_report()
	get_tree().quit()


func _one_run(index: int) -> void:
	_room_log.clear()
	_last_depth = -1
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	var t := 0.0
	while not game.hud.results_panel.visible and t < 1800.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_tick(get_physics_process_delta_time())
	_release()
	_end_room()
	var killers: PackedStringArray = []
	if is_instance_valid(game.room):
		for e in game.room.enemies:
			if e.is_hittable():
				killers.append(e.display_name)
	var gear: PackedStringArray = []
	for k in Run.EQUIP_SLOTS:
		if Run.equipped(k):
			gear.append(Run.equipped(k).title())
	var r := {"run": index + 1, "won": game.phase == game.Phase.WON, "depth": Run.depth + (1 if Run.won else 0),
		"level": Run.level, "job": Run.job.display_name, "time": Run.time, "kills": Run.kills,
		"types": Run.type_points.duplicate(), "gear": gear, "cards": Run.cards.duplicate(), "rooms": _room_log.duplicate(),
		"ore": Run.ore, "galder": Run.galder, "around": killers, "materials": Run.materials.duplicate()}
	results.append(r)
	print("run %d: %s at room %d, Lv %d %s, %.0fs, %d kills" % [r.run, "CLEAR" if r.won else "died", r.depth,
		r.level, r.job, r.time, r.kills])
	_choose_heirloom()
	_restore_city()
	get_tree().paused = false
	Engine.time_scale = 1.0
	game.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- the bot

func _tick(delta: float) -> void:
	if game.hud.pick_panel.visible:
		_release()
		_choose()
		return
	var player: Player = game.player
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		_release()
		return
	if Run.depth != _last_depth:
		_end_room()
		_last_depth = Run.depth
		_room_t = 0.0
		_room_hp = Run.hp
	match game.phase:
		game.Phase.FIGHT:
			_room_t += delta
			if _room_t > ROOM_LIMIT:
				print("  stuck in room %d (%s); clearing it" % [Run.depth + 1, game.room.data.id])
				for e in game.room.enemies:
					print("    %s state %d at %s reachable %s path %d  player at %s" % [e.data.id, e.state, e.global_position,
						game.room.is_walkable(e.global_position), game.room.find_path(player.global_position, e.global_position).size(),
						player.global_position])
				print("    wave %d/%d alive %d pending %d" % [game.room.wave, game.room.waves.size(), game.room.alive, game.room.pending])
				print("    player state %d t %.1f vel %s walkable %s vault %s mask %d input %s" % [player.state, player._t, player.velocity,
					game.room.is_walkable(player.global_position), player._vaulting, player.collision_mask, player.move_input()])
				for e in game.room.enemies.duplicate():
					if e.is_hittable():
						e.take_hit(99999, Vector2.RIGHT, 0.0, true)
				_room_t = 0.0
			_fight(player, delta)
		game.Phase.DOORS:
			_release()
			if not game.room.doors.is_empty():
				var d: Door = game.room.doors[randi() % game.room.doors.size()]
				if d.ready_to_enter():
					player.global_position = d.global_position
		_:
			_release()


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
	# Dodge a wind-up aimed at us.
	for e in room.enemies:
		if e.state == Enemy.State.WINDUP and e._t > e._state_len * 0.45:
			var reach: float = e.cfg.get("range", 50.0) + e.cfg.get("radius", 40.0) + 10.0
			if Combat.ground(e.global_position - player.global_position).length() < reach and player.can_dash():
				var away := (player.global_position - e.global_position).normalized().rotated(randf_range(-0.6, 0.6))
				_press(away)
				player.buffer_action("dash")
				return
	# Skills when they're ready and something is close.
	for i in Run.loadout.size():
		var id: StringName = Run.loadout[i]
		if id != &"" and best < 140.0 and player.now() >= player.skills.slot_ready_at[i] \
				and Run.mp >= Run.card(id).mp_cost:
			player.buffer_action(SkillCaster.SLOT_ACTIONS[i])
			_release()
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
			if player.can_dash() and randf() < 0.5:
				player.buffer_action("dash")
			else:
				_detour = dir.rotated(PI / 2.0 * (1 if randf() < 0.5 else -1))
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


# ---------------------------------------------------------------- choices

func _choose() -> void:
	var opts: Array = game._pick_options
	var pick := 0
	match game._pick_kind:
		"card":
			pick = randi() % opts.size()
			for i in opts.size():
				if opts[i].is_skill() and Run.free_slot() >= 0:
					pick = i
		"replace":
			# Make room for the new job's skills by dropping the lowest-level one.
			pick = opts.size() - 1
			if game._pending_skill in Run.job.cards:
				var low := 99
				for i in opts.size() - 1:
					var lvl := Run.card_level(Run.loadout[opts[i]])
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
			pick = 0 if _score(Run.equipped("acc1")) <= _score(Run.equipped("acc2")) else 1
		"compound_mat":
			pick = opts.size() - 1
			for i in opts.size() - 1:
				var m: MaterialData = opts[i]
				if Run.material_count(m) >= m.need and not Run.compound_targets().is_empty():
					pick = i
					break
		"compound_target":
			pick = 0
		"port":
			pick = opts.size() - 1
			var best_score := 0.0
			for i in opts.size() - 1:
				if _score(opts[i]) > best_score:
					best_score = _score(opts[i])
					pick = i
		"shop":
			pick = opts.size() - 1
			for i in opts.size() - 1:
				var o: Dictionary = opts[i]
				if Run.galder < o.price:
					continue
				if (o.kind == "potion" and Run.hp < Run.max_hp * 0.6) or (o.kind == "gear" and _gear_gain(o.item) > 5.0) 						or (o.kind == "ore" and Run.galder > 400):
					pick = i
					break
		"anvil":
			pick = opts.size() - 1
			for i in opts.size() - 1:
				var g := Run.equipped(opts[i])
				if Run.can_afford_refine(g) and Run.refine_chance(g) >= 0.45:
					pick = i
					break
	game.hud._on_pick(pick)


func _type_pick(opts: Array) -> int:
	if build in opts:
		return opts.find(build)
	return randi() % opts.size()


## How much better an item is than what it would replace, by a rough score.
func _gear_gain(g: GearItem) -> float:
	var worst := INF
	for k in Run.slot_keys_for(g.data):
		worst = minf(worst, _score(Run.equipped(k)))
	var load_after := Run.equip_load() + g.data.weight
	var penalty := 20.0 if load_after > Run.load_limit() else 0.0
	return _score(g) - worst - penalty


func _score(g: GearItem) -> float:
	if g == null:
		return 0.0
	var s := g.stats()
	return s.get("AP", 0) * 1.0 + s.get("DP", 0) * 0.8 + s.get("HP", 0) * 0.15 + s.get("MD", 0) * 0.3 \
		+ s.get("LK", 0) * 2.0 + s.get("DA", 0) * 1.5 + s.get("AC", 0) * 0.5 + s.get("HV", 0) * 2.0 \
		+ s.get("MA", 0) * 2.0 + s.get("MP", 0) * 0.1 + s.get("WT", 0) * 0.03


## Between runs, buy whatever the city can afford, in the guide's order.
func _restore_city() -> void:
	for r: RestorationData in Run.hub.restorations:
		while Profile.can_buy(r):
			Profile.buy(r)
			print("   restored %s (%d TM, %d shards left)" % [r.display_name, Profile.tm, Profile.shards])


## Between runs, carry the best item in the warehouse (as a player would).
func _choose_heirloom() -> void:
	var best := -1
	var best_score := 0.0
	for i in Profile.warehouse.size():
		var g := GearItem.from_dict(Profile.warehouse[i], Run.item_by_id)
		if g and g.data.slot == ItemData.Slot.WEAPON and _score(g) > best_score:
			best_score = _score(g)
			best = i
	Profile.set_heirloom(best)
	if best >= 0:
		print("   carrying %s next" % GearItem.from_dict(Profile.warehouse[best], Run.item_by_id).title())


# ---------------------------------------------------------------- report

func _end_room() -> void:
	if _last_depth < 0:
		return
	_room_log.append({"room": _last_depth + 1, "time": _room_t, "hp_lost": _room_hp - Run.hp, "hp": Run.hp,
		"max_hp": Run.max_hp})


func _report() -> void:
	print("\n==== playtest: %d runs, build %s ====" % [results.size(), build])
	var clears := 0
	var depth := 0.0
	for r in results:
		clears += 1 if r.won else 0
		depth += r.depth
		print("run %d  %s  room %d  Lv %d %s  %.0fs  kills %d  types %s" % [r.run, "CLEAR" if r.won else "died ",
			r.depth, r.level, r.job, r.time, r.kills, r.types])
		print("   gear: %s" % ", ".join(r.gear))
		if not r.won:
			print("   died near: %s" % ", ".join(r.around))
		print("   cards: %s   ore %d  galder %d  materials %s" % [r.cards, r.ore, r.galder, r.materials])
		var rooms: PackedStringArray = []
		for room in r.rooms:
			rooms.append("%d:%.0fs/-%d" % [room.room, room.time, room.hp_lost])
		print("   rooms (time/hp lost): %s" % "  ".join(rooms))
	print("clears %d / %d, average room reached %.1f" % [clears, results.size(), depth / maxf(results.size(), 1)])
