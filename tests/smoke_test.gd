extends Node
## Headless smoke test for a Coral Beach run.
## Run everything: godot --headless --path . res://tests/smoke_test.tscn
## Run some sections: add `-- only=charm,ui` (sections by name) or `-- class=cat,lion`
## (the sections that test those characters); tests/run_smoke.sh wraps both. `-- seed=N`
## picks the seed every run and placement starts from (default 1, so results repeat).
## Each section sets up what it needs, so any subset passes on its own. Changes to
## shared code still run the full suite (CLAUDE.md, section 5).

## The sections, in the order they run.
const SECTIONS: Array[String] = ["core", "power", "magic", "sense", "elements", "charm", "talents", "balance", "ui", "boss",
	"systems", "lint"]
## Card id literals allowed in shared code (scripts/ outside skills/ and tools/): CLAUDE.md,
## section 2. Lower it as hooks move into card data; it may never rise.
const CARD_ID_LITERALS_MAX := 0
## The section that tests each character.
const CLASS_SECTION: Dictionary[String, String] = {"buffalo": "power", "bunny": "power", "sheep": "magic",
	"dragon": "magic", "fox": "sense", "lion": "sense", "cat": "charm", "raccoon": "charm"}

## The sections picked on the command line; empty runs them all.
var only: Array[String] = []
## The seed for the run's RNG and the test's own placement (seed=N).
var test_seed := 1
var failures := 0
var game: Game


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func run_state() -> Node:
	return get_node("/root/Run")


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] == "seed" and kv[1].is_valid_int():
			test_seed = int(kv[1])
			continue
		var names := kv[1].split(",", false) if kv.size() == 2 else PackedStringArray([arg])
		for name in names:
			if kv[0] == "only" and name in SECTIONS:
				only.append(name)
			elif kv[0] == "class" and CLASS_SECTION.has(name):
				only.append(CLASS_SECTION[name])
			else:
				push_error("smoke test: unknown argument %s (sections: %s)" % [arg, ", ".join(SECTIONS)])
				get_tree().quit(2)
				return
	get_window().size = Vector2i(1280, 720)  # the shipped window, not headless 1280x1280
	seed(test_seed)  # the test's own placement, and every later run's seed, follow from it
	Run.next_seed = test_seed
	_run.call_deferred()


## Whether a section runs: every one, or those picked on the command line.
func _on(section: String) -> bool:
	return only.is_empty() or section in only


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.is_hittable())


func clear_room() -> void:
	for _i in 60:
		if game.phase != game.Phase.FIGHT:
			return
		for e: Enemy in enemies():
			e.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.5)


func profile() -> Node:
	return get_node("/root/Profile")


func _run() -> void:
	profile().use_path("user://smoke_test_profile.json", true)  # never touch the real save
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await wait(2.6)
	if _on("core"):
		await _core_room()
	if _on("power"):
		await _power_attacks()
	if _on("core"):
		await _core_rewards()
	if _on("power"):
		# Job changes, upgrade skills and the Power-line talents.
		await skill_rules()
	if _on("magic"):
		# The Magic line: Sheep and Dragon, casting, Seals and Pacts, every spell.
		await magic_line()
	if _on("sense"):
		# The Sense line: Fox and Lion, the gun's cycle, every Sense skill.
		await sense_line()
	if _on("elements"):
		# Elemental attack compounds and their hit effects; shields and guns.
		await elements_and_shields()
	if _on("charm"):
		# The Charm line: Cat and Raccoon, the beast forms, every Charm skill.
		await charm_line()
	if _on("talents"):
		await talent_hooks()
	if _on("balance"):
		_balance()
	if _on("ui"):
		await _ui_audit()
	if _on("boss"):
		await _end_of_run()
	if _on("systems"):
		_systems(run_state())
	if _on("lint"):
		_lint()

	print("\n%s: %d failure(s)%s" % ["OK" if failures == 0 else "FAILED", failures,
		"" if only.is_empty() else " in " + ", ".join(only)])
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures else 0)


## The first room builds, a wave spawns, a punch lands, and pathfinding works.
func _core_room() -> void:
	var Run := run_state()
	var room: Room = game.room
	check(room != null and room.world != null, "first room builds from %s" % (room.data.map if room else "?"))
	check(room.is_walkable(game.player.global_position), "player starts on walkable ground")
	check(room.get_child_count() > 3 and room.world.get_child_count() > 1, "room has ground, props and the player")
	await wait(1.5)
	check(enemies().size() > 0, "wave 1 spawns (%d enemies)" % enemies().size())

	# Punch an enemy placed in front of the player.
	var player: Player = game.player
	var target: Enemy = enemies()[0]
	var hp_before := target.hp
	target.global_position = player.global_position + Vector2(30, 6)
	for _i in 2:
		player.aim = Combat.ground(target.global_position - player.global_position).normalized()
		player.attack.start(0)
		for _f in 20:
			player.aim = Combat.ground(target.global_position - player.global_position).normalized()
			await get_tree().physics_frame
	check(target.hp < hp_before, "punch damages %s (%d -> %d)" % [target.data.id, hp_before, target.hp])

	# Pathfinding returns a route between two walkable points.
	var a := room.random_spot(Vector2.ZERO, 0.0)
	var b := room.random_spot(a, 300.0)
	check(room.find_path(a, b).size() > 1, "grid pathfinding finds a route across the room")


## Every Power-line attack and echo rune casts and damages a monster in front of Buffalo.
func _power_attacks() -> void:
	var Run := run_state()
	var room: Room = game.room
	var player: Player = game.player
	# Every Power-line attack casts and damages a monster in front of Buffalo.
	check(Run.deck.loadout[0] == Run.cls.start_job.starter.id, "the run starts with %s in slot 1" % Run.cls.start_job.starter.id)
	var skill_ids: Array[StringName] = []
	for card: CardData in Run.deck.all_cards():
		if card.is_skill() and card.resource_path.begins_with("res://data/skills/power/") 				and not card.id in [&"clinch_release", &"chakra_balance"]:
			skill_ids.append(card.id)
	check(skill_ids.size() == 23, "the Power line has 25 attacks (23 that deal damage): %d" % skill_ids.size())
	for id in skill_ids:
		# Ranges are on the ground plane; place the dummy at a ground distance.
		var reach := 110.0 if id in [&"boxer_dash", &"flash_cut", &"mega_flash_cut", &"piercing_wave", &"earthquake_blade",
			&"inferno_blade", &"tornado_bomb", &"sonic_slash", &"lightning_strike"] else 50.0
		if id == &"shadow":
			reach = 150.0  # Shadow strikes the monster nearest the cursor, 150 ahead without a mouse
		var spot := Vector2.INF
		var ground_dir := Vector2.ZERO
		for _i in 300:
			var p := room.random_spot(Vector2.ZERO, 0.0)
			var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
			if room.line_clear(p, p + Combat.screen(d) * 130.0) and room.is_open_spot(p + Combat.screen(d) * reach):
				spot = p
				ground_dir = d
				break
		var at := spot + Combat.screen(ground_dir) * reach
		player.global_position = spot
		player.enter(Player.State.MOVE)
		for other in room.enemies:
			# Park the room's monsters out of the way: nothing else may take the hit
			# (removing them would break the room's clear later on).
			other.global_position = room.random_spot(spot, 400.0)
			other.apply_debuff("hold", 1.0, 2.0)
			other.hp = maxi(other.hp, 99999)  # nor die to a stray hit and end the wave
		var dummy: Enemy = room.spawn(&"torobbie", at)
		await wait(0.6)
		dummy.max_hp = 99999
		dummy.hp = 99999
		var before := dummy.hp
		Run.deck.cards[id] = 1
		Run.deck.loadout[0] = id
		Run.mp = Run.max_mp
		Run.hp = Run.max_hp
		player.skills.slot_ready_at[0] = 0.0
		player.invulnerable_until = player.now() + 5.0  # room monsters mustn't interrupt the cast
		player.aim = ground_dir
		var cast := player.skills.try_cast(0)
		for _f in 90:
			if is_instance_valid(dummy):
				dummy.global_position = at
			await get_tree().physics_frame
		check(cast and dummy.hp < before, "%s casts and damages a monster (%d -> %d)%s" % [id, before, dummy.hp,
			"" if dummy.hp < before else _why(cast, dummy, player)])
		if dummy.is_hittable():
			dummy.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.3)
	player.invulnerable_until = 0.0
	# Echo runes: a borrowed skill in slot 4.
	for c: CardData in Run.echoes.reduce(func(acc: Array, e: EnemyData) -> Array: return acc + e.runes, []):
		var spot2 := Vector2.INF
		var dir2 := Vector2.ZERO
		# Galder Barrage lands on the cursor (150 ahead without a mouse).
		var reach2 := 150.0 if c.id == &"galder_barrage" else 70.0
		for _i in 300:
			var p := room.random_spot(Vector2.ZERO, 0.0)
			var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
			if room.line_clear(p, p + Combat.screen(d) * (reach2 + 60.0)) and room.is_open_spot(p + Combat.screen(d) * reach2):
				spot2 = p
				dir2 = d
				break
		if spot2 == Vector2.INF:  # no open line found: fall back to any open spot
			spot2 = room.random_spot(Vector2.ZERO, 0.0)
			dir2 = Vector2.RIGHT
		player.global_position = spot2
		player.enter(Player.State.MOVE)
		var at2 := spot2 + Combat.screen(dir2) * reach2
		for other in room.enemies:
			# As above: nothing else may take the hit (spells land on the monster nearest the aim).
			other.global_position = room.random_spot(spot2, 400.0)
			other.apply_debuff("hold", 1.0, 3.0)
			other.hp = maxi(other.hp, 99999)
		var target2: Enemy = room.spawn(&"torobbie", at2)
		for _w in 30:
			await wait(0.1)
			if target2.is_hittable():
				break
		var hp0 := target2.hp
		Run.deck.take_rune(c)
		Run.mp = Run.max_mp
		Run.purse.galder = 500
		player.skills.slot_ready_at[3] = 0.0
		player.invulnerable_until = player.now() + 5.0
		player.aim = dir2
		var cast2 := player.skills.try_cast(3)
		for _f in 90:
			if is_instance_valid(target2):
				target2.global_position = at2
			await get_tree().physics_frame
		check(cast2 and target2.hp < hp0, "rune skill %s casts from slot 4 (%d -> %d)%s" % [c.id, hp0, target2.hp,
			"" if target2.hp < hp0 else _why(cast2, target2, player)])
		if target2.is_hittable():
			target2.take_hit(99999, Vector2.RIGHT, 0.0, true)
		await wait(0.3)
	Run.deck.rune = null
	player.invulnerable_until = 0.0
	Run.deck.cards = {Run.cls.start_job.starter.id: 1}
	Run.deck.loadout.assign([Run.cls.start_job.starter.id, &"piercing_wave", &"shockwave"])
	Run.deck.cards[&"piercing_wave"] = 2
	Run.deck.cards[&"shockwave"] = 1
	Run.deck.add_card(&"tornado_bomb", 1)
	check(Run.deck.loadout[1] == &"tornado_bomb" and Run.deck.card_level(&"piercing_wave") == 0,
		"a new skill can replace a slotted one")
	Run.deck.loadout.assign([Run.cls.start_job.starter.id, &"", &""])
	Run.deck.cards = {Run.cls.start_job.starter.id: 1}
	Run.pending_levels = 0  # the dummies' EXP shouldn't queue level-ups for the checks below
	Run.xp = 0


