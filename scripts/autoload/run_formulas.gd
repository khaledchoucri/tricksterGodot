class_name RunFormulas
extends RefCounted
## The run's numbers (Run.formulas): your damage, defence, speed, guns and crits against the
## starting character's, and the monster curve, each with its source.

## Offsets that soften stat ratios (a stat twice the starting value is not
## twice the effect).
const AP_SOFT := 40.0
const MA_SOFT := 50.0
const DX_SOFT := 60.0
const DEF_SOFT := 100.0
## A normal monster at the median of its region, in room 1: effective HP
## (what it takes to kill through its DP) and damage per hit. The sword's
## first three hits (130 at x1.0) kill it; it lands 6% of a starting HP bar.
const MOB_EHP := 128.0
const MOB_HIT := 12.5
## Per room of depth: effective HP and damage growth. A par build's damage
## grows faster than this (about x4 by room 16 against x2.8), so gear and
## builds shorten fights instead of only keeping pace.
const DEPTH_EHP := 0.12
const DEPTH_HIT := 0.07
## How much of a monster's original toughness and hit strength (relative to
## its region's median) survives: 1 keeps the spread, 0 flattens it.
const SPREAD_EHP := 0.7
const SPREAD_HIT := 0.6
const MAX_HIT_SPREAD := 2.5
var _norms := {}


## The median effective HP and hit of a region's regular monsters.
func region_norm(r: RegionData) -> Dictionary:
	if _norms.has(r):
		return _norms[r]
	var ehp: Array[float] = []
	var hit: Array[float] = []
	var dp: Array[float] = []
	var md: Array[float] = []
	for e in r.enemies:
		if e.is_boss or e.echo or e.min_depth >= 99:
			continue
		var s := Stats.from_monster(monster_stats(e).get("stats", {}))
		ehp.append(Run.raw_ehp(s))
		hit.append(Run.raw_hit(s))
		dp.append(float(s.get("DP", 0)))
		md.append(float(s.get("MD", 0)))
	for a: Array[float] in [ehp, hit, dp, md]:
		a.sort()
	_norms[r] = {"ehp": ehp[ehp.size() / 2] if ehp.size() else 250.0, "hit": hit[hit.size() / 2] if hit.size() else 11.0,
		"DP": dp[dp.size() / 2] if dp.size() else 0.0, "MD": md[md.size() / 2] if md.size() else 0.0}
	return _norms[r]


## Effective HP of a monster with original stats `s` in region `r` at `depth`
## under the old depth curve (kept for Echoes and balance probes).
func mob_ehp(s: Dictionary, r: RegionData, at_depth: int) -> float:
	var rel := Run.raw_ehp(s) / float(region_norm(r).ehp)
	return MOB_EHP * r.hp_scale * pow(rel, SPREAD_EHP) * (1.0 + DEPTH_EHP * at_depth)


## Original HP times this is a monster's HP here. Monsters are as tough as
## their original level makes them, not as deep as the room is: deeper rooms
## bring the region's higher-level monsters (as the original maps do), and a
## growing character outgrows them.
const MOB_HP_SCALE := 0.55


## HP of a monster with original stats `s` in region `r`.
func mob_hp(s: Dictionary, r: RegionData) -> float:
	return float(s.get("HP", 100)) * MOB_HP_SCALE * r.hp_scale


## A monster's hit, from its original AP (raw_hit) like its HP: the same in
## every room, so HP and DP gained along the way are felt. Bosses' original
## AP is far above their region's, so a hit is capped at MAX_HIT_SPREAD
## times the region's median.
const MOB_HIT_SCALE := 1.15


func mob_hit(s: Dictionary, r: RegionData) -> int:
	var raw := minf(Run.raw_hit(s), float(region_norm(r).hit) * MAX_HIT_SPREAD)
	return maxi(1, roundi(MOB_HIT_SCALE * r.damage_scale * raw))


func monster_name(enemy: EnemyData) -> String:
	if enemy == null:
		return ""
	if enemy.display_name != "":
		return enemy.display_name
	return monster_stats(enemy).get("name", String(enemy.id).capitalize())


func monster_stats(enemy: EnemyData) -> Dictionary:
	if enemy == null:
		return {}
	if not enemy.stats_override.is_empty():
		return enemy.stats_override
	return Run.monster_data.get(enemy.monster_id, {})


