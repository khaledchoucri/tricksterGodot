extends SmokeSection
## Map-independent persistent warehouse identity and old-save migration checks.

## Synchronous isolation: preserve all profile fields, replaced Run fields and both RNG values.
func run() -> void:
	var saved_profile: Dictionary = {}
	for property: Dictionary in Profile.get_script().get_script_property_list():
		var key: String = property.name
		saved_profile[key] = Profile.get(key)
	var saved_run: Dictionary = {}
	for key: String in ["gear", "route", "_stats"]:
		saved_run[key] = Run.get(key)
	var rng_seed: int = Run.rng.seed
	var rng_state: int = Run.rng.state
	Profile.use_path("user://warehouse_identity_test.json", true)
	Run.gear = RunGear.new()
	Run.gear.items = saved_run.gear.items
	Run.route = RunRoute.new()
	Run.route.regions = saved_run.route.regions
	Run._stats = {"WT": 0}
	_migration()
	_compaction()
	_bag_and_overflow()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	for key: String in saved_profile:
		Profile.set(key, saved_profile[key])
	for key: String in saved_run:
		Run.set(key, saved_run[key])
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state


func _migration() -> void:
	var old_item := GearItem.make(_item("wood_sword")).to_dict()
	old_item.erase("uid")
	var file := FileAccess.open(Profile.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "warehouse": [old_item, old_item, old_item],
		"loadout": {"weapon": 2}, "heirloom": 1, "lost_bag": {"items": [old_item]}}))
	file.close()
	Profile.load_profile()
	check(Profile.warehouse.size() == 3 and Profile.lost_bag.items.size() == 1,
		"legacy migration preserves identical warehouse pieces and lost-bag contents")
	var ids: Dictionary[int, bool] = {}
	for entry: Dictionary in Profile.warehouse + Profile.lost_bag.items:
		ids[int(entry.get("uid", -1))] = true
	check(ids.size() == 4 and not ids.has(-1), "legacy pieces receive distinct persistent identities")
	check(Profile.loadout == {"weapon": 2} and Profile.legacy_heirloom == 1,
		"legacy loadout and heirloom still refer to the original pieces")
	Profile.save()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Profile.path))
	check(data.has("loadout_ids") and int(data.loadout_ids.weapon) == Profile.item_uid(2),
		"saved loadouts refer to identities rather than shelf positions")
	Profile.load_profile()
	check(Profile.loadout == {"weapon": 2}, "identity loadout resolves correctly after JSON reload")


func _compaction() -> void:
	var worn := Run.city.from_shelf(2)
	var uid := worn.stored
	Run.gear.equipment = {"weapon": worn}
	Profile.discard_item(0)
	check(Profile.legacy_heirloom == 0, "legacy heirloom follows compaction before its first run")
	worn.refine = 6
	check(Run.city.worn_from_shelf(1) and not Run.city.worn_from_shelf(0),
		"worn identity follows its item after a lower shelf is discarded")
	Run.city.save_point()
	Profile.load_profile()
	check(int(Profile.warehouse[1].refine) == 6 and int(Profile.warehouse[0].refine) == 0,
		"Port save and reload update the worn piece without overwriting its neighbour")
	check(Profile.item_uid(1) == uid and Profile.loadout == {"weapon": 1},
		"compaction and reload preserve identity and loadout")
	Profile.discard_item(0)
	worn.refine = 7
	check(Run.city.bring_home().is_empty(), "victory accepts stored gear after another compaction")
	Profile.load_profile()
	check(Profile.legacy_heirloom == -1, "discarding a pending heirloom clears its reference")
	check(Profile.warehouse.size() == 1 and int(Profile.warehouse[0].refine) == 7,
		"victory saves progress into the correct remaining item")
	check(Run.city.save_point(worn) and Profile.warehouse.size() == 1,
		"sending an already stored piece home does not duplicate its identity")


func _bag_and_overflow() -> void:
	var worn: GearItem = Run.gear.equipment.weapon
	var uid := worn.stored
	Run.city.drop_bag(Vector2.ZERO)
	check(Profile.warehouse.is_empty() and Profile.item_index(uid) == -1,
		"death removes the bagged identity from its current shelf")
	check(int(Profile.lost_bag.items[0].uid) == uid and int(Profile.lost_bag.items[0].refine) == 7,
		"lost bag preserves the item identity and its improvements")
	Run.gear.equipment = {}
	Run.city.pick_up_bag()
	check(Profile.item_uid(0) == uid and Profile.lost_bag.is_empty(),
		"bag recovery restores the same identity")
	while not Profile.warehouse_full():
		Profile.store_item(GearItem.make(_item("candy_hat")).to_dict())
	var overflow := GearItem.make(_item("steel_helmet"))
	Run.gear.equipment = {"hat": overflow}
	check(Run.city.bring_home() == [overflow] and overflow.stored == -1,
		"overflow retains an unsaved item without claiming another piece's identity")
	Profile.discard_item(0)
	check(Run.city.save_point(overflow) and overflow.stored > uid,
		"making room stores the overflow with a fresh identity, never a reused shelf ID")
	var index := Profile.item_index(overflow.stored)
	Profile.discard_item(index)
	check(not Run.city.bank(overflow), "a stale removed identity cannot bank into a different item")
	check(Run.city.bring_home() == [overflow], "a missing stored identity is returned as unresolved overflow")
	var next_uid: int = Profile.next_item_uid
	Profile.save()
	Profile.load_profile()
	var fresh: int = Profile.store_item(GearItem.make(_item("candy_hat")).to_dict())
	check(Profile.item_uid(fresh) >= next_uid, "reload never reuses a discarded highest identity")