## Fading props, vaulting, the room reward, gear, the anvil, level-ups, a door, and a monster's shot.
func _core_rewards() -> void:
	var Run := run_state()
	var room: Room = game.room
	var player: Player = game.player
	# Scenery in front of the player fades and the silhouette shows.
	var behind := Vector2.INF
	for prop in room.props:
		for dy: float in [10.0, 20.0, 30.0]:
			var feet := prop.position - Vector2(0, dy)
			if room.is_walkable(feet) and prop.hides(feet + Vector2(0, -26), feet.y):
				behind = feet
				break
		if behind != Vector2.INF:
			break
	if behind != Vector2.INF:
		player.global_position = behind
		for _f in 3:
			await get_tree().physics_frame
		var faded := room.props.any(func(p: Prop) -> bool: return p.target_alpha < 1.0)
		check(faded and player.silhouette.visible, "props hiding the player fade and the silhouette shows")
	else:
		print("SKIP  no prop to hide behind in this room")

	# A dash vaults an obstacle when there's open ground past it.
	var vault_from := Vector2.INF
	var vault_dir := Vector2.ZERO
	for _i in 400:
		var p := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		if room.vault_distance(p, d, player.dash_distance, player.vault_extra) > 0.0:
			vault_from = p
			vault_dir = d
			break
	if vault_from != Vector2.INF:
		player.global_position = vault_from
		player.enter(Player.State.MOVE)
		player.dash_ready_at = 0.0
		Input.action_press("dash")
		player.buffer_action("dash")
		player.aim = Combat.ground(vault_dir).normalized()
		await get_tree().physics_frame
		Input.action_release("dash")
		await wait(0.5)
		var moved := (player.global_position - vault_from).dot(vault_dir)
		check(moved > 40.0 and room.is_walkable(player.global_position),
			"dash vaults an obstacle and lands on open ground (%.0f px)" % moved)
	else:
		print("SKIP  no vaultable obstacle found in this room")

	# Levels earned in combat are chosen after the room reward.
	Run.gain_exp(Run.exp_to_next())
	check(Run.pending_levels == 1, "gaining EXP queues a level-up")

	await clear_room()
	await wait(1.0)
	check(game.hud.pick_panel.visible and game._pick_kind == "card", "clearing room 1 offers a skill card")
	var card_id: StringName = game._pick_options[0].id
	game._steps.append_array(["gear", "anvil"])
	game.hud._on_pick(0)
	check(Run.deck.card_level(card_id) == 1, "picking adds %s at level 1" % card_id)
	await wait(0.2)
	check(game.hud.pick_panel.visible and game._pick_kind == "gear", "an Equipment reward offers gear")
	var found: GearItem = game._pick_options[0]
	game.hud._on_pick(0)
	await wait(0.2)
	check(Run.gear.equipment.values().has(found), "picking the gear equips %s" % found.title())
	check(game.hud.pick_panel.visible and game._pick_kind == "anvil", "an Anvil reward opens the anvil")
	var weapon: GearItem = Run.gear.equipped("weapon")
	Run.purse.galder = 1000
	var ore_before: int = Run.purse.ore
	var cost: Dictionary = weapon.refine_cost()
	game.hud._on_pick(0)
	await wait(1.0)
	check(game._pick_kind == "anvil" and Run.purse.ore == ore_before - cost.ore,
		"refining at the anvil spends ore and returns to it (%s)" % weapon.title())
	game.hud._on_pick(game._pick_options.size() - 1)
	await wait(0.2)
	Run.gear.equip(GearItem.make(_item("pretty_hammer")))
	while Run.type_points.power < 6:
		Run.apply_type("power")
	game.player.refresh_gear()
	var steps: Array = game.player.combo_steps()
	game.player.attack.start(0)
	for _f in 30:
		await get_tree().physics_frame
	check(game.player.combo == Player.FAMILY_COMBOS.hammer and steps.size() == 4
		and game.player.weapon.weapon_name == "item_40004",
		"a hammer swaps the combo; Extra Swing adds a 4th swing (%d)" % steps.size())
	Run.gear.equip(GearItem.make(Run.cls.start_weapon))
	game.player.refresh_gear()
	check(game.hud.pick_panel.visible and game._pick_kind == "type", "the queued level-up offers the four types next")
	game.hud._on_pick(0)
	await wait(0.4)
	var trained: CardData = game._pick_options[0] if game._pick_kind == "card" else null
	var trained_lv: int = Run.deck.card_level(trained.id) if trained else 0
	check(game.hud.pick_panel.visible and trained and trained_lv > 0, "a level-up also trains a skill you have")
	if trained:
		game.hud._on_pick(0)
		await wait(0.4)
		check(Run.deck.card_level(trained.id) == trained_lv + 1, "training raises %s to Lv %d" % [trained.display_name, Run.deck.card_level(trained.id)])
	check(room.doors.size() == 2, "two exit doors open (%d)" % room.doors.size())

	# Walk through a door into the next room.
	var door: Door = room.doors[0]
	await wait(0.7)
	if game.room == room and is_instance_valid(door):  # it may already have walked into one
		game.player.global_position = door.global_position
	await wait(2.6)
	check(Run.route.depth == 1 and game.room != room, "entering a door loads room 2 (%s)" % game.room.data.id)

	# Clione's shot travels and hurts the player.
	await wait(1.0)
	for e: Enemy in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	var clione: Enemy = game.room.spawn("clione", game.room.random_spot(game.player.global_position, 150.0))
	await wait(0.7)
	# Somewhere in range with a clear line of fire.
	var me: Vector2 = game.player.global_position
	var placed := false
	for _i in 2000:
		var p: Vector2 = game.room.random_spot(me, 120.0)
		if Combat.ground(p - me).length() < 230.0 and game.room.line_clear(p, me):
			clione.global_position = p
			placed = true
			break
	if not placed:  # no open line near the player: bring both into the open
		game.player.global_position = game.room.random_spot(me, 0.0)
		me = game.player.global_position
		clione.global_position = me + Vector2(140, 0)
	var hp_start: int = Run.hp
	var saw_shot := false
	for _f in 400:
		if get_tree().get_nodes_in_group("projectiles").size() > 0 or game.room.world.get_children().any(func(n: Node) -> bool: return n is Projectile):
			saw_shot = true
		await get_tree().physics_frame
		if Run.hp < hp_start:
			break
	check(saw_shot, "Clione fires a projectile")
	check(Run.hp < hp_start, "enemy attacks hurt the player (%d -> %d)" % [hp_start, Run.hp])


## Progression guards: damage grows with its stat as in Trickster, and monsters are as tough as their original level.
func _balance() -> void:
	var Run := run_state()
	var outliers: PackedStringArray = []
	for ri: int in Run.route.regions.size():
		var r: RegionData = Run.route.regions[ri]
		for e in r.enemies:
			if e.echo or e.min_depth >= 99:
				continue
			var st := Stats.from_monster(Run.formulas.monster_stats(e).get("stats", {}))
			var hp: float = Run.formulas.mob_hp(st, r) * e.hp_mult
			if e.is_boss:
				# Basic hits from a par build at the region's end (about 210 a hit
				# after Coral Beach, twice that after Desert Beach).
				var hits: float = hp / (210.0 * (ri + 1))
				if hits < 15.0 or hits > 120.0:
					outliers.append("%s boss takes %.0f hits" % [e.id, hits])
			elif float(Run.formulas.mob_hit(st, r)) > Run.formulas.region_norm(r).hit * Run.formulas.MAX_HIT_SPREAD * Run.formulas.MOB_HIT_SCALE * r.damage_scale + 1.0:
				outliers.append("%s hits too hard" % e.id)
	check(outliers.is_empty(), "every monster's HP comes from its original level%s" % ("" if outliers.is_empty() else ": " + ", ".join(outliers)))
	Profile.class_id = "dragon"
	Run.new_run()
	var arrow: CardData = Run.deck.card(&"mana_arrow")
	var before: float = Run.formulas.skill_mult(arrow)
	Run._stats["MA"] = Run.stat("MA") * 2
	check(is_equal_approx(Run.formulas.skill_mult(arrow), before * 2.0), "twice the MA is twice Mana Arrow's damage (x%.2f -> x%.2f)" % [before, Run.formulas.skill_mult(arrow)])
	var always := true
	for i in 20:
		always = always and Run.deck.card(&"mana_arrow") in Run.deck.card_offers(3, true)
	Run.deck.cards[&"mana_arrow"] = 3
	for i in 20:
		always = always and Run.deck.card(&"arrow_rush") in Run.deck.card_offers(3, false)
	for i in 20:
		always = always and Run.deck.card(&"arrow_rush") in Run.deck.card_offers(3, true)
	check(always, "Dragon is always offered Mana Arrow's level-ups, and Arrow Rush (new cards and training) once Mana Arrow is Lv 3")
	# The two basics: Mana Arrow wins on one or two targets, Mana Ring from three,
	# at every stage (the basic and its supplement at the same level).
	var ring: CardData = Run.deck.card(&"mana_ring")
	var rush: CardData = Run.deck.card(&"arrow_rush")
	var boost: CardData = Run.deck.card(&"mana_ring_booster")
	var basics_ok := true
	var basics := PackedStringArray()
	for lv in range(1, 6):
		var arrows := 1.0 + (rush.value_at(lv) - 1.0) * rush.param("ratio", lv) / 100.0 if lv > 1 else 1.0
		var arrow_dps := arrow.value_at(lv) * arrows / arrow.cooldown_at(1)
		var ring_dps := (ring.value_at(lv) + (boost.value_at(lv) if lv > 1 else 0.0)) / ring.cooldown_at(1)
		basics_ok = basics_ok and 2.0 * ring_dps <= arrow_dps * 1.1 and 3.0 * ring_dps > arrow_dps
		basics.append("Lv%d %d vs %d/target" % [lv, arrow_dps, ring_dps])
	check(basics_ok, "Mana Arrow out-damages Mana Ring on 2 targets, Mana Ring wins on 3 (%s)" % ", ".join(basics))
	Profile.class_id = "buffalo"
	Run.new_run()


## The worst-case pick lists fit on screen and can be left.
func _ui_audit() -> void:
	var Run := run_state()
	var saved_mats: Dictionary = Run.purse.materials.duplicate()
	for path in DirAccess.get_files_at("res://data/materials"):
		var m: MaterialData = load("res://data/materials/" + path.trim_suffix(".remap"))
		Run.purse.material_info[m.id] = m
		Run.purse.materials[m.id] = m.need + 2
	game._open_compounder()
	await wait(0.3)
	var all_ok := true
	for i: int in game._pick_options.size():
		all_ok = all_ok and game.hud.pick_reachable(i)
	check(all_ok and game.hud.pick_panel.get_global_rect().size.y <= 720.0,
		"a Compounder with %d materials fits on screen and every option is reachable" % (game._pick_options.size() - 1))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.2)
	check(not game.hud.pick_panel.visible or game._pick_kind != "compound_mat", "Esc leaves the Compounder")
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	Run.purse.materials = saved_mats
	var many: Array = []
	for i in 20:
		many.append({"title": "Option %d" % i, "text": "A long description that has to wrap onto a second line inside the pick panel without running under the icon or off the edge."})
	many.append({"title": "Leave", "text": "", "cancel": true})
	game.hud.show_pick("Twenty options", many)
	await wait(0.3)
	check(game.hud.pick_reachable(20) and game.hud.pick_panel.get_global_rect().end.y <= 720.0,
		"a 20-option list scrolls and its Leave option stays pinned on screen (reachable %s, bottom %d)"
		% [game.hud.pick_reachable(20), game.hud.pick_panel.get_global_rect().end.y])
	game.hud.pick_panel.visible = false


## The boss room, a lingering spell, death and the rollback, then Megalopolis.
func _end_of_run() -> void:
	var Run := run_state()
	await clear_room()
	Run.route.depth = Run.route.regions[0].run_length
	game.get_tree().paused = false
	game.hud.pick_panel.visible = false
	game._load_room()
	await wait(3.0)
	var boss: Enemy = null
	for e: Enemy in enemies():
		if e.is_boss:
			boss = e
	check(boss != null and game.room.data.map == "map_dg11b", "boss room loads the Dark Cave with the Golden Mole")
	if boss:
		boss.take_hit(int(boss.max_hp * 0.36), Vector2.RIGHT, 0.0, true)
		await wait(1.3)
		check(enemies().size() >= 3, "boss summons Torobbies below 66%% HP (%d enemies)" % enemies().size())

	# A lingering spell outlives its room (a run ending, a room change) cleanly:
	# the field's end effect used to wait on a freed player and error.
	check(Enemy.projectile_scene().instantiate() is Projectile, "monster shots load (Tutankhamen's curse once got an empty scene)")
	var caster: Player = game.player
	Run.deck.cards[&"undines_garden"] = 1
	Run.deck.loadout[0] = &"undines_garden"
	Run.mp = Run.max_mp
	caster.skills.slot_ready_at[0] = 0.0
	caster.enter(Player.State.MOVE)
	caster.invulnerable_until = caster.now() + 3.0  # the boss would interrupt the cast
	var lingered := caster.skills.try_cast(0)
	await wait(1.0)
	var held := Skill._lingering.size()  # checked once the run is over and the game freed, below

	# Death shows the rollback results.
	Run.hp = 1
	game.player.invulnerable_until = 0.0
	game.player.take_hit(50, Vector2.RIGHT, 0.0, false, 1000000)  # perfect accuracy: no evade
	await wait(2.6)
	check(game.hud.results_panel.visible and game.phase == game.Phase.DEAD, "dying shows the rollback results")
	var P := profile()
	check(P.stats.runs == 1 and P.stats.deaths == 1 and P.tm == Run.purse.tm, "the rollback banks the run (%d TM)" % P.tm)

	# Megalopolis: people, the gate, conversations and restorations.
	Engine.time_scale = 1.0
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	await wait(0.5)
	check(lingered and held > 0 and Skill._lingering.is_empty(),
		"a lingering field lets go when the run ends under it (%d lingering, then %d)" % [held, Skill._lingering.size()])
	var hub: Hub = load("res://scenes/hub.tscn").instantiate()
	get_tree().root.add_child(hub)
	await wait(1.0)
	check(hub.npcs.size() == 4 and hub.gate != null and hub.room.is_walkable(hub.player.global_position),
		"the hub builds Megalopolis with %d people and the gate" % hub.npcs.size())
	check(hub.story.conversation_for("cavalier").get("id") == "cav_intro", "Don Cavalier starts with his introduction")
	var guide: Npc = hub._npc(&"cavalier")
	hub.player.global_position = guide.global_position + Vector2(0, 20)
	hub.talk(guide)
	for _i in 30:
		await wait(0.05)
		hub.dialogue._typing = false
		hub.dialogue._advanced.emit()
	check(P.has_flag("met_cavalier") and not hub.talking, "finishing a conversation sets its flag")
	check(hub.story.conversation_for("cavalier").get("id") == "cav_rollback", "after a death he remembers the rollback")
	P.tm = 10000
	var hall: RestorationData = Run.hub.restorations.filter(func(r: RestorationData) -> bool: return r.id == &"training_hall")[0]
	check(P.buy(hall) and P.level(hall.id) == 1 and P.tm == 10000 - hall.tm_cost(1), "restoring the Training Hall spends TM")
	Run.new_run()
	check(Run.max_hp == Run.stat("HP") and Run.bonus_hp == 15, "restorations apply to the next run (max HP %d)" % Run.max_hp)
	var reach: float = Combat.ground(hub.room.nearest_reachable(Run.hub.gate_position) - hub.gate.global_position).length()
	check(reach < 1.0, "the expedition gate stands on reachable ground")
	hub.queue_free()


