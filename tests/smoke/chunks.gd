extends SmokeSection
## Chunks: a run is one chunk of three regions in one job tier. The chunk data, the choice of chunk,
## card gating by the chunk's pace, and the veteran start of a later chunk (its level, jobs, type
## points, carried cards and weapon). Chunk 2's regions aren't built yet, so its veteran start is
## checked on a stand-in chunk 2 that plays chunk 1's regions.

var _saved: Dictionary = {}


func run(Run: Node) -> void:
	_save(Run)
	_chunk_data(Run)
	_exports(Run)
	_gating(Run)
	_choice(Run)
	_veteran(Run)
	_cards(Run)
	_build_and_arms(Run)
	_packs(Run)
	await _draft_by_keys(Run)
	await _gate(Run)
	await _branches(Run)
	_restore(Run)


func _save(Run: Node) -> void:
	_saved = {"chunks": Profile.chunks.duplicate(), "choice": Profile.chunk_choice.duplicate(),
		"builds": Profile.builds.duplicate(), "class": Profile.class_id, "loadout": Profile.loadout.duplicate(),
		"route_chunks": Run.route.chunks.duplicate()}


func _restore(Run: Node) -> void:
	Profile.chunks = _saved.chunks
	Profile.chunk_choice = _saved.choice
	Profile.builds = _saved.builds
	Profile.class_id = _saved.class
	Profile.loadout = _saved.loadout
	Run.route.chunks.assign(_saved.route_chunks)
	Run.veteran.cards_override = ""
	Run.new_run()


## A stand-in chunk 2: the shipped chunk's numbers on chunk 1's regions played backwards (so it
## starts in the Relics' item band, as a later chunk starts high), with `cards` as its veteran
## cards.
func _stand_in(Run: Node, cards: String) -> ChunkData:
	var real: ChunkData = Run.route.chunk_numbered(2)
	var c: ChunkData = real.duplicate()
	var regions: Array[RegionData] = Run.route.chunk_numbered(1).regions.duplicate()
	regions.reverse()
	c.regions = regions
	c.veteran_cards = cards
	Run.route.chunks[Run.route.chunks.find(real)] = c
	return c


## Plays a fresh Buffalo run in chunk 2 (open, chosen), on the stand-in with `cards`.
func _buffalo_in_chunk_2(Run: Node, cards: String) -> ChunkData:
	Run.route.chunks.assign(_saved.route_chunks)
	var c := _stand_in(Run, cards)
	Profile.class_id = "buffalo"
	Profile.chunks["buffalo"] = 1
	Profile.chunk_choice["buffalo"] = 2
	Profile.loadout = {}
	Run.new_run(7)
	return c


func _chunk_data(Run: Node) -> void:
	var one: ChunkData = Run.route.chunk_numbered(1)
	var two: ChunkData = Run.route.chunk_numbered(2)
	check(one != null and one.route_text() == "Coral Beach > Desert Beach > Caballa Relics" and one.start_level == 1
		and one.job_tier == 1 and one.opened_by == 0, "chunk 1 is Coral Beach to the Relics, from Lv 1 in the 1st job, open from the start")
	check(two != null and two.start_level == 54 and two.job_tier == 2 and two.opened_by == 1 and two.tm_open == 61,
		"chunk 2 starts at Lv 54 in the 2nd job, opened by a chunk 1 clear, its cards open to TM 61")
	Profile.chunks.erase("buffalo")
	check(one.open_for("buffalo") and not two.open_for("buffalo"), "chunk 2 is closed to a Buffalo without a chunk 1 clear")
	Profile.chunks["buffalo"] = 1
	check(two.open_for("buffalo") and not two.open_for("bunny"), "a Buffalo's chunk 1 clear opens chunk 2 for the Buffalo only")


