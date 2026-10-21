class_name RunPurse
extends RefCounted
## What the run carries (Run.purse): Galder, ore, TM, shards and monster materials. A
## rollback banks what carries over (Profile.bank_leftovers).

## The refining ore's name (the original's Bronze Fragment).
const ORE_NAME := "Bronze Fragment"

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


func add_material(mat: MaterialData, count: int) -> void:
	if count <= 0:
		return
	material_info[mat.id] = mat
	materials[mat.id] = materials.get(mat.id, 0) + count


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
	for r in Run.route.regions:
		for e in r.enemies:
			if e.material and e.material.id == id:
				return e.material
	return null