func _item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id)


## Stats, types and traits, jobs and prerequisites, gear, weight and refining.
## Code rules the smoke test enforces (CLAUDE.md, sections 2 and 5).
func _lint() -> void:
	var ids := {}
	for c: CardData in Run.deck.all_cards():
		ids[String(c.id)] = true
	var literal := RegEx.create_from_string('&"([a-z0-9_]+)"')
	var total := 0
	var worst: PackedStringArray = []
	for path in _scripts_under("res://scripts"):
		if path.begins_with("res://scripts/skills/") or path.begins_with("res://scripts/tools/"):
			continue
		var n := 0
		for m in literal.search_all(FileAccess.get_file_as_string(path)):
			n += 1 if ids.has(m.get_string(1)) else 0
		total += n
		if n > 0:
			worst.append("%s %d" % [path.get_file(), n])
	check(total <= CARD_ID_LITERALS_MAX, "card id literals in shared code: %d (at most %d; %s)"
		% [total, CARD_ID_LITERALS_MAX, ", ".join(worst)])
	# A skill's behaviour script names only the cards it plays (supplements reach it as mods).
	var own := {}
	for c: CardData in Run.deck.all_cards():
		if c.behavior:
			own[c.behavior.resource_path] = own.get(c.behavior.resource_path, []) + [String(c.id)]
	var cross: PackedStringArray = []
	for path in _scripts_under("res://scripts/skills"):
		for m in literal.search_all(FileAccess.get_file_as_string(path)):
			var id := m.get_string(1)
			if ids.has(id) and not id in own.get(path, []) and not "%s %s" % [path.get_file(), id] in cross:
				cross.append("%s %s" % [path.get_file(), id])
	check(cross.is_empty(), "skill scripts name only their own cards%s" % ("" if cross.is_empty() else ": " + ", ".join(cross)))
	# Every script compiles, with the autoloads in place (scenes the suite never opens too).
	var broken: PackedStringArray = []
	var all_scripts := _scripts_under("res://scripts")
	all_scripts.append_array(_scripts_under("res://tests"))
	for path in all_scripts:
		var s: GDScript = load(path)
		if s == null or not s.can_instantiate():
			broken.append(path.get_file())
	check(broken.is_empty(), "all %d scripts compile%s" % [all_scripts.size(), "" if broken.is_empty() else ": " + ", ".join(broken)])
	# Every Run.<member> and Run.<module>.<member> the scripts name exists (calls on an
	# autoload are only resolved when they run, so a stale name would wait for a player).
	var run_ref := RegEx.create_from_string("\\bRun\\.([A-Za-z_]\\w*)(?:\\.([A-Za-z_]\\w*))?")
	var missing := {}
	for path in all_scripts:
		for m in run_ref.search_all(FileAccess.get_file_as_string(path)):
			var a := m.get_string(1)
			var b := m.get_string(2)
			if not _has_member(Run, a):
				missing["Run.%s (%s)" % [a, path.get_file()]] = true
			elif b != "" and Run.get(a) is RefCounted and not _has_member(Run.get(a), b):
				missing["Run.%s.%s (%s)" % [a, b, path.get_file()]] = true
	check(missing.is_empty(), "every Run member the scripts name exists%s" % ("" if missing.is_empty() else ": " + ", ".join(missing.keys())))
	# Paths to the original assets go through Assets (scripts/assets.gd), never a literal.
	var literal_paths: PackedStringArray = []
	for path in all_scripts:
		if path != "res://scripts/assets.gd" and FileAccess.get_file_as_string(path).contains("\"" + Assets.ROOT):
			literal_paths.append(path.get_file())
	check(literal_paths.is_empty(), "no script spells out an original_assets path%s"
		% ("" if literal_paths.is_empty() else ": " + ", ".join(literal_paths)))
	# Every monster names an attack pattern, and its tune overrides only that pattern's fields.
	var bad_attacks: PackedStringArray = []
	var monsters: Array[EnemyData] = Run.echoes.duplicate()
	for r in Run.route.regions:
		monsters.append_array(r.enemies)
	for e in monsters:
		if e.attack == null:
			bad_attacks.append("%s has none" % e.id)
			continue
		for key: String in e.tune:
			if not key in e.attack:
				bad_attacks.append("%s.tune.%s" % [e.id, key])
	check(bad_attacks.is_empty(), "all %d monsters have an attack pattern their tune fits%s"
		% [monsters.size(), "" if bad_attacks.is_empty() else ": " + ", ".join(bad_attacks)])


## Whether `o` has a method, property, constant or signal called `n`.
func _has_member(o: Object, n: String) -> bool:
	if o.has_method(n) or n in o or o.has_signal(n):
		return true
	var s: Script = o.get_script()
	return s != null and s.get_script_constant_map().has(n)


## Every .gd file under `dir`, recursively.
func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(d)))
	return out