## Chunk 1's gating is the one it always had (TM 20 open, 0.6 levels per TM level).
func _gating(Run: Node) -> void:
	Profile.class_id = "buffalo"
	Profile.chunk_choice.erase("buffalo")
	Run.new_run(7)
	var at: Dictionary = {}
	for id: StringName in [&"bulls_eye", &"burning_rave", &"hyper_beat", &"tornado_bomb"]:
		at[id] = Run.deck.unlock_level(Run.deck.card(id))
	check(at == {&"bulls_eye": 1, &"burning_rave": 1, &"hyper_beat": 15, &"tornado_bomb": 18},
		"chunk 1 offers a Fighter's cards by TM level: Hyper Beat at Lv 15, Tornado Bomb at Lv 18 (%s)" % at)


func _choice(Run: Node) -> void:
	Run.route.chunks.assign(_saved.route_chunks)
	Profile.class_id = "buffalo"
	Profile.chunk_choice["buffalo"] = 2
	Profile.chunks.erase("buffalo")
	Run.new_run(7)
	check(Run.route.chunk.number == 1, "choosing a closed chunk 2 still plays chunk 1")
	Profile.chunks["buffalo"] = 1
	Run.new_run(7)
	check(Run.route.chunk.number == 1, "an open chunk 2 not yet built (%d of 3 regions) plays chunk 1" % Run.route.chunk_numbered(2).regions.size())
	_buffalo_in_chunk_2(Run, "max")
	check(Run.route.chunk.number == 2 and Run.route.regions == Run.route.chunk.regions and Run.route.plan[-1].boss,
		"an open, built chunk 2 is played when chosen: its regions, %d rooms to its last boss" % Run.route.plan.size())


func _veteran(Run: Node) -> void:
	Profile.builds.erase("buffalo")
	var c := _buffalo_in_chunk_2(Run, "max")
	var ids: Array = Run.jobs.map(func(j: JobData) -> StringName: return j.id)
	check(Run.level == 54 and ids == [&"fighter", &"knight"] and Run.job.id == &"knight" and Run.actor() == "knight",
		"a chunk 2 run starts at Lv 54 as a Knight, the Fighter behind it (%s)" % [ids])
	var pts := 0
	for t: String in Run.type_points:
		pts += int(Run.type_points[t])
	check(pts == 53 and Run.type_points == {"power": 27, "magic": 5, "sense": 5, "charm": 16} and Run.pending_levels == 0,
		"its 53 level-ups' type points follow the Buffalo's graph without a clear's build (%s)" % Run.type_points)
	var lv1: Dictionary = Run.ref_stats.duplicate()
	Profile.chunk_choice.erase("buffalo")
	Run.new_run(7)
	var fresh: Dictionary = Run.ref_stats.duplicate()
	_buffalo_in_chunk_2(Run, "max")
	check(lv1 == fresh and Run.formulas.attack_mult() > 4.0,
		"damage stays linear against the level-1 character: a Lv 54 Knight hits x%.1f" % Run.formulas.attack_mult())
	var faint: CardData = Run.deck.card(&"faint")
	var inferno: CardData = Run.deck.card(&"inferno_blade")
	check(Run.deck.unlock_level(faint) == 54 and Run.deck.unlock_level(inferno) == 53 + ceili((125 - c.tm_open) * c.tm_pace),
		"a Knight's cards come by chunk 2's pace: Faint from Lv 54, Inferno Blade at Lv %d" % Run.deck.unlock_level(inferno))
	var offered: Array = Run.deck.card_offers(12, false, Run.job).map(func(x: CardData) -> StringName: return x.id)
	check(offered.all(func(id: StringName) -> bool: return Run.deck.card(id).tm_level <= c.tm_open) and &"faint" in offered,
		"a new Knight is offered only the cards up to TM %d (%s)" % [c.tm_open, offered])


