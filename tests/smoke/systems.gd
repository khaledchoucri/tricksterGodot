extends SmokeSection
## The run's systems: regions, seeds, mods, stats and types, jobs, gear, compounding, the warehouse,
## cards and the wardrobe, Echoes, drilling, the Trickster, mastery and Heat.


func run(Run: Node) -> void:
	_restore_all(Run)
	# The run crosses three regions; every room's map is exported and every monster has its
	# original stats.
	var names: PackedStringArray = []
	var gaps: PackedStringArray = []
	for r: RegionData in Run.route.regions:
		names.append(r.display_name)
		for room: RoomData in r.rooms + [r.boss_room]:
			if not FileAccess.file_exists(Assets.map_dir(room.map) + "map.json"):
				gaps.append("%s's map %s" % [room.id, room.map])
		for e: EnemyData in r.enemies:
			if not Run.monster_data.has(e.monster_id):
				gaps.append("%s's stats (row %s)" % [e.id, e.monster_id])
	check(names == PackedStringArray(["Coral Beach", "Desert Beach", "Caballa Relics"]) and gaps.is_empty(),
		"a run crosses %s, every room and monster exported%s" % [" > ".join(names), "" if gaps.is_empty() else ": " + ", ".join(gaps)])
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
	# Each region offers its own gear levels, first room to boss, however long the run is.
	var ranges: Array[String] = []
	for d: int in Run.route.plan.size():
		var p: RoomPlan = Run.route.plan[d]
		Run.route.depth = d
		if p.local_depth == 0 or p.boss:
			ranges.append(str(Run.gear.gear_level()))
	var want: Array[String] = []
	for r: RegionData in Run.route.regions:
		want.append_array([str(r.gear_levels.x), str(r.gear_levels.y)])
	check(ranges == want, "every region's rooms offer its own gear levels (%s)" % " ".join(ranges))
	# The Caballa Relics offer their own tier: the level-50 and level-65 lines, every slot.
	Run.route.depth = Run.route.plan.size() - 2
	var relics_gear: Array = Run.gear.gear_offers(60)
	var tier := relics_gear.filter(func(g: GearItem) -> bool: return g.data.level >= 50)
	var slots := {}
	for g: GearItem in tier:
		slots[g.data.slot] = true
	check(slots.size() >= 4 and tier.any(func(g: GearItem) -> bool: return g.data.level >= 65),
		"the Relics offer level 50-65 gear (%d of %d offers, %d slots)" % [tier.size(), relics_gear.size(), slots.size()])
	Run.route.depth = 5
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

	# Master Louis: a mastered skill starts the run, at its mastery level; caps stay at 5.
	var start: CardData = null
	for card: CardData in Run.deck.all_cards():
		if Run.deck.can_start_with(card):
			start = card
			break
	var startable: Array = Run.deck.all_cards().filter(func(card: CardData) -> bool: return Run.deck.can_start_with(card))
	var own: Array[CardData] = Run.deck.card_pool()
	check(start != null and startable.all(func(card: CardData) -> bool: return card in own)
		and not Run.deck.can_start_with(Run.deck.card(&"shockwave")) and Run.deck.card_cap(&"shockwave") == 5,
		"Buffalo's starting skills are cards of its own trees (%s), not Shockwave, which it has anyway"
		% ", ".join(startable.map(func(card: CardData) -> String: return card.display_name)))
	if start:
		Profile.restorations["skill_shrine"] = 1
		Profile.materials[String(start.master_material.id)] = 18
		Profile.galder = 1500
		Run.deck.master_card(start)
		Run.deck.master_card(start)
		Profile.start_skills[String(Run.cls.id)] = String(start.id)
		Run.new_run()
		check(Run.deck.card_level(start.id) == 2 and Run.deck.card_cap(start.id) == 5,
			"a skill mastered twice starts the run at Lv 2 (%s Lv %d)" % [start.display_name, Run.deck.card_level(start.id)])
		Profile.restorations.erase("skill_shrine")
	Profile.mastery = {}
	Profile.start_skills = {}
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