func _systems(Run: Node) -> void:
	_restore_all(Run)
	# A seed replays a run: the same room plan, card offers and gear rolls.
	var replays: Array[String] = []
	for s: int in [42, 42, 43]:
		Run.new_run(s)
		var rooms: Array = Run.route.plan.map(func(r: RoomPlan) -> String: return String(r.data.id) + ("*" if r.elite else ""))
		var offers: Array = Run.deck.card_offers(3, false).map(func(c: CardData) -> String: return String(c.id))
		var gear: Array = Run.gear.gear_offers(3).map(func(g: GearItem) -> String: return g.title() + str(g.stats))
		replays.append("%s | %s | %s" % [", ".join(rooms), ", ".join(offers), ", ".join(gear)])
	check(replays[0] == replays[1] and replays[0] != replays[2] and Run.run_seed == 43,
		"the same seed replays the room plan, offers and gear, and another seed doesn't (%s...)" % replays[0].left(60))
	Run.new_run()

	# Cards declare their stat mods; Run.mod() sums the held ones.
	var bad_keys: PackedStringArray = []
	var modded := 0
	for c: CardData in Run.deck.all_cards():
		modded += 1 if not c.mods.is_empty() else 0
		for key: String in c.mods:
			if not Mod.is_key(key):
				bad_keys.append("%s:%s" % [c.id, key])
	check(bad_keys.is_empty() and modded >= 17, "every card's mods use known keys (%d cards with mods)%s"
		% [modded, "" if bad_keys.is_empty() else ": " + ", ".join(bad_keys)])
	var ap0: int = Run.stat("AP")
	var heart: CardData = Run.deck.card(&"pumping_heart")
	Run.deck.cards[&"pumping_heart"] = 3
	Run.stats_changed()
	check(is_equal_approx(Run.mod("AP%"), heart.value_at(3)) and Run.stat("AP") == floori(ap0 * (1.0 + heart.value_at(3) / 100.0)),
		"a held AP%% card raises AP by its value (+%s%%: %d -> %d)" % [heart.value_at(3), ap0, Run.stat("AP")])
	Run.deck.cards.erase(&"pumping_heart")
	Run.stats_changed()
	# Wardrobe quirks are mods too; two pieces that each speed you up compound.
	var worn_before: Dictionary = Profile.worn.duplicate()
	Profile.give_wardrobe(&"bunny_ears")
	Profile.give_wardrobe(&"newbie_sprint")
	Profile.wear("ear", &"bunny_ears")
	Profile.wear("speed", &"newbie_sprint")
	var fast: float = Run.formulas.speed_mult() / (0.85 if Run.gear.overweight() else 1.0)
	check(Run.mod("move%") == 18.0 and is_equal_approx(fast, 1.08 * 1.1),
		"Bunny's Ears and Newbie Sprint add their move%% and compound (x%.3f)" % fast)
	Profile.worn = worn_before
	var ap: int = Run.stat("AP")
	var ac: int = Run.stat("AC")
	var t: Dictionary = Run.apply_type("power")
	check(Run.stat("AP") == ap + 4 and Run.stat("AC") == ac + 2 and t.is_empty(), "a Power point raises AP and AC")
	Run.apply_type("power")
	t = Run.apply_type("power")
	check(t.get("id") == &"staggering_finish" and Run.has_trait(&"staggering_finish"),
		"three Power points unlock Staggering Finish")
	var hp: int = Run.max_hp
	Run.gain_exp(Run.exp_to_next())
	check(Run.level == 2 and Run.max_hp > hp and Run.hp == Run.max_hp, "levelling grows HP along Buffalo's graph")

	Run.new_run()
	var mult: float = Run.formulas.attack_mult()
	Run.gear.equip(GearItem.make(_item("wood_sword")))
	check(Run.stat("AP") == Run.cls.base.AP + 20 and Run.formulas.attack_mult() > mult * 1.2,
		"a Wood Sword raises AP and combo damage (x%.2f)" % (Run.formulas.attack_mult() / mult))
	Run.gear.equip(GearItem.make(_item("lucky_amulet")))
	Run.gear.equip(GearItem.make(_item("topaz_ring")))
	check(Run.gear.equipped("acc1").data.id == &"lucky_amulet" and Run.gear.equipped("acc2").data.id == &"topaz_ring",
		"two accessories fill both accessory slots")
	check(not Run.gear.overweight() and Run.formulas.speed_mult() == 1.0, "light gear stays under the load limit")
	Run.gear.equip(GearItem.make(_item("bamboo_sword")))
	Run.gear.equip(GearItem.make(_item("clam_shield")))
	check(Run.gear.overweight() and Run.formulas.speed_mult() < 1.0, "heavy gear past WT / 4 (%d / %d) slows you" % [Run.gear.equip_load(), Run.gear.load_limit()])
	var pouch := GearItem.make(_item("pocket_pouch"))
	Run.gear.equip(pouch, "acc1")
	check(not Run.gear.overweight(), "a Pocket Pouch (+200 WT) carries the load")

	var sword := GearItem.make(_item("wood_sword"))
	Run.gear.equip(sword)
	Run.purse.ore = 50
	Run.purse.galder = 5000
	var before: int = Run.stat("AP")
	check(Run.gear.try_refine(sword, 0.0) == "success" and sword.refine == 1 and Run.stat("AP") > before
		and sword.title() == "Wood Sword +1", "refining succeeds and raises AP (%d -> %d)" % [before, Run.stat("AP")])
	var dropped := false
	for _i in 40:
		sword.refine = 5
		if Run.gear.try_refine(sword, 0.999) == "drop":
			dropped = sword.refine == 4
			break
	check(dropped, "a failed refine from +5 can drop a level")
	check(not Run.gear.can_afford_refine(sword) or Run.purse.ore > 0, "refining costs Bronze Fragments and Galder")

	Run.route.depth = 0
	var early: Array = Run.gear.gear_offers(30)
	Run.route.depth = 5
	var late: Array = Run.gear.gear_offers(30)
	check(early.all(func(g: GearItem) -> bool: return g.data.level <= 1)
		and late.any(func(g: GearItem) -> bool: return g.data.level >= 13), "deeper rooms drop higher-level gear")
	var rolls: Array = []
	for _i in 60:
		rolls.append(GearItem.roll(_item("wood_sword"), 1.0))
	check(rolls.any(func(g: GearItem) -> bool: return g.prefix != ""), "drops can roll Trickster prefixes (%s)"
		% rolls.filter(func(g: GearItem) -> bool: return g.prefix != "")[0].title())

	Run.new_run()
	var offered_smash := false
	for _i in 40:
		for c: CardData in Run.deck.card_offers(3, false):
			offered_smash = offered_smash or c.id == &"upper_smash"
	check(not offered_smash, "Upper Smash waits for Bull's Eye Lv 3 (the original's 10 of 11)")
	Run.deck.cards[&"bulls_eye"] = 3
	for _i in 40:
		for c: CardData in Run.deck.card_offers(3, false):
			offered_smash = offered_smash or c.id == &"upper_smash"
	check(offered_smash, "Bull's Eye Lv 3 opens Upper Smash")

	Run.route.depth = Run.route.region.job_change_depth
	check(Run.job_change_due() and Run.job.id == &"fighter", "the trial room brings the Fighter's job change")
	var sword_mult: float = Run.formulas.attack_mult()
	var knight: JobData = Run.job.next_jobs[0]
	Run.start_job(knight)
	var knight_only: bool = Run.deck.card_offers(3, false, knight).all(func(c: CardData) -> bool: return c in knight.cards)
	check(Run.job.id == &"knight" and knight_only, "advancing to Knight opens the Knight tree")
	var third: Array = Run.job.next_jobs.map(func(j: JobData) -> String: return String(j.id))
	check(third == ["gladiator", "mercenary"] and Run.job.next_jobs[0].unlocked() and not Run.job.next_jobs[1].unlocked(),
		"a Knight goes on to Gladiator, or Mercenary once a Gladiator clear unlocks it")
	Profile.stats["clears_gladiator"] = 1
	check(Run.job.next_jobs[1].unlocked(), "a Gladiator clear unlocks the Mercenary")
	Profile.stats.erase("clears_gladiator")
	check(Run.formulas.attack_mult() > sword_mult * 1.1, "Sword Mastery strengthens the sword combo")

	Run.new_run()
	var evade: float = Run.formulas.evade_chance(50)
	for _i in 3:
		Run.apply_type("charm")
	check(Run.formulas.evade_chance(50) > evade + 0.08, "Charm raises evasion and unlocks Light Feet")
	for _i in 10:
		Run.apply_type("magic")
	Run.mp = 0
	var hp_before: int = Run.hp
	check(Run.spend_mp(10) and Run.hp == hp_before - 20, "Overcast pays missing MP with HP")

	# Monster materials and compounding.
	Run.new_run()
	var penguin: EnemyData = Run.route.region.enemy(&"blue_penguin")
	var ice: MaterialData = penguin.material
	var drop: Dictionary = Run.purse.add_kill(0, 0, 0, true, false, ice, 0.0)
	check(drop.material == ice and Run.purse.material_count(ice) == 2, "an elite Blue Penguin drops 2 Cool Ice")
	Run.purse.add_material(ice, 2)
	var blade := GearItem.make(_item("wood_sword"))
	Run.gear.equip(blade)
	check(Run.purse.compoundable_materials().has(ice) and Run.gear.compound_targets().has("weapon"),
		"4 Cool Ice can be compounded into the Wood Sword's slot")
	var c: Dictionary = Run.gear.compound(blade, ice)
	check(c.stat == "Water" and c.value >= ice.min_value and c.value <= ice.max_value and Run.purse.material_count(ice) == 0
		and blade.free_slots() == 0, "compounding uses 4 Cool Ice and rolls Water attack %d" % c.value)
	check(Run.gear.element_attack().get("Water", 0) == c.value, "the sword's Water attack counts toward elemental damage")
	var hard: MaterialData = Run.route.region.enemy(&"bustshell").material
	var helm := GearItem.make(_item("candy_hat"))
	Run.gear.equip(helm)
	var dp: int = Run.stat("DP")
	Run.purse.add_material(hard, hard.need)
	var hc: Dictionary = Run.gear.compound(helm, hard)
	check(Run.stat("DP") == dp + hc.value, "Hard Scales compounded into a hat add DP (+%d)" % hc.value)
	var shop: Array[Dictionary] = Run.gear.shop_offers()
	check(shop.any(func(o: Dictionary) -> bool: return o.kind == "gear") and shop.any(func(o: Dictionary) -> bool: return o.kind == "potion"),
		"the shop sells gear and potions")
	Run.route.depth = 4
	Run.route.current_room().feature = &"blue_penguin"
	var roller: Room = load("res://scripts/room.gd").new()
	var penguins := 0
	var total := 0
	for _r in 6:
		for w: Array in roller._make_waves(4, false):
			for e: Dictionary in w:
				total += 1
				penguins += 1 if e.id == &"blue_penguin" else 0
	check(penguins * 3 >= total, "a Blue Penguin den fills its waves with penguins (%d of %d)" % [penguins, total])

	# Warehouse, heirlooms, level sync and rollback.
	Run.new_run()
	var heir := GearItem.make(_item("wood_sword"))
	heir.refine = 5
	Run.gear.equip(heir)
	check(Run.city.save_point(heir) and Profile.warehouse.size() == 1 and heir.stored == 0, "a Portable Port sends the sword home")
	Profile.set_heirloom(0)
	Run.new_run()
	var carried: GearItem = Run.gear.equipped("weapon")
	check(carried.data.id == &"wood_sword" and carried.refine == 5 and carried.effective_refine() == 3
		and carried.sync_factor() < 1.0, "the heirloom comes back level-synced: %s" % carried.title())
	var synced_ap: int = carried.stats().AP
	Run.route.depth = 3
	Run.city.sync_heirlooms()
	check(carried.stats().AP > synced_ap and carried.sync_factor() == 1.0, "deeper rooms lift the sync (AP %d -> %d)"
		% [synced_ap, carried.stats().AP])
	Run.route.depth = 0
	Run.purse.ore = 20
	Run.purse.galder = 5000
	Run.gear.try_refine(carried, 0.0)
	check(Run.city.unsaved_changes().size() == 1, "refining the heirloom is unsaved until a Port")
	Run.new_run()
	check(Run.gear.equipped("weapon").refine == 5, "dying without saving rolls the heirloom back to +5")
	Run.gear.try_refine(Run.gear.equipped("weapon"), 0.0)
	Run.city.save_point()
	Run.new_run()
	check(Run.gear.equipped("weapon").refine == 6, "saving at a Port keeps the +6")
	var kept: Dictionary = Profile.bank_leftovers(false, 101, 5, {&"cool_ice": 3})
	check(kept.galder == 50 and Profile.ore == 2 and Profile.materials.get("cool_ice", 0) == 1,
		"a rollback banks half the leftover Galder, ore and materials")
	Profile.bank_leftovers(true, 100, 4, {&"cool_ice": 4})
	check(Profile.galder == 150 and Profile.materials.cool_ice == 5, "a clear banks all of them")
	Profile.use_path("user://smoke_test_profile.json", true)
	Run.new_run()
	check(not Run.city.system_on(&"smithing") and not Run.job_change_due(), "a fresh city has no smithing or job changes")
	Run.route.depth = Run.route.region.job_change_depth
	check(not Run.job_change_due(), "without the Job Hall the trial room changes nothing")
	_restore_all(Run)
	check(Run.city.system_on(&"smithing") and Run.job_change_due(), "restoring the Job Hall turns the job change on")

	# Monster cards and the wardrobe.
	Profile.restorations["card_house"] = 1
	var boss_cards := 0
	for _i in 40:
		boss_cards += 1 if Run.purse.roll_card(&"golden_mole", false, true) else 0
	check(boss_cards > 8 and boss_cards < 32, "bosses drop their cards half the time (%d / 40)" % boss_cards)
	var shore: CardSetData = Run.hub.card_sets.filter(func(s: CardSetData) -> bool: return s.id == &"shore_critters")[0]
	for m in shore.monsters:
		Profile.add_card(m)
	check(shore.complete() and shore.reward.id == &"bunny_ears", "three cards complete the Shore Critters set")
	Profile.give_wardrobe(&"buffalo_horn")
	Profile.wear("ear", &"buffalo_horn")
	Run.new_run()
	var mult_horn: float = Run.formulas.attack_mult()
	check(Run.mod("elite_damage%") == 10.0 and Run.stat("AP") == Run.cls.base.AP + 2 + 6 and mult_horn > 1.0,
		"wearing Buffalo's Horn adds AP and its quirk")
	Profile.wear("ear", &"")
	Run.new_run()

	# Echoes appear in elite rooms only after a first clear.
	Run.new_run()
	Run.route.depth = Run.route.regions[0].elite_depths[0]
	var echo_seen := false
	for _i in 40:
		echo_seen = echo_seen or Run.purse.echo_here() != null
	check(not echo_seen or int(Profile.stats.get("clears", 0)) >= 1, "no Echoes before the first clear")
	Profile.stats["clears"] = max(1, int(Profile.stats.get("clears", 0)))
	for _i in 40:
		echo_seen = echo_seen or Run.purse.echo_here() != null
	check(echo_seen, "after a clear, Echoes haunt elite rooms")
	Run.new_run()

	# Bunny: a second class from data alone.
	var bunny: ClassData = Run.classes[1]
	check(not bunny.unlocked() or int(Profile.stats.get("clears", 0)) >= 1, "Bunny's slot opens after a clear")
	Profile.stats["clears"] = 1
	Profile.class_id = "bunny"
	Run.new_run()
	check(Run.cls.id == &"bunny" and Run.job.id == &"schoolgirl" and Run.job.next_jobs[0].id == &"boxer"
		and Run.deck.card_level(&"shockwave") == 1, "Bunny starts as a Schoolgirl with Shockwave, headed for Boxer")
	var boxer: JobData = Run.job.next_jobs[0]
	Run.start_job(boxer)
	var champ_or_duel: Array = boxer.next_jobs.map(func(j: JobData) -> String: return String(j.id))
	check(champ_or_duel == ["champion", "duelist"] and not boxer.next_jobs[1].unlocked(),
		"a Boxer goes on to Champion, or Duelist after a Champion clear")
	Profile.class_id = "buffalo"
	Run.new_run()

	# Drilling.
	Profile.restorations["drill_shop"] = 1
	var drill: DrillData = Run.purse.drill()
	check(drill != null and drill.id == &"basic_drill", "the Drill Shop gives a Basic Drill")
	var shallow: Dictionary = Run.purse.dig_rewards(10)
	var deep: Dictionary = Run.purse.dig_rewards(80)
	check(shallow.ore > 0 and shallow.material == null and deep.material != null and deep.shard == 1,
		"deeper digs bring up materials and Harkon Shards")

	# The custom Trickster.
	check(not Run.city.trickster_unlocked(), "the Trickster is locked at first")
	Profile.stats["clears_gladiator"] = 1
	Profile.stats["clears_champion"] = 1
	Profile.stats["runes_echo_bard"] = 1
	check(Run.city.trickster_unlocked(), "a 3rd-job clear with Buffalo and with Bunny unlocks the Trickster")
	Profile.custom = {"kit": "fists", "graph": "Magic / Sense", "trees": ["knight", "bard_tree"]}
	Profile.class_id = "trickster"
	Run.new_run()
	var pool_ids: Array = Run.deck.card_pool().map(func(c: CardData) -> String: return String(c.id))
	check(Run.cls.id == &"trickster" and not Run.cls.armed and "lacerator" in pool_ids and "drip_bomb" in pool_ids
		and "shockwave" in pool_ids and Run.has_passive(&"data_bleed"),
		"a fists Trickster with Knight and Bard trees offers Lacerator, Drip Bomb and the Fighter tree")
	check(float(Run.cls.graph.magic) == 0.5, "its type graph is the Magic / Sense preset")
	Profile.class_id = "buffalo"
	Profile.custom = {}
	for k: String in ["clears_gladiator", "clears_champion", "runes_echo_bard"]:
		Profile.stats.erase(k)
	Run.new_run()

	# Master Louis raises card caps.
	var wave: CardData = Run.deck.card(&"shockwave")
	Profile.materials[String(wave.master_material.id)] = 6
	Profile.galder = 600
	check(Run.deck.can_master(wave) and Run.deck.card_cap(&"shockwave") == 5, "6 Hard Scales and 500 G can master Shockwave")
	Run.deck.master_card(wave)
	Run.deck.cards[&"shockwave"] = 5
	Run.deck.add_card(&"shockwave")
	check(Run.deck.card_cap(&"shockwave") == 6 and Run.deck.card_level(&"shockwave") == 6, "a mastered Shockwave reaches Lv 6")
	Profile.mastery = {}
	Run.new_run()

	# Server Settings (Heat).
	Profile.server_settings = {"server_load": 2, "pk_mode": 1, "hardcore": 1}
	check(ServerSettings.heat() == 7 and is_equal_approx(ServerSettings.monster_hp_mult(), 1.3),
		"Server Load 2 + PK Mode + Hardcore is Heat 7")
	Run.new_run()
	Run.revives = 1
	check(not Run.try_revive(), "Hardcore Server allows no revives")
	Run.purse.tm = 1000
	Run.purse.shards = 0
	Run.city.finish(true)
	check(Run.last_result.tm == 1700 and Run.last_result.bounty == 7 and Profile.best_heat == 7,
		"clearing at Heat 7 banks +70% TM and a 7-shard bounty")
	Run.new_run()
	Run.purse.tm = 1000
	Run.city.finish(true)
	check(Run.last_result.bounty == 0, "the bounty is paid once per Heat level")
	Profile.server_settings = {}
	Run.new_run()