func _cards(Run: Node) -> void:
	_buffalo_in_chunk_2(Run, "max")
	var fighter: JobData = Run.jobs[0]
	var short: PackedStringArray = []
	for card: CardData in fighter.cards:
		if Run.deck.card_level(card.id) != Run.deck.card_cap(card.id):
			short.append("%s %d" % [card.id, Run.deck.card_level(card.id)])
	var slotted: Array = Run.deck.loadout.filter(func(id: StringName) -> bool: return id != &"")
	check(short.is_empty() and slotted.size() == 3 and Run.veteran.draft_left == 0,
		"\"max\": every Fighter card at its cap, three skills slotted (%s)%s" % [Run.deck.loadout, "" if short.is_empty() else ": " + ", ".join(short)])
	check(Run.deck.unlock_level(Run.deck.card(&"tornado_bomb")) == 1, "a veteran's 1st-job cards are never gated")
	# Every character: the whole 1st-job tree but what it can't hold (a beast form, a card that
	# shuts out one it has, the other mage's basic spell), and three skills in the slots.
	var report: PackedStringArray = []
	var ok := true
	for cls: ClassData in Run.classes:
		Profile.class_id = String(cls.id)
		Profile.chunks[String(cls.id)] = 1
		Profile.chunk_choice[String(cls.id)] = 2
		Run.new_run(7)
		var tree: Array[CardData] = cls.start_job.cards
		var missing: PackedStringArray = []
		for card in tree:
			if Run.deck.card_level(card.id) == 0 and card.form_actor == "" and not card.id in cls.excluded_cards \
					and card.excludes.all(func(x: StringName) -> bool: return Run.deck.card_level(x) == 0):
				missing.append(String(card.id))
		var skills: int = Run.deck.loadout.filter(func(id: StringName) -> bool: return id != &"").size()
		ok = ok and missing.is_empty() and Run.job.tier == 2 and skills == mini(3, tree.filter(
			func(x: CardData) -> bool: return x.is_skill() and not Run.deck.is_basic(x.id) and x.form == &"").size())
		report.append("%s %s %d/%d%s" % [cls.id, Run.job.id, Run.deck.cards.size(), tree.size(),
			"" if missing.is_empty() else " missing " + ",".join(missing)])
	check(ok, "\"max\" for every character: its 2nd job, its whole 1st-job tree, three skills slotted (%s)" % "; ".join(report))
	_buffalo_in_chunk_2(Run, "all:3")
	var off: Array = fighter.cards.filter(func(x: CardData) -> bool:
		return Run.deck.card_level(x.id) != mini(3, Run.deck.card_cap(x.id)))
	check(off.is_empty(), "\"all:3\": every Fighter card at Lv 3, or its cap when lower (%s)" % [off])
	_buffalo_in_chunk_2(Run, "draft:4:3")
	var held: Array = Run.deck.cards.keys()
	var offers: Array[CardData] = Run.deck.draft_offers(3)
	check(Run.veteran.draft_left == 4 and Run.veteran.draft_level == 3 and held == [&"shockwave"]
		and offers.size() == 3 and offers.all(func(x: CardData) -> bool: return x in fighter.cards),
		"\"draft:4:3\": four drafts of Fighter cards at Lv 3 wait for the first room (holding %s)" % [held])


func _build_and_arms(Run: Node) -> void:
	Profile.builds["buffalo"] = {"power": 10, "magic": 0, "sense": 0, "charm": 0}
	_buffalo_in_chunk_2(Run, "max")
	check(Run.type_points == {"power": 53, "magic": 0, "sense": 0, "charm": 0},
		"the type points follow the build of the character's last clear (%s)" % Run.type_points)
	var w: GearItem = Run.gear.equipped("weapon")
	var band: int = Run.route.chunk.regions[0].gear_levels.x
	check(w != null and w.data.family == Run.cls.start_weapon.family and w.data.level > band - 25 and w.data.level <= band,
		"a veteran with no loadout weapon carries a %s of item level %d, not the level-1 one" % [w.title(), w.data.level])
	Profile.builds.erase("buffalo")
	# A clear records the build the next chunk starts from.
	Run.type_points = {"power": 20, "magic": 3, "sense": 0, "charm": 30}
	Run.city.finished = false
	Run.city.finish(true)
	check(Profile.builds.get("buffalo", {}) == {"power": 20, "magic": 3, "sense": 0, "charm": 30},
		"a clear records the character's type points for its next veteran start")