## Berserker's rage, and Desperate Rally below its HP line (stronger the
## lower HP gets, up to double at 0).
func _berserk_mult() -> float:
	var m := 1.0 + Run.mod("damage%") / 100.0
	for t in Run.deck.talents():
		m = t.adjust(&"damage", m)
	return m


func _ratio(key: String, soft: float) -> float:
	return (Run.stat(key) + soft) / (float(Run.ref_stats.get(key, 0)) + soft)


## Damage scales with its stat as in Trickster (damage = stat x skill %):
## the stat against the starting character's, so twice the MA is twice the
## damage and one early point is worth several percent.
func _linear(key: String) -> float:
	return Run.stat(key) / maxf(float(Run.ref_stats.get(key, 0)), 1.0)


## Damage multiplier for the basic combo.
func attack_mult() -> float:
	var m := _linear("AP") * _berserk_mult()
	if Run.has_passive(&"sword_mastery") and Run.gear.weapon_family() == "sword" and Run.cls.armed:
		m *= 1.15
	if Run.has_passive(&"boxers_footwork") and not Run.cls.armed:
		m *= 1.15
	return m


## Damage multiplier for a skill, from the stat it scales with.
func skill_mult(c: CardData = null) -> float:
	var scaling := c.scaling if c else "AP"
	# AP, MA and DA work as in Trickster (linear). A GUN skill's value is a %
	# of a gun shot (its table Ratio). The runes' DP skills keep a damped curve.
	var m := 1.0
	if scaling == "GUN":
		return gun_shot_mult() * GUN_SHOT / 100.0
	elif scaling in ["AP", "MA", "DA", "HV"]:
		m = _linear(scaling)
	elif _is_expression(scaling):
		m = attack_power(scaling) / maxf(attack_power(scaling, true), 1.0)
	else:
		m = _ratio(scaling, {"DP": 60.0}.get(scaling, AP_SOFT))
	if c and c.has_tag(&"thrown"):
		m *= 1.0 + Run.mod("thrown_damage%") / 100.0
	m = Run.mod_factor("skill_damage%", false, m)
	return m * _berserk_mult()


## A skill's attack as the server computes it (tools/re/README.md): a sum
## of weighted stats such as "AP+16HV" (Volley Kick), "0.1HPNOW+0.5DP"
## (Siren Song) or "AP+0.1LOST" (Final Blow). HPNOW is your current HP,
## LOST the HP you're missing. `ref`: the same for the level-1 character
## at full health, that a card's numbers are tuned against.
func attack_power(expr: String, ref := false) -> float:
	var total := 0.0
	for term in expr.split("+"):
		var i := 0
		while i < term.length() and (term[i] == "." or term[i].is_valid_int()):
			i += 1
		var w := float(term.substr(0, i)) if i > 0 else 1.0
		total += w * _attack_stat(term.substr(i), ref)
	return total


func _is_expression(scaling: String) -> bool:
	return scaling.contains("+") or scaling.contains("HPNOW") or scaling.contains("LOST") or \
		(scaling.length() > 0 and (scaling[0] == "." or scaling[0].is_valid_int()))


func _attack_stat(key: String, ref: bool) -> float:
	match key:
		"HPNOW":
			return float(Run.ref_stats.get("HP", 0)) if ref else float(Run.hp)
		"LOST":
			return 0.0 if ref else float(maxi(Run.max_hp - Run.hp, 0))
	return float(Run.ref_stats.get(key, 0)) if ref else float(Run.stat(key))


## AP + DA against the starting character's: a gun hits harder with a better
## gun (its AP) and with Sense points (DA).
## The server's gun damage (GameServer.exe 0x59d440, GunAttackStrategy):
## 20 x (AC - 49) + Gun AP + 20 - 30 x the target's HV. AC is the gun's
## stat, worth 20 Gun AP a point; translated linearly against level 1 as the
## other lines are, with the target's HV as its defence (Enemy.gun_defense_mult).
const GUN_AP_PER_AC := 20.0
## A gun shot's base damage (gun_shot.tres), which the gun skills' % refer to.
const GUN_SHOT := 87.0


## Gun Overdrive (CustomizingGun) multiplies the gun's Gun AP by its Ratio;
## Gun Booster (PriMarksmanship) adds its AP to the shot's.
func gun_attack() -> float:
	var ap := gun_ap() * (1.0 + Run.mod("gun_AP%") / 100.0) + Run.mod("gun_AP")
	return Run.stat("AC") + ap / GUN_AP_PER_AC