func _restore_all(Run: Node) -> void:
	for r: RestorationData in Run.hub.restorations:
		if r.effect == "system":
			Profile.restorations[String(r.id)] = 1


func skill_rules() -> void:
	var p: Player = game.player
	for e: Enemy in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await wait(0.5)
	p.global_position = game.room.random_spot(p.global_position, 0.0)
	p.invulnerable_until = 0.0
	p.aim = Vector2.RIGHT
	check(p.sprite.actor_name == Run.cls.actor, "a run starts as the class's own character")
	Run.take_damage(30)
	var hp: int = Run.hp
	var points: Dictionary = Run.type_points.duplicate()
	Run.start_job(load("res://data/jobs/knight.tres"))
	p.refresh_gear()
	check(p.sprite.actor_name == "knight" and Run.actor() == "knight", "becoming a Knight turns you into the Knight")
	check(Run.hp == hp and Run.type_points == points, "a job change brings no type points or heal (none in Trickster)")
	Run.start_job(load("res://data/jobs/gladiator.tres"))
	p.refresh_gear()
	check(p.sprite.actor_name == "power_m", "a Gladiator takes the Power 3rd-job body")

	# Advanced forms are offered only with their base skill and replace it.
	Run.new_run()
	Run.start_job(load("res://data/jobs/knight.tres"))
	var tempest: CardData = Run.deck.card(&"tempest_strike")
	check(tempest.upgrades == &"lacerator" and not Run.deck.can_learn(tempest), "Tempest Strike needs Lacerator in hand")
	Run.deck.add_card(&"lacerator")
	Run.deck.cards[&"lacerator"] = 3
	check(Run.deck.can_learn(tempest) and Run.deck.can_learn(Run.deck.card(&"tidal_slash")), "Lacerator Lv 3 opens Tempest Strike and Tidal Slash")
	var at := Run.deck.loadout.find(&"lacerator")
	Run.deck.add_card(&"tempest_strike")
	check(Run.deck.loadout[at] == &"tempest_strike" and Run.deck.card_level(&"lacerator") == 0 and Run.deck.card_level(&"tempest_strike") == 3,
		"Tempest Strike takes Lacerator's slot and level, replacing it")
	check(not Run.deck.can_learn(Run.deck.card(&"tidal_slash")), "with Lacerator gone, Tidal Slash is no longer offered")
	Run.deck.cards[&"tempest_strike"] = 2
	var gale_offered := false
	for _i in 30:
		for c: CardData in Run.deck.card_offers(3, false, load("res://data/jobs/gladiator.tres")):
			gale_offered = gale_offered or c.id == &"gale_strike"
	check(not gale_offered, "Gale Strike isn't offered before Tempest Strike Lv 3")
	Run.deck.cards[&"tempest_strike"] = 3
	Run.start_job(load("res://data/jobs/gladiator.tres"))
	check(Run.deck.can_learn(Run.deck.card(&"gale_strike")), "Tempest Strike Lv 3 opens Gale Strike for the Gladiator")
	Run.deck.add_card(&"piercing_wave")
	Run.deck.cards[&"piercing_wave"] = 3
	Run.deck.add_card(&"earthquake_blade")
	check(Run.deck.card_level(&"piercing_wave") == 0 and Run.deck.known_level(&"piercing_wave") == 3
		and Run.deck.requirements_met(Run.deck.card(&"lightning_strike")),
		"Earthquake Blade replaces Piercing Wave and still opens Lightning Strike")
	check(Run.deck.card_cap(&"guard_break") == 1 and not Run.deck.can_master(Run.deck.card(&"guard_break")),
		"Guard Break stays at Lv 1, as in the original")

	# Talents with the original effects.
	Run.new_run()
	var ap: int = Run.stat("AP")
	Run.deck.add_card(&"pumping_heart")
	check(Run.stat("AP") > ap, "Pumping Heart raises AP (%d -> %d)" % [ap, Run.stat("AP")])
	var target: Enemy = game.room.spawn("torobbie", p.global_position + Vector2(50, 0))
	target.max_hp = 99999
	target.hp = 99999
	for i in 40:
		if target.is_hittable():
			break
		await wait(0.1)
	var acc: int = target.accuracy()
	var defense: float = target.defense_mult()
	Run.deck.add_card(&"shockvibe")
	Run.deck.add_card(&"armor_breaker")
	Run.deck.add_card(&"suffocate")
	p.deal_hit(target, 10.0, 1.0, 0.0, false)
	check(target.accuracy() < acc or acc == 0, "Shockvibe lowers a hit monster's accuracy (%d -> %d)" % [acc, target.accuracy()])
	check(target.defense_mult() >= defense and not target.can_hide(), "Armor Breaker lowers its DP; Suffocate keeps it from hiding")
	Run.deck.add_card(&"guard")
	p._tick_talents(0.016)
	hp = Run.hp
	p.invulnerable_until = 0.0
	p.take_hit(20, Vector2.LEFT, 0.0, false, 9999)
	check(Run.hp == hp and Run.guard_blocks == 0, "Guard blocks a physical hit outright")
	p.invulnerable_until = 0.0
	p.take_hit(20, Vector2.LEFT, 0.0, true, 9999)
	check(Run.hp < hp, "Guard doesn't block magic")
	Run.deck.add_card(&"clinch_release")
	Run.deck.loadout[1] = &"clinch_release"
	p.invulnerable_until = 0.0
	p.take_hit(5, Vector2.LEFT, 300.0, false, 9999)
	p.skills.slot_ready_at[1] = 0.0
	Run.mp = Run.max_mp
	p.buffer_action("skill_2")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p.state == Player.State.SKILL and p.knock == Vector2.ZERO, "Clinch Release can be cast while staggered and cancels it")
	await wait(0.4)
	Run.hp = Run.max_hp / 2
	p.start_regen(0.05, 0.2, 2.0)
	await wait(0.5)
	check(Run.hp > Run.max_hp / 2, "Chakra Balance recovers HP over time")
	target.take_hit(999999, Vector2.RIGHT, 0.0, true)
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)


## Takes a dummy away without a death (no EXP, no room clear).
func _remove(e: Enemy) -> void:
	if is_instance_valid(e):
		game.room.enemies.erase(e)
		e.queue_free()


## A dummy in front of the player that won't die from the checks.
## Why a spell check missed: did the cast start, where was the target, and
## what else was in the room.
func _why(cast: bool, e: Enemy, p: Player) -> String:
	var others := 0
	for o: Enemy in game.room.enemies:
		if o != e and o.is_hittable():
			others += 1
	return " [cast %s, target %s at %.0f px, state %d, player state %d, %d other monsters]" % [cast,
		"valid" if is_instance_valid(e) else "gone", e.global_position.distance_to(p.global_position) if is_instance_valid(e) else -1.0,
		e.state if is_instance_valid(e) else -1, p.state, others]


func _dummy(p: Player, ahead: float) -> Enemy:
	var room: Room = game.room
	var spot := Vector2.INF
	var dir := Vector2.RIGHT
	for _i in 300:
		var at := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		if room.line_clear(at, at + Combat.screen(d) * (ahead + 40.0)) and room.is_open_spot(at + Combat.screen(d) * ahead):
			spot = at
			dir = d
			break
	p.global_position = spot
	p.enter(Player.State.MOVE)
	p.aim = dir
	for other: Enemy in room.enemies.duplicate():
		_remove(other)  # nothing else may take the hit
	var at := spot + Combat.screen(dir) * ahead
	var e: Enemy = room.spawn(&"torobbie", at)
	for _w in 30:
		await wait(0.1)
		if e.is_hittable():
			break
	# It walks toward the player while it spawns; put it back where the check expects it
	# (left close, it could fall outside a skill's aim wedge and the check would flake).
	e.global_position = at
	e.max_hp = 99999
	e.hp = 99999
	return e