## A region's pack scale grows its waves' budget: chunk 2's veterans need bigger packs.
func _packs(Run: Node) -> void:
	Run.new_run(7)
	var region: RegionData = Run.route.region
	var wharf: RegionData = load("res://data/oops_wharf/region.tres")
	var roller: Room = load("res://scripts/room.gd").new()
	var counts: Array[int] = []
	for scale: float in [1.0, 2.0]:
		region.pack_scale = scale
		Run.rng.seed = 11
		var n := 0
		for _r in 6:
			for w: Array in roller._make_waves(4, false):
				n += w.size()
		counts.append(n)
	region.pack_scale = 1.0
	roller.free()
	check(wharf.pack_scale == 2.0 and counts[1] >= counts[0] * 1.6,
		"Oops Wharf packs twice the budget of chunk 1's rooms: %d monsters against %d" % [counts[1], counts[0]])


## The draft is a pick before the first room, made with the number keys like any other.
func _draft_by_keys(Run: Node) -> void:
	_buffalo_in_chunk_2(Run, "draft:2:3")
	# One game at a time: the runner's would answer the same Events.
	get_tree().paused = false
	if is_instance_valid(runner.game):
		runner.game.free()
	runner.game = null
	var g: Game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(g)
	var titles: PackedStringArray = []
	for i in 2:
		for _w in 80:
			await wait(0.1)
			if g.hud.pick_panel.visible:
				break
		titles.append(g.hud.get_node("%PickTitle").text)
		var key := InputEventKey.new()
		key.keycode = KEY_1
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().process_frame
		key.pressed = false
		Input.parse_input_event(key)
		await get_tree().process_frame
		if g._pick_kind == "replace":
			g.hud._on_pick(0)
	for _w in 60:
		await wait(0.1)
		if g.phase == g.Phase.FIGHT:
			break
	var drafted: Array = Run.deck.cards.keys().filter(func(id: StringName) -> bool: return id != &"shockwave")
	check(titles.size() == 2 and titles[0].begins_with("Veteran draft") and drafted.size() == 2
		and drafted.all(func(id: StringName) -> bool: return Run.deck.card_level(id) == 3) and g.phase == g.Phase.FIGHT,
		"two draft picks by key, each card at Lv 3, then the first room's fight (%s; %s)" % [titles, drafted])
	get_tree().paused = false
	g.queue_free()
	await get_tree().process_frame


## The gate asks where a character with chunk 2 open logs in; Esc stays in the city.
func _gate(Run: Node) -> void:
	_buffalo_in_chunk_2(Run, "max")
	Profile.chunk_choice["buffalo"] = 1
	var runs := int(Profile.stats.runs)
	Profile.stats.runs = maxi(runs, 1)  # not a first visit: no welcome conversation
	var hub: Hub = load("res://scenes/hub.tscn").instantiate()
	get_tree().root.add_child(hub)
	await wait(1.0)
	var titles: Array = hub.gate_menu.chunk_options().map(func(o: Dictionary) -> String: return "%s [%s]%s" % [o.title, o.tag,
		" (off)" if o.disabled else ""])
	Profile.chunks.erase("buffalo")
	var closed: Array = hub.gate_menu.chunk_options().filter(func(o: Dictionary) -> bool: return o.disabled)
	Profile.chunks["buffalo"] = 1
	hub.gate_menu.depart_to_chunk()
	for _w in 20:
		await wait(0.05)
		if hub.dialogue.visible:
			break
	var shown: bool = hub.dialogue.visible and hub.talker.talking
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	esc.pressed = false
	Input.parse_input_event(esc)
	await wait(0.2)
	check(titles.size() == 2 and String(titles[1]).contains("Lv 54 Knight") and closed.size() == 1 and shown
		and not hub.leaving and not hub.talker.talking and int(Profile.chunk_choice.buffalo) == 1,
		"the gate asks a Buffalo with chunk 2 open where to log in (%s); a closed chunk is shown locked; Esc stays" % [titles])
	hub.queue_free()
	Profile.stats.runs = runs
	await get_tree().process_frame


