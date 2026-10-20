extends Node
## Hits to kill each region's monsters, room by room, for a pure build
## using the game's own formulas: progression must show as falling numbers.
##   godot --headless res://tests/progression_probe.tscn
func _ready() -> void:
	for cls in ["dragon", "sheep", "buffalo", "fox", "lion"]:
		Profile.class_id = cls
		Run.new_run()
		var basic: StringName = Run.cls.basic_skill.id if Run.cls.basic_skill else &"shockwave"
		var sense: bool = cls in ["fox", "lion"]
		var stat := "AC" if cls == "lion" else "DA" if sense else "MA" if Run.cls.basic_skill else "AP"
		var main := "power" if cls == "lion" else "sense" if sense else "magic" if Run.cls.basic_skill else "power"
		var c: CardData = Run.cls.basic_skill if Run.cls.basic_skill else Run.card(basic)
		print("== %s (%s, %s)" % [cls, basic, stat])
		for room in [0, 2, 4, 6, 7, 8, 10, 12, 15]:
			var lv := 1 + int(room * 1.5)
			while Run.level < lv:
				Run.gain_exp(Run.exp_to_next())
			while Run.pending_levels > 0:
				Run.apply_type(main)
				Run.pending_levels -= 1
			var skill_lv := mini(1 + room / 3, 5)
			Run.cards[basic] = skill_lv
			var r: RegionData = Run.regions[0 if room < 8 else 1]
			var d: int = room if room < 8 else room - 8
			var dmg := c.value_at(skill_lv) * (Run.gun_shot_mult() if basic == &"gun_shot" else Run.skill_mult(c))
			var line := ""
			for e in r.enemies:
				if e.is_boss or e.echo or e.min_depth > d:
					continue
				var s: Dictionary = Stats.from_monster(Run.monster_stats(e).get("stats", {}))
				var def := float(s.get("MD" if stat == "MA" else "HV" if stat == "AC" else "DP", 0)) * (1.5 if stat == "AC" else 1.0)
				var a := Run.gun_attack() if stat == "AC" else float(Run.stat(stat))
				var hp := Run.mob_hp(s, r) * e.hp_mult
				line += " %s %.1f" % [String(e.id).left(6), hp / (dmg * a / (a + def))]
			print("room %2d Lv %2d %s %3d x%.2f sk%d dmg %4d |%s" % [room, lv, stat, Run.stat(stat), Run.skill_mult(c), skill_lv, dmg, line])
	get_tree().quit()