func magic_line() -> void:
	var p: Player = game.player
	for e: Enemy in enemies():
		e.take_hit(99999, Vector2.RIGHT, 0.0, true)
	await wait(0.5)
	p.invulnerable_until = 0.0
	check(Run.classes.size() == 8 and Run.classes.all(func(c: ClassData) -> bool: return c.unlocked()),
		"all eight characters are playable from the start")
	var saved: String = Profile.class_id

	# Sheep: Librarian, Mana Ring on the attack button, no MP.
	Profile.class_id = "sheep"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"sheep" and Run.job.id == &"librarian" and Run.deck.card_level(&"mana_ring") == 1
		and not &"mana_ring" in Run.deck.loadout and p.sprite.actor_name == "sheep",
		"Sheep starts as a Librarian with Mana Ring as her basic attack, not in a slot")
	var target := await _dummy(p, 90.0)
	var mp := Run.mp
	var hp := target.hp
	p.buffer_action("attack")
	await wait(2.5)  # the rings appear by her, then swoop in (the client's flight)
	check(target.hp < hp and Run.mp >= mp, "left click casts Mana Ring at no MP (%d -> %d, MP %d -> %d)" % [hp, target.hp, mp, Run.mp])
	var never := true
	for _i in 60:
		for c: CardData in Run.deck.card_offers(3, false):
			never = never and not c.id in [&"mana_arrow", &"arrow_rush"]
	check(never, "Sheep is never offered Mana Arrow or Arrow Rush")

	# MP regenerates for mages.
	Run.mp = 0
	await wait(1.0)
	check(Run.mp > 0, "a mage regenerates MP over time (%d after 1 s)" % Run.mp)

	# Casting: half the original Delay, locked in place, only a dash gets out.
	Run.start_job(load("res://data/jobs/bard.tres"))
	p.refresh_gear()
	Run.deck.cards[&"seal_of_water"] = 1
	Run.deck.add_card(&"drip_bomb")
	var slot := Run.deck.loadout.find(&"drip_bomb")
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[slot] = 0.0
	var at := p.global_position
	var bomb := Run.deck.card(&"drip_bomb")
	check(is_equal_approx(bomb.cast_at(1), 0.5), "Drip Bomb casts in 0.5 s (the original's 1.0, halved)")
	p.skills.try_cast(slot)
	Input.action_press("move_right")
	p.buffer_action("attack")
	p.take_hit(5, Vector2.LEFT, 300.0, false, 9999)
	await wait(0.25)
	check(p.state == Player.State.SKILL and p.skills.casting_left() > 0.0 and p.global_position.distance_to(at) < 2.0,
		"mid-cast: a hit, a move and an attack press don't move or interrupt the caster")
	Input.action_release("move_right")
	mp = Run.mp
	p.buffer_action("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(p.state == Player.State.DASH and Run.mp > mp, "a dash cancels the cast and refunds its MP (%d -> %d)" % [mp, Run.mp])
	await wait(0.5)

	# Seals shut out two elements; job lists decide who learns what.
	check(not Run.deck.can_learn(Run.deck.card(&"seal_of_fire")) and not Run.deck.can_learn(Run.deck.card(&"seal_of_earth"))
		and Run.deck.can_learn(Run.deck.card(&"seal_of_thunder")), "Seal of Water closes the Fire and Earth seals")
	check(not Run.deck.can_learn(Run.deck.card(&"whirlwind_blaze")), "without Seal of Fire, fire magic isn't offered")
	Run.deck.cards[&"seal_of_thunder"] = 1
	Run.deck.cards[&"electro_attack"] = 3
	check(not Run.deck.requirements_met(Run.deck.card(&"tesla_field")), "Sheep's Tesla Field waits for Mana Ring Lv 3")
	Run.deck.cards[&"mana_ring"] = 3
	check(Run.deck.requirements_met(Run.deck.card(&"tesla_field")), "Mana Ring Lv 3 stands in for Mana Arrow in Sheep's Tesla Field")
	Run.start_job(load("res://data/jobs/witch.tres"))
	check(Run.deck.can_learn(Run.deck.card(&"dark_pact")) and Run.deck.can_learn(Run.deck.card(&"light_pact")), "a Witch can learn Magician skills")
	Run.deck.cards[&"water_shield"] = 2
	Run.start_job(load("res://data/jobs/soul_master.tres"))
	Run.deck.add_card(&"undines_blessing")
	check(Run.deck.card_level(&"water_shield") == 0 and Run.deck.card_level(&"undines_blessing") == 2 and Run.formulas.resist("Water") > 0.0,
		"Undine's Blessing replaces the Water Shield and keeps its resistance (%d%%)" % Run.formulas.resist("Water"))
	_remove(target)

	# Dragon: Shaman, Mana Arrow, and the Priest can't learn dark magic.
	Profile.class_id = "dragon"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"dragon" and Run.job.id == &"shaman" and Run.deck.card_level(&"mana_arrow") == 1,
		"Dragon starts as a Shaman with Mana Arrow")
	never = true
	for _i in 60:
		for c: CardData in Run.deck.card_offers(3, false):
			never = never and not c.id in [&"mana_ring", &"mana_ring_booster"]
	check(never, "Dragon is never offered Mana Ring or Mana Ring Booster")
	Run.start_job(load("res://data/jobs/magician.tres"))
	Run.deck.cards[&"mana_arrow"] = 3
	Run.deck.cards[&"light_pact"] = 1
	check(Run.deck.requirements_met(Run.deck.card(&"light_wave")), "Mana Arrow stands in for Mana Ring in Dragon's Light Wave")
	Run.deck.cards.erase(&"light_pact")
	Run.start_job(load("res://data/jobs/priest.tres"))
	check(not Run.deck.can_learn(Run.deck.card(&"dark_pact")) and Run.deck.can_learn(Run.deck.card(&"light_pact")), "a Priest can't learn dark magic")
	Run.start_job(load("res://data/jobs/wizard.tres"))
	check(Run.deck.can_learn(Run.deck.card(&"seal_of_fire")), "a Wizard can learn Bard skills")

	# Element resistance now applies to spells.
	var foe := await _dummy(p, 60.0)
	foe.elements = {"Fire": 50}
	hp = foe.hp
	p.deal_hit(foe, 100.0, 1.0, 0.0, false, {"element": "Fire"})
	var fire_hit := hp - foe.hp
	hp = foe.hp
	p.deal_hit(foe, 100.0, 1.0, 0.0, false, {})
	check(fire_hit < hp - foe.hp, "a monster resists the element it's strong against (%d vs %d)" % [fire_hit, hp - foe.hp])
	_remove(foe)

	# Every Magic spell does its job on a dummy.
	var spells: Array[CardData] = []
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/magic/") and not c.id in [&"basic_healing", &"med_cure"]:
			spells.append(c)
	check(spells.size() == 50, "the Magic line has 50 spells in play: %d" % spells.size())
	for c in spells:
		var kind := c.behavior.resource_path.get_file()
		var near := kind in ["spell_nova.gd", "spell_whisper.gd"] or c.id == &"hinder_snare"
		var dummy := await _dummy(p, 45.0 if near else 90.0)
		dummy.elements = {}
		var before := dummy.hp
		Run.deck.cards[c.id] = 1
		Run.deck.loadout[0] = c.id
		Run.mp = Run.max_mp
		Run.hp = Run.max_hp / 2
		var hp0 := Run.hp
		p.skills.slot_ready_at[0] = 0.0
		p.invulnerable_until = p.now() + 9.0
		var cast := p.skills.try_cast(0)
		var pin := dummy.global_position
		# Dimensional Rift lingers; Mana Arrow and Mana Ring wait by you before they fly in.
		var until := p.now() + (4.5 if c.id == &"dimensional_rift" else 3.0 if c.id in [&"mana_arrow", &"mana_ring"] else 2.2)
		while p.now() < until:
			if is_instance_valid(dummy):
				dummy.global_position = pin  # it would walk out of fields and bursts
			await get_tree().physics_frame
		var did := false
		var how := ""
		if kind == "spell_heal.gd":
			did = Run.hp > hp0
			how = "heals %d -> %d" % [hp0, Run.hp]
		elif kind == "spell_debuff.gd":
			did = dummy.hp < before or not dummy.debuffs.is_empty()
			how = "debuffs %s, %d -> %d" % [dummy.debuffs.keys(), before, dummy.hp]
		elif c.id in [&"undines_garden", &"raions_space", &"salamanders_territory", &"gnomes_domain", &"sylphs_playground"]:
			did = dummy.debuffs.keys().any(func(k: String) -> bool: return k.begins_with("resist_"))
			how = "lowers %s" % [dummy.debuffs.keys()]
		else:
			did = dummy.hp < before
			how = "%d -> %d" % [before, dummy.hp]
		check(cast and did, "%s casts and works (%s)%s" % [c.id, how, "" if did else _why(cast, dummy, p)])
		Run.deck.cards.erase(c.id)
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)


## The Sense line: Fox and Lion, the gun's cycle, every Sense skill.
func sense_line() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id

	# Fox: Archeologist, Shuriken Master on the attack button, no MP.
	Profile.class_id = "fox"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"fox" and Run.job.id == &"archeologist" and Run.deck.card_level(&"shuriken_master") == 1
		and p.sprite.actor_name == "fox", "Fox starts as an Archeologist with Shuriken Master as her basic attack")
	var target := await _dummy(p, 90.0)
	var mp := Run.mp
	var hp := target.hp
	p.buffer_action("attack")
	await wait(0.9)
	check(target.hp < hp and Run.mp >= mp, "left click throws a hidden weapon at no MP (%d -> %d)" % [hp, target.hp])
	_remove(target)

	# Lion: Engineer, a gun, Gun Carrier, and the gun's cycle.
	Profile.class_id = "lion"
	Run.new_run()
	p.refresh_gear()
	p.velocity = Vector2.ZERO
	var gun := p.gun
	check(Run.cls.id == &"lion" and Run.job.id == &"engineer" and Run.deck.card_level(&"gun_carrier") > 0
		and Run.gear.carries_gun() and gun.has_gun(), "Lion starts as an Engineer carrying a gun (Gun Carrier)")
	check(Run.deck.card_level(&"quick_reload") > 0 and Run.deck.card_level(&"overcharge") == 0 and not gun.charges(),
		"Lion starts with Quick Reload; the power gauge waits for Overcharge")
	check(gun.range() > 300.0, "the gun outranges the spells (%d)" % gun.range())
	var basic_hit := Run.formulas.GUN_SHOT * Run.formulas.gun_shot_mult()
	var weakest := INF
	for id: StringName in [&"power_shot", &"double_shot", &"butt_plate", &"shooting_spree", &"berserk"]:
		var c := Run.deck.card(id)
		var per_hit := c.value_at(1) * Run.formulas.skill_mult(c) / maxf(c.param("count", 1, 1.0), 1.0)
		weakest = minf(weakest, per_hit)
	check(weakest > basic_hit, "every gun skill outhits a basic shot (weakest %d vs %d)" % [weakest, basic_hit])
	var reload := gun.reload_time()
	check(is_equal_approx(reload, 120.0 / 90.0), "the Old Ebony Gun reloads in 120000/GaugeSpeed ms (%.2f s)" % reload)
	target = await _dummy(p, 120.0)
	p.invulnerable_until = p.now() + 30.0  # a monster's hit would reset the reload
	for e: Enemy in game.room.enemies:
		if e != target:
			e.apply_debuff("hold", 1.0, 30.0)
	gun.equip(gun.gun)
	await wait(reload + 0.2)
	check(gun.loaded(), "standing still, the gun loads")
	hp = target.hp
	p.buffer_action("attack")
	await wait(0.4)
	check(target.hp < hp and gun.state == GunCycle.State.RELOADING,
		"a shot hits the line (%d -> %d) and starts the reload at once" % [hp, target.hp])
	# What resets a reload.
	gun.progress = 100.0
	p.start_dash()
	check(gun.progress == 0.0, "a dash resets the reload")
	gun.progress = 100.0
	gun.interrupt(true)
	check(gun.progress == 0.0, "a hit resets the reload")
	Run.deck.cards[&"invincible_reload"] = 1
	gun.progress = 100.0
	gun.interrupt(true)
	check(gun.progress == 100.0, "Invincible Reload keeps the reload through a hit")
	Run.deck.cards.erase(&"invincible_reload")
	await wait(0.5)
	Run.deck.cards.erase(&"quick_reload")  # Lion's starter: walking keeps the reload
	p.enter(Player.State.MOVE)
	gun.progress = 100.0
	Input.action_press("move_right")
	await wait(0.3)
	var moved := gun.progress
	Input.action_release("move_right")
	Run.deck.cards[&"quick_reload"] = 1
	gun.progress = 100.0
	Input.action_press("move_right")
	await wait(0.3)
	Input.action_release("move_right")
	check(moved < 50.0 and gun.progress > 100.0,
		"walking resets the reload (%.0f), not with Quick Reload (%.0f)" % [moved, gun.progress])
	Run.deck.cards[&"speedloader"] = 5
	check(gun.reload_time() < reload, "Speedloader shortens the reload (%.2f -> %.2f s)" % [reload, gun.reload_time()])
	check(is_equal_approx(gun.reload_time(), reload / (1.0 + Run.deck.card_value(&"speedloader") / 100.0)),
		"Speedloader raises the fill rate as the client does (2 - Ratio/100)")
	Run.deck.cards.erase(&"speedloader")
	check(Run.deck.grows_basic(Run.deck.card(&"quick_reload")) and Run.deck.grows_basic(Run.deck.card(&"invincible_reload")),
		"a gunner is always offered Quick Reload and Invincible Reload once learnable")
	var ac0 := Run.formulas.gun_stat_mult()
	Run.type_points["power"] += 5  # +10 AC
	Run.stats_changed()
	check(is_equal_approx(Run.formulas.gun_stat_mult(), Run.formulas.gun_attack() / float(Run.ref_stats["AC"])) and Run.formulas.gun_stat_mult() > ac0,
		"gun damage scales with AC (the server's gun formula): x%.2f -> x%.2f" % [ac0, Run.formulas.gun_stat_mult()])
	Run.type_points["power"] -= 5
	Run.stats_changed()
	# The power zone, with Overcharge.
	gun.state = GunCycle.State.LOADED
	gun.power = float(gun.gun.zone) + 5.0
	check(gun.fire() and not gun.last_power, "without Overcharge there is no power shot")
	Run.deck.cards[&"overcharge"] = 1
	gun.state = GunCycle.State.LOADED
	gun.power = float(gun.gun.zone) + 5.0
	check(gun.fire() and gun.last_power, "with Overcharge, a shot fired above PowStartPoint is overcharged")
	Run.deck.cards.erase(&"overcharge")
	# A gun skill fires without a load and leaves the reload alone.
	gun.progress = 60.0
	Run.deck.cards[&"power_shot"] = 1
	Run.deck.loadout[0] = &"power_shot"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	var fired := p.skills.try_cast(0)
	await wait(0.4)
	check(fired and gun.state == GunCycle.State.RELOADING and gun.progress >= 60.0,
		"Power Shot fires mid-reload and doesn't reset it (%.0f)" % gun.progress)
	Run.deck.cards.erase(&"power_shot")
	_remove(target)

	# A wall stops a shot.
	var room: Room = game.room
	var blocked := false
	for _i in 300:
		var at := room.random_spot(Vector2.ZERO, 0.0)
		var d := Vector2.from_angle(TAU * (randi() % 8) / 8.0)
		var far := at + Combat.screen(d) * 150.0
		if room.is_walkable(far) and room.line_clear(at, at + Combat.screen(d) * 30.0) and not room.line_clear(at, far):
			p.global_position = at
			p.enter(Player.State.MOVE)
			p.aim = d
			var behind: Enemy = room.spawn(&"torobbie", far)
			await wait(1.0)
			behind.max_hp = 99999
			behind.hp = 99999
			behind.global_position = far  # it may have walked round the wall
			behind.apply_debuff("hold", 1.0, 5.0)
			gun.state = GunCycle.State.LOADED
			p.skills.slot_ready_at[SkillCaster.BASIC] = 0.0
			p.skills.try_cast(SkillCaster.BASIC)
			await wait(0.3)
			check(behind.hp == 99999, "a wall stops a shot")
			_remove(behind)
			blocked = true
			break
	if not blocked:
		print("SKIP  no wall with open ground behind it found")

	# Every Sense skill does its job on a dummy.
	var skills: Array[CardData] = []
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/sense/") and c.id != &"gun_shot" \
				and not c.id in [&"stone_shower"]:
			skills.append(c)
	for c in skills:
		var kind := c.behavior.resource_path.get_file()
		var dummy := await _dummy(p, 60.0 if kind == "close_strike.gd" else 90.0)
		dummy.elements = {}
		var before := dummy.hp
		Run.deck.cards[c.id] = 1
		Run.deck.loadout[0] = c.id
		Run.mp = Run.max_mp
		Run.hidden = c.id in [&"sudden_attack", &"poison_assault"]
		gun.state = GunCycle.State.LOADED
		p.skills.slot_ready_at[0] = 0.0
		p.invulnerable_until = p.now() + 9.0
		var cast := p.skills.try_cast(0)
		var pin := dummy.global_position
		var until := p.now() + 2.2
		while p.now() < until:
			if is_instance_valid(dummy):
				dummy.global_position = pin
			await get_tree().physics_frame
		var did := false
		var how := ""
		match c.id:
			&"hide":
				did = Run.hidden
				how = "hidden %s" % Run.hidden
			&"bunker":
				did = Run.in_bunker(p.now())
				how = "bunker %d HP" % Run.bunker_hp
			&"bunker_release":
				did = cast
				how = "cast"
			&"sticky_icky", &"shield_breaker":
				did = not dummy.debuffs.is_empty()
				how = "debuffs %s" % [dummy.debuffs.keys()]
			_:
				did = dummy.hp < before
				how = "%d -> %d" % [before, dummy.hp]
		check(cast and did, "%s casts and works (%s)%s" % [c.id, how, "" if did else _why(cast, dummy, p)])
		Run.deck.cards.erase(c.id)
		Run.hidden = false
		Run.bunker_until = 0.0
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0

	# Hybrids, as in the Magic line.
	var hunter_lord: JobData = load("res://data/jobs/hunter_lord.tres")
	var cyber: JobData = load("res://data/jobs/cyber_hunter.tres")
	check(not hunter_lord.unlocked() and not cyber.unlocked(), "Hunter Lord and Cyber Hunter start locked")
	check(Run.deck.card(&"power_shot") in hunter_lord.cards and Run.deck.card(&"fan_of_knives") in cyber.cards,
		"a Hunter Lord learns Inventor skills and a Cyber Hunter Explorer skills")

	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)