## A chunk-2 clear opens one 3rd-job branch, picked by key; the last one left opens by itself, and
## a chunk-1 clear's single next job (the Knight) without a pick.
func _branches(Run: Node) -> void:
	var opened: Dictionary = Profile.jobs_open.duplicate()
	Profile.jobs_open.erase("buffalo")
	_buffalo_in_chunk_2(Run, "max")
	var offered: Array = Run.veteran.branch_offers().map(func(j: JobData) -> StringName: return j.id)
	var g: Game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(g)
	await wait(2.6)
	g._choose_branch()
	await get_tree().process_frame
	var title: String = g.hud.get_node("%PickTitle").text
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await wait(1.0)  # the results fade in over 0.6 s
	var after: Array = Profile.jobs_open.get("buffalo", []).duplicate()
	check(offered == [&"gladiator", &"mercenary"] and title.contains("next job") and after == ["mercenary"]
		and g.hud.results_panel.visible, "a Knight's chunk 2 clear offers %s; key 2 opens the Mercenary, then the results (%s; %s; results %s)" % [offered,
		after, title, g.hud.results_panel.visible])
	g._choose_branch()  # a second clear: one branch left, opened without a pick
	await get_tree().process_frame
	check(Profile.jobs_open.buffalo == ["mercenary", "gladiator"] and Run.veteran.branch_offers().is_empty(),
		"a second clear opens the Gladiator, the branch left (%s)" % [Profile.jobs_open.buffalo])
	var three: ChunkData = Run.route.chunk_numbered(2).duplicate()
	three.job_tier = 3
	var path: Array = Run.veteran.job_path(three).map(func(j: JobData) -> StringName: return j.id)
	check(path == [&"fighter", &"knight", &"mercenary"], "a 3rd-tier chunk sets out in the first branch opened (%s)" % [path])
	get_tree().paused = false
	g.queue_free()
	await get_tree().process_frame
	Profile.jobs_open.erase("buffalo")
	Profile.class_id = "buffalo"
	Profile.chunk_choice.erase("buffalo")
	Run.new_run(7)
	var fighter: Array = Run.veteran.branch_offers().map(func(j: JobData) -> StringName: return j.id)
	check(fighter == [&"knight"], "a Fighter's clear has the Knight to open, its only next job (%s)" % [fighter])
	Profile.jobs_open = opened


## Every chunk's built regions are exported: each room's map, each monster's original row and sprite.
func _exports(Run: Node) -> void:
	var names: PackedStringArray = []
	var gaps: PackedStringArray = []
	for c: ChunkData in Run.route.chunks:
		for r in c.regions:
			names.append("%d: %s" % [c.number, r.display_name])
			for room: RoomData in r.rooms + [r.boss_room]:
				if not FileAccess.file_exists(Assets.map_dir(room.map) + "map.json"):
					gaps.append("%s's map %s" % [room.id, room.map])
			for e: EnemyData in r.enemies:
				if not Run.monster_data.has(e.monster_id):
					gaps.append("%s's stats (row %s)" % [e.id, e.monster_id])
				elif not FileAccess.file_exists(Assets.actor_json(String(e.id))):
					gaps.append("%s's sprite" % e.id)
	check(gaps.is_empty() and "2: Oops Wharf" in names, "every built region of every chunk is exported (%s)%s" % [
		", ".join(names), "" if gaps.is_empty() else ": " + ", ".join(gaps)])
