class_name RunPurse
extends RefCounted
## What the run carries (Run.purse): Galder, ore, TM, shards and monster materials. A
## rollback banks what carries over (Profile.bank_leftovers).

## The refining ore's name (the original's Bronze Fragment).
const ORE_NAME := "Bronze Fragment"
## A Bronze Fragment's weight (ItemParam 11254, Weight 2).
const ORE_WEIGHT := 2
## Galder: spent on skills that cost it, the shop and the city's smiths.
var galder := 0
## Refining ore (Bronze Fragments).
var ore := 0
## TM earned this run, banked on a rollback.
var tm := 0
## Shards earned this run.
var shards := 0
## Monster materials carried: MaterialData id -> count, and the data by id.
var materials: Dictionary = {}
var material_info: Dictionary = {}


## Galder skills spend the run's Galder (Galder Thrower's 100 is 20 here: a
## fifth of the original's prices). False, and nothing spent, when short.
func spend_galder(amount: int) -> bool:
	if galder < amount:
		return false
	galder -= amount
	return true


## What the materials and ore you carry weigh (their original Weight).
func carried_weight() -> int:
	var total := ore * ORE_WEIGHT
	for id: StringName in materials:
		var m: MaterialData = material_info.get(id, material_by_id(id))
		total += int(materials[id]) * (m.weight if m else 1)
	return total


## How much you can carry: WT, the original's MaxWT. Decided with the user (2026-10-21): this is
## WT's job, since worn gear counts against no load.
func carry_limit() -> int:
	return Run.stat("WT")


## How many of something weighing `each` still fit.
func _fits(count: int, each: int) -> int:
	return clampi((carry_limit() - carried_weight()) / maxi(1, each), 0, count)


## Picks up `count` of a material, as many as fit; the rest is left behind (Events.too_heavy).
## Returns how many were taken.
func add_material(mat: MaterialData, count: int) -> int:
	if count <= 0:
		return 0
	material_info[mat.id] = mat
	var n := _fits(count, mat.weight)
	materials[mat.id] = materials.get(mat.id, 0) + n
	if n < count:
		Events.too_heavy.emit(mat.display_name, count - n)
	return n


## Picks up `count` Bronze Fragments, as many as fit. Returns how many were taken.
func add_ore(count: int) -> int:
	if count <= 0:
		return 0
	var n := _fits(count, ORE_WEIGHT)
	ore += n
	if n < count:
		Events.too_heavy.emit(ORE_NAME, count - n)
	return n


func material_count(mat: MaterialData) -> int:
	return materials.get(mat.id, 0)


## Materials carried with enough for one compound.
func compoundable_materials() -> Array[MaterialData]:
	var out: Array[MaterialData] = []
	for id: StringName in materials:
		var m: MaterialData = material_info[id]
		if materials[id] >= m.need:
			out.append(m)
	return out


## Every material the run can drop, by id (for city crafting).
func material_by_id(id: StringName) -> MaterialData:
	for r in Run.route.all_regions():
		for e in r.enemies:
			if e.material and e.material.id == id:
				return e.material
	return null


## Whether an Echo joins this elite room (after the first clear).
func echo_here() -> EnemyData:
	if not Run.route.current_room().elite or int(Profile.stats.get("clears", 0)) < 1 or Run.rng.randf() > 0.45:
		return null
	return Run.echoes[Run.rng.randi() % Run.echoes.size()]


## Monster card drop for a kill (rare; elites and bosses more often).
func roll_card(enemy_id: StringName, elite: bool, boss: bool) -> bool:
	if not Run.city.system_on(&"cards"):
		return false
	var chance := 0.5 if boss else (0.15 if elite else 0.02 + Run.stat("DA") / 1000.0)
	return Run.rng.randf() < chance


## The drill carried (the first one once the Drill Shop is restored).
func drill() -> DrillData:
	if Run.hub == null or Run.hub.drills.is_empty() or not Run.city.system_on(&"drilling"):
		return null
	for d in Run.hub.drills:
		if String(d.id) == Profile.drill and String(d.id) in Profile.drills:
			return d
	return Run.hub.drills[0]


## What a dig to `depth` brings up: ore, then the region's materials, then
## gear, then a Harkon Shard.
func dig_rewards(depth_reached: int) -> Dictionary:
	var out := {"ore": 0, "material": null, "count": 0, "gear": null, "shard": 0}
	if depth_reached >= 5:
		out.ore = 1 + depth_reached / 10
	if depth_reached >= 15:
		var mats: Array[MaterialData] = []
		for e in Run.route.region.enemies:
			if e.material and not e.is_boss:
				mats.append(e.material)
		if not mats.is_empty():
			out.material = mats[Run.rng.randi() % mats.size()]
			out.count = 2 + depth_reached / 20
	if depth_reached >= 40:
		var offers := Run.gear.gear_offers(1)
		if not offers.is_empty():
			out.gear = offers[0]
	if depth_reached >= 70:
		out.shard = 1
	return out


## Rewards for a kill. Returns what dropped: {"ore": n, "material":
## MaterialData or null, "count": n}.
func add_kill(exp_amount: int, tm_amount: int, galder_amount: int, elite := false, boss := false,
		mat: MaterialData = null, mat_chance := 0.0) -> Dictionary:
	Run.kills += 1
	tm += tm_amount
	galder += int(galder_amount * (1.0 + Run.stat("LK") / 100.0) * Run.mod_factor("galder%"))
	var found := 0
	if boss:
		found = 3
	elif elite or Run.rng.randf() < (0.12 + Run.stat("DA") / 400.0) * ServerSettings.drop_mult():
		found = 1
	add_ore(found)
	var count := 0
	if mat and Run.city.system_on(&"compounding"):
		if boss:
			count = 3
		elif elite:
			count = 2
		elif Run.rng.randf() < (mat_chance + Run.stat("DA") / 200.0 + Run.mod("material_drop")) * ServerSettings.drop_mult():
			count = 1
		add_material(mat, count)
	if Run.mod("kill_mp") > 0.0:
		Run.gain_mp(int(Run.mod("kill_mp")))
	Run.gain_exp(exp_amount)
	return {"ore": found, "material": mat if count > 0 else null, "count": count}