## Elemental attack compounds (the server's 0x59c4a0) and their hit effects
## (the client's 0x5c69d0), and no shield beside a gun.
## Every Talent hook does its job (Guard's block is checked in the Power line).
func talent_hooks() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id
	Profile.class_id = "sheep"
	Run.new_run()
	p.refresh_gear()
	var foe := await _dummy(p, 60.0)
	p.invulnerable_until = 0.0

	# tick and absorb: Shield of Heaven's barrier fills, then takes a hit first.
	Run.deck.cards[&"shield_of_heaven"] = 1
	p._tick_talents(0.016)
	var barrier := roundi(Run.stat("MA") * Run.deck.card(&"shield_of_heaven").value_at(1) / 100.0)
	check(barrier > 0 and Run.barrier == barrier, "Shield of Heaven's barrier fills to its share of MA (%d)" % Run.barrier)
	var hp := Run.hp
	p.take_hit(1, Vector2.LEFT, 0.0, false, 9999)
	check(Run.hp == hp and Run.barrier < barrier, "the barrier takes a hit before your HP (%d left)" % Run.barrier)
	Run.deck.cards.erase(&"shield_of_heaven")
	Run.barrier = 0

	# tick: Oath of Light heals every 10 s.
	Run.deck.cards[&"oath_of_light"] = 1
	Run.hp = Run.max_hp / 2
	hp = Run.hp
	for _i in 11:
		p._tick_talents(1.0)
	check(Run.hp > hp, "Oath of Light heals every 10 s (%d -> %d)" % [hp, Run.hp])
	Run.deck.cards.erase(&"oath_of_light")

	# tick: Berserker's rage costs HP while a monster is around.
	Run.deck.cards[&"berserker"] = 1
	Run.hp = Run.max_hp
	hp = Run.hp
	for _i in 3:
		p._tick_talents(1.0)
	check(Run.hp < hp, "Berserker drains HP in a fight (%d -> %d)" % [hp, Run.hp])
	Run.deck.cards.erase(&"berserker")

	# retaliate: Dark Barrier turns a physical hit back, Mana Reflector a magic one.
	for id: StringName in [&"dark_barrier", &"mana_reflector"]:
		Run.deck.cards[id] = 5
		var before := foe.hp
		for t in Run.deck.talents():
			t.retaliate(p, foe, 200, id == &"mana_reflector")
		check(foe.hp < before, "%s strikes back at the attacker (%d -> %d)" % [id, before, foe.hp])
		Run.deck.cards.erase(id)

	# revive: Revival brings you back with its share of max HP, then waits its cooldown.
	Run.deck.cards[&"revival"] = 1
	Run.revival_ready_at = 0.0
	Run.hp = 0
	var back := Run.try_revive()
	check(back and Run.hp == maxi(1, roundi(Run.max_hp * Run.deck.card(&"revival").value_at(1) / 100.0))
		and Run.revival_ready_at > Events.time, "Revival brings you back from a fatal blow (%d HP)" % Run.hp)
	Run.deck.cards.erase(&"revival")
	Run.hp = Run.max_hp

	# on_cast: Blood Testament makes a spell cost HP.
	Run.deck.cards[&"blood_testament"] = 1
	var spell: CardData = Run.deck.all_cards().filter(func(c: CardData) -> bool: return c.is_skill() and c.cast_at(1) > 0.0)[0]
	hp = Run.hp
	for t in Run.deck.talents():
		t.on_cast(spell, 1, 0)
	check(Run.hp < hp, "Blood Testament: casting %s costs HP (%d -> %d)" % [spell.id, hp, Run.hp])
	Run.deck.cards.erase(&"blood_testament")
	Run.hp = Run.max_hp

	# adjust: Desperate Rally raises your damage low on HP; Sharp Sense the power shot.
	var full := Run.formulas.attack_mult()
	Run.deck.cards[&"desperate_rally"] = 3
	Run.hp = 1
	check(Run.formulas.attack_mult() > full, "Desperate Rally hits harder near death (x%.2f -> x%.2f)" % [full, Run.formulas.attack_mult()])
	Run.deck.cards.erase(&"desperate_rally")
	Run.hp = Run.max_hp
	Run.deck.cards[&"sharp_sense"] = 1
	var keen: CardData = Run.deck.card(&"keen_sense")
	var want := (100.0 + keen.value_at(Run.deck.MAX_CARD_LEVEL)) * (1.0 + Run.deck.card(&"sharp_sense").value_at(1) / 100.0) - 100.0
	check(is_equal_approx(Run.formulas.power_shot_bonus(), want), "Sharp Sense builds on a mastered Keen Sense (+%.0f%%)" % Run.formulas.power_shot_bonus())
	Run.deck.cards.erase(&"sharp_sense")

	_remove(foe)
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.3)


func elements_and_shields() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id
	Profile.class_id = "buffalo"
	Run.new_run()
	p.refresh_gear()
	var w := Run.gear.equipped("weapon")
	var target := await _dummy(p, 60.0)
	target.elements = {}
	# A plain hit, then one with Fire and Water compounded on the weapon.
	var plain := 0
	var hp := target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	plain = hp - target.hp
	w.slots = maxi(w.slots, 2)
	w.compounds.clear()
	w.compounds.append({"material": "cocos_shell", "stat": "Fire", "value": 20})
	w.compounds.append({"material": "cool_ice", "stat": "Water", "value": 10})
	Run.stats_changed()
	target.set_meta("element_fx_at", -INF)
	hp = target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	var with_el := hp - target.hp
	var fx: Array[String] = []
	for n: Node in game.room.get_children():
		if n is Cake and (n as Cake).effect.begins_with("element_"):
			fx.append((n as Cake).effect)
	check(absf(float(with_el) / plain - 1.3) < 0.05, "Fire 20%% and Water 10%% add 30%% to the hit (%d -> %d)" % [plain, with_el])
	check("element_fire" in fx and "element_ice" in fx, "each element plays its own hit effect at once %s" % [fx])
	# Resistance takes its share off that element only; physical resistance off the hit.
	target.elements = {"Fire": 50}
	hp = target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	var resisted := hp - target.hp
	check(absf(float(resisted) / plain - 1.2) < 0.05, "50%% Fire resistance halves the Fire part (%d)" % resisted)
	target.elements = {"Physical": 40}
	w.compounds.clear()
	Run.stats_changed()
	hp = target.hp
	p.deal_hit(target, 100.0, 1.0, 0.0, false, {"no_crit": true, "no_graze": true})
	check(absf(float(hp - target.hp) / plain - 0.6) < 0.05, "40%% physical resistance takes 40%% off a hit (%d)" % (hp - target.hp))
	check(target.attack_element() == "", "physical resistance is never a monster's attack element")
	var mats: Array[String] = []
	for r in Run.route.regions:
		for e in r.enemies:
			if e.material and e.material.is_element():
				mats.append(e.material.stat)
	for k: String in MaterialData.ELEMENTS:
		check(k in mats, "a monster drops a %s attack material" % k)
	_remove(target)

	# Shields and guns.
	Profile.class_id = "lion"
	Run.new_run()
	p.refresh_gear()
	var offered_shield := false
	for i in 40:
		Run.route.depth = i % 16
		for g in Run.gear.gear_offers(3):
			offered_shield = offered_shield or g.data.slot == ItemData.Slot.SHIELD
	Run.route.depth = 0
	check(not offered_shield, "a gunner is never offered a shield")
	Profile.class_id = "fox"
	Run.new_run()
	Run.deck.cards[&"gun_carrier"] = 1
	var shield := GearItem.roll(load("res://data/items/wood_buckler.tres"), 0.0)
	Run.gear.equip(shield)
	check(Run.gear.equipped("shield") == shield, "Fox wears a shield with a sword")
	Run.gear.equip(GearItem.roll(load("res://data/items/ebony_gun.tres"), 0.0))
	check(Run.gear.carries_gun() and Run.gear.equipped("shield") == null and shield in Run.gear.displaced,
		"taking up a gun puts the shield away")
	check(Run.gear.equip(shield) == null and Run.gear.equipped("shield") == null, "no shield goes on beside a gun")
	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.3)


