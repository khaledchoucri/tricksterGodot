extends SmokeSection
## Progression guards: damage grows with its stat as in Trickster, and monsters are as tough as
## their original level.


## Progression guards: damage grows with its stat as in Trickster, and monsters are as tough as their original level.
func run() -> void:
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
	Run.level = Run.deck.unlock_level(Run.deck.card(&"arrow_rush"))  # Arrow Rush is TM 50
	for i in 20:
		always = always and Run.deck.card(&"arrow_rush") in Run.deck.card_offers(3, false)
	for i in 20:
		always = always and Run.deck.card(&"arrow_rush") in Run.deck.card_offers(3, true)
	Run.level = 1
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