## The equipped gun's Gun AP (its table AP, raised by refining).
func gun_ap() -> float:
	var w := Run.gear.equipped("weapon")
	return float(w.stats().get("AP", 0)) if w and w.data.family == "gun" else 0.0


func gun_stat_mult() -> float:
	return gun_attack() / maxf(float(Run.ref_stats.get("AC", 0)), 1.0)


## Damage multiplier for a gun shot. The gun skills are multiples of it, so
## they always outhit the basic shot (Gun Booster and Gun Overdrive included,
## though the original keeps Overdrive to the basic shot).
func gun_shot_mult() -> float:
	return gun_stat_mult() * _berserk_mult()


## Extra power-shot damage, %: Keen Sense's mod, or what Sharp Sense makes of it.
func power_shot_bonus() -> float:
	var b := Run.mod("power_shot%")
	for t in Run.deck.talents():
		b = t.adjust(&"power_shot%", b)
	return b


## A reload's time against the gun's own. Speedloader sets the client's fill
## rate to 2 - Ratio/100 (Trickster.bin 0x4c04e0), its value being 100 - Ratio.
func reload_mult() -> float:
	return 1.0 / (1.0 + Run.mod("reload_speed%") / 100.0)


## Cooldowns are the original's; only Refreshing Dew shortens them.
func skill_cooldown_mult() -> float:
	return 1.0 - Run.mod("cooldown_cut%") / 100.0


## Your resistance to an element, in %.
func resist(element: String) -> float:
	# The elemental Shields, the Blessings that keep their Shield's resistance, Lightning Rod...
	var r := Run.mod("resist:" + element) if element in Mod.ELEMENTS else 0.0
	return minf(r, 80.0)


## Extra damage % for spells of an element (Elemental Boost, Dark Assimilation).
func element_boost(element: String) -> float:
	return Run.mod("boost:%s%%" % element) if element in Mod.ELEMENTS else 0.0


func attack_speed_mult() -> float:
	return _ratio("DX", DX_SOFT) * (1.0 + Run.mod("attack_speed%") / 100.0) * Run.form_speed_mult()


func speed_mult() -> float:
	return Run.mod_factor("move%", false, 0.85 if Run.gear.overweight() else 1.0)


func dash_cooldown_mult() -> float:
	var m := Run.mod_factor("dash_cooldown_cut%", true, 1.3 if Run.gear.overweight() else 1.0)
	return m * (0.8 if not Run.cls.armed else 1.0)  # fighting bare-handed keeps you light on your feet


## Debuffs your hits carry from the talents that inflict one ({key: [value, seconds]},
## see Enemy.debuffs): the breakers' value for their Seconds, Suffocate's pin and
## Entrancing Wink's silence (no magic) for their value in seconds.
func hit_debuffs() -> Dictionary:
	var out := {}
	for c in Run.deck.held_cards():
		if c.inflicts == "":
			continue
		var lvl := Run.deck.card_level(c.id)
		out[c.inflicts] = [c.value_at(lvl), c.param("seconds", lvl)] if c.table.has("seconds") else [1.0, c.value_at(lvl)]
	return out


## Critical chance, against `e` when given (Luck Breaker makes cursed
## monsters easier to crit).
func crit_chance(e: Enemy = null) -> float:
	var c := 0.03 + Run.stat("LK") / 250.0
	return c * (1.0 + e.debuff("luck") / 100.0) if e else c


## Damage taken: DP against physical hits, MD against magic.
## `element`: the attacker's (an elemental Shield resists it).
func damage_taken_mult(magic := false, element := "") -> float:
	var key := "MD" if magic else "DP"
	var m := (float(Run.ref_stats.get(key, 0)) + DEF_SOFT) / (Run.stat(key) + DEF_SOFT)
	m = Run.mod_factor("damage_cut%", true, m)
	if magic:
		m = Run.mod_factor("magic_damage_cut%", true, m)  # Mana Reflector turns its part back
	if element != "":
		m *= 1.0 - resist(element) / 100.0
	return m


## Chance to evade an attack from a monster with accuracy `ac`.
func evade_chance(ac: int) -> float:
	var hv := Run.stat("HV")
	var c := hv / float(hv + ac + 150)
	c += Run.mod("evade")
	return minf(c, 0.6)


func mp_per_hit() -> int:
	return 5 + int(Run.mod("hit_mp"))