## The Charm line: Cat and Raccoon, the server's HV-weighted attacks, the
## beast forms, Galder, and every Charm skill on a dummy.
func charm_line() -> void:
	var p: Player = game.player
	var saved: String = Profile.class_id

	Profile.class_id = "raccoon"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"raccoon" and Run.job.id == &"teacher" and p.sprite.actor_name == "raccoon",
		"Raccoon starts as a Teacher")
	Profile.class_id = "cat"
	Run.new_run()
	p.refresh_gear()
	check(Run.cls.id == &"cat" and Run.job.id == &"model" and Run.deck.card_level(&"power_blow") == 1
		and p.sprite.actor_name == "cat" and Run.cls.basic_skill == null,
		"Cat starts as a Model with Power Blow, fighting with her weapon's combo")

	# The server's attacks: Volley Kick is AP + 16 HV, so Charm points (HV)
	# grow it far more than Power Blow (AP alone); Final Blow grows with the
	# HP you've lost.
	check(is_equal_approx(Run.formulas.attack_power("AP+16HV"), Run.stat("AP") + 16.0 * Run.stat("HV")),
		"Run.formulas.attack_power reads the server's expression (AP + 16 HV = %d)" % Run.formulas.attack_power("AP+16HV"))
	var kick := Run.deck.card(&"volley_kick")
	var blow := Run.deck.card(&"power_blow")
	var final := Run.deck.card(&"final_blow")
	var kick0 := Run.formulas.skill_mult(kick)
	var blow0 := Run.formulas.skill_mult(blow)
	check(is_equal_approx(kick0, 1.0) and is_equal_approx(blow0, 1.0), "at level 1 the multipliers start at 1")
	Run.type_points["charm"] += 5  # +10 HV
	Run.stats_changed()
	var kick1 := Run.formulas.skill_mult(kick)
	check(kick1 > 1.5 and is_equal_approx(Run.formulas.skill_mult(blow), 1.0),
		"Charm points grow Volley Kick (x%.2f) but not Power Blow (x%.2f)" % [kick1, Run.formulas.skill_mult(blow)])
	Run.type_points["charm"] -= 5
	Run.stats_changed()
	var fb0 := Run.formulas.skill_mult(final)
	Run.hp = Run.max_hp / 2
	check(Run.formulas.skill_mult(final) > fb0, "Final Blow hits harder the more HP you've lost (x%.2f -> x%.2f)" % [fb0, Run.formulas.skill_mult(final)])
	Run.hp = Run.max_hp
	check(Run.formulas.skill_mult(Run.deck.card(&"wild_nail")) == Run.formulas.attack_power("16HV") / Run.formulas.attack_power("16HV", true),
		"Wild Nail is HV alone")

	# Evolution is a talent: learned, Cat is the beast (trs001) for good, with
	# no MP drain; only Evolution's skills work, and only they are offered.
	# Beast's Instinct is timed on top of it, and Evolution outlasts it.
	check(not Run.deck.card(&"evolution").is_skill(), "Evolution is a talent")
	check(not Run.deck.requirements_met(Run.deck.card(&"beast_claw")) and not Run.deck.requirements_met(Run.deck.card(&"fatal_wound")),
		"Evolution's skills aren't offered before it")
	var ap0 := Run.stat("AP")
	var dp0 := Run.stat("DP")
	Run.deck.add_card(&"evolution")
	p.become_beast()
	check(Run.form == &"evolution" and p.sprite.actor_name == "beast_evolution" and Run.stat("AP") > ap0
		and Run.stat("DP") < dp0, "Evolution turns Cat into the beast (trs001): AP %d -> %d, DP %d -> %d" % [ap0,
		Run.stat("AP"), dp0, Run.stat("DP")])
	check(p.combo == Player.BEAST_COMBO and not p.weapon.visible, "the beast fights with its claws, no weapon")
	check(Run.deck.requirements_met(Run.deck.card(&"beast_claw")) and Run.deck.requirements_met(Run.deck.card(&"fatal_wound")),
		"with it, Beast Claw and Fatal Wound open up")
	Run.mp = Run.max_mp / 2
	var mp1 := Run.mp
	await wait(1.2)
	check(Run.form == &"evolution" and Run.mp >= mp1, "Evolution never drains MP or ends (MP %d -> %d)" % [mp1, Run.mp])
	Run.mp = Run.max_mp
	for id: StringName in [&"volley_kick", &"beast_claw", &"wild_nail"]:
		Run.deck.cards[id] = 1
	Run.deck.loadout = [&"volley_kick", &"beast_claw", &"wild_nail"] as Array[StringName]
	for i in 3:
		p.skills.slot_ready_at[i] = 0.0
	check(not p.skills.try_cast(0) and Run.form_block(&"volley_kick") == "Not in Evolution",
		"Volley Kick doesn't work in Evolution")
	check(not p.skills.try_cast(2), "nor Wild Nail, Metamorphosis's")
	check(p.skills.try_cast(1), "Beast Claw does")
	await wait(0.8)
	var ent: JobData = load("res://data/jobs/entertainer.tres")
	var job_e := Run.job
	Run.jobs.append(ent)
	Run.job = ent
	var offered_e: Array[StringName] = []
	for i in 20:
		for c in Run.deck.card_offers(3, false):
			if c.is_skill():
				offered_e.append(c.id)
	var stray_e := offered_e.filter(func(id: StringName) -> bool: return not Run.form_allows(id))
	check(stray_e.is_empty(), "Evolution is only offered skills it can use: %s" % [offered_e if stray_e.is_empty() else stray_e])
	Run.jobs.erase(ent)
	Run.job = job_e
	Run.deck.cards[&"beasts_instinct"] = 1
	Run.deck.loadout[0] = &"beasts_instinct"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	check(p.skills.try_cast(0), "Beast's Instinct casts in Evolution")
	await wait(0.7)
	var ap_i := Run.stat("AP")
	check(Run.instinct and not p.skills.try_cast(1), "in Beast's Instinct, no skills (AP %d)" % ap_i)
	mp1 = Run.mp
	await wait(1.0)
	check(Run.mp < mp1, "Beast's Instinct drains MP (%d -> %d)" % [mp1, Run.mp])
	p.instinct_until = p.now()
	await wait(0.2)
	check(not Run.instinct and Run.form == &"evolution" and Run.stat("AP") < ap_i, "when it ends, Evolution stays")
	for id: StringName in [&"evolution", &"volley_kick", &"beast_claw", &"wild_nail", &"beasts_instinct"]:
		Run.deck.cards.erase(id)
	Run.deck.loadout = [&"", &"", &""] as Array[StringName]
	Run.form = &""
	Run.stats_changed()
	p.refresh_gear()
	check(p.sprite.actor_name == "cat", "back to Cat for the next checks")

	# Metamorphosis is a talent: learned, you're the beast for good, with no
	# MP drain; only beast skills work, and only they are offered.
	var meta := Run.deck.card(&"metamorphosis")
	check(not meta.is_skill(), "Metamorphosis is a talent")
	check(not Run.deck.requirements_met(Run.deck.card(&"wild_nail")) and not Run.deck.requirements_met(Run.deck.card(&"card_soldier")),
		"Metamorphosis's skills aren't offered before it")
	ap0 = Run.stat("AP")
	dp0 = Run.stat("DP")
	Run.deck.add_card(&"metamorphosis")
	p.become_beast()
	check(Run.form == &"metamorphosis" and p.sprite.actor_name == "beast_metamorphosis" and Run.stat("DP") > dp0
		and Run.stat("AP") < ap0, "Metamorphosis turns you into the beast (trs002): DP %d -> %d, AP %d -> %d" % [dp0,
		Run.stat("DP"), ap0, Run.stat("AP")])
	check(Run.deck.requirements_met(Run.deck.card(&"wild_nail")) and Run.deck.requirements_met(Run.deck.card(&"heavy_hit"))
		and Run.deck.requirements_met(Run.deck.card(&"card_soldier")), "with it, Wild Nail, Heavy Hit and Card Soldier open up")
	Run.mp = Run.max_mp / 2
	mp1 = Run.mp
	await wait(1.2)
	check(Run.form == &"metamorphosis" and Run.mp >= mp1, "it never drains MP or ends (MP %d -> %d)" % [mp1, Run.mp])
	Run.mp = Run.max_mp
	Run.deck.cards[&"card_strike"] = 1
	Run.deck.cards[&"wild_nail"] = 1
	Run.deck.loadout[0] = &"card_strike"
	Run.deck.loadout[1] = &"wild_nail"
	p.skills.slot_ready_at[0] = 0.0
	p.skills.slot_ready_at[1] = 0.0
	check(not p.skills.try_cast(0) and Run.form_block(&"card_strike") != "", "Card Strike doesn't work in Metamorphosis")
	check(p.skills.try_cast(1), "Wild Nail does")
	await wait(0.6)
	var cm: JobData = load("res://data/jobs/card_master.tres")
	var job0 := Run.job
	Run.jobs.append(cm)
	Run.job = cm
	var offered: Array[StringName] = []
	for i in 20:
		for c in Run.deck.card_offers(3, false):
			if c.is_skill():
				offered.append(c.id)
	var stray := offered.filter(func(id: StringName) -> bool: return not Run.form_allows(id))
	check(stray.is_empty() and &"wild_nail" in Run.deck.card_pool().map(func(c: CardData) -> StringName: return c.id),
		"a beast is only offered skills it can use: %s" % [offered if stray.is_empty() else stray])
	Run.jobs.erase(cm)
	Run.job = job0
	for id: StringName in [&"metamorphosis", &"card_strike", &"wild_nail"]:
		Run.deck.cards.erase(id)
	Run.deck.loadout[0] = &""
	Run.deck.loadout[1] = &""
	Run.form = &""
	Run.stats_changed()
	p.refresh_gear()

	# Galder: spent from the run's purse; short of it, no cast.
	Run.deck.cards[&"galder_thrower"] = 1
	Run.deck.loadout[0] = &"galder_thrower"
	Run.purse.galder = 5
	p.skills.slot_ready_at[0] = 0.0
	check(not p.skills.try_cast(0), "Galder Thrower needs its Galder")
	Run.purse.galder = 100
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	check(p.skills.try_cast(0) and Run.purse.galder == 80, "Galder Thrower spends 20 Galder (100 -> %d)" % Run.purse.galder)
	await wait(0.5)

	# Every Charm skill does its job on a dummy.
	var skills: Array[CardData] = []
	for c in Run.deck.all_cards():
		if c.is_skill() and c.resource_path.begins_with("res://data/skills/charm/"):
			skills.append(c)
	check(skills.size() == 27, "the Charm line has 27 active skills: %d" % skills.size())
	for c in skills:
		var kind := c.behavior.resource_path.get_file()
		var ahead := 60.0 if kind == "charm_strike.gd" else 120.0 if kind in ["card_throw.gd", "pouch_throw.gd", "galder_barrage.gd"] else 50.0
		var dummy := await _dummy(p, ahead)
		dummy.elements = {}
		var extra: Array[Enemy] = []
		if c.id == &"four_of_a_kind":
			for i in 3:
				var e2: Enemy = game.room.spawn(&"torobbie", dummy.global_position + Vector2(10 * (i + 1), 8))
				extra.append(e2)
			await wait(0.6)
			for e2 in extra:
				e2.max_hp = 99999
				e2.hp = 99999
		var before := dummy.hp
		p.end_instinct()
		Run.form = &""  # the forms don't end on their own
		Run.deck.cards.erase(&"metamorphosis")
		Run.deck.cards.erase(&"evolution")
		Run.deck.cards[c.id] = 1
		Run.deck.loadout[0] = c.id
		if c.form != &"":
			var need: StringName = c.form
			Run.form = need if need != &"beast" else &"metamorphosis"
			Run.deck.cards[Run.form] = 1
			Run.stats_changed()
		Run.mp = Run.max_mp
		Run.hp = Run.max_hp
		Run.purse.galder = 500
		p.skills.slot_ready_at[0] = 0.0
		p.invulnerable_until = p.now() + 9.0
		var hp_before := Run.hp
		var cast := p.skills.try_cast(0)
		var pin := dummy.global_position
		var until := p.now() + 2.2
		while p.now() < until:
			if is_instance_valid(dummy):
				dummy.global_position = pin
			await get_tree().physics_frame
		var did := false
		var how := ""
		match c.id:
			&"beasts_instinct":
				did = Run.instinct and Run.form == &"evolution"
				how = "instinct %s" % Run.instinct
			&"flux_capacitor":
				did = Run.hp < hp_before
				how = "HP %d -> %d" % [hp_before, Run.hp]
			&"skunk_pouch", &"deadly_funk":
				did = dummy.state == Enemy.State.HURT
				how = "state %s" % dummy.state
			&"full_house":
				# One card in five is a bad hand (BAD_HAND) that hurts you instead.
				did = dummy.hp < before or Run.hp < hp_before
				how = "%d -> %d, HP %d -> %d" % [before, dummy.hp, hp_before, Run.hp]
			_:
				did = dummy.hp < before
				how = "%d -> %d" % [before, dummy.hp]
		check(cast and did, "%s casts and works (%s)%s" % [c.id, how, "" if did else _why(cast, dummy, p)])
		p.end_instinct()
		Run.form = &""
		Run.deck.cards.erase(c.id)
		for e2 in extra:
			_remove(e2)
		_remove(dummy)
		await wait(0.3)
	p.invulnerable_until = 0.0
	check(Run.deck.card(&"galder_barrage") in (load("res://data/echoes/echo_entertainer.tres") as EnemyData).runes,
		"the Echo of an Entertainer lends the Charm line's own Galder Barrage")

	# Hybrids.
	var diva: JobData = load("res://data/jobs/diva.tres")
	var duke: JobData = load("res://data/jobs/duke.tres")
	check(not diva.unlocked() and not duke.unlocked(), "Diva and Duke start locked")
	check(Run.deck.card(&"card_strike") in diva.cards and Run.deck.card(&"volley_kick") in duke.cards
		and not Run.deck.card(&"evolution") in duke.cards and not Run.deck.card(&"metamorphosis") in diva.cards,
		"a Diva learns Card Master skills and a Duke Entertainer skills, but not the other's beast")

	Profile.class_id = saved
	Run.new_run()
	p.refresh_gear()
	await wait(0.5)
