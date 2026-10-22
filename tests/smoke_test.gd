class_name SmokeTest
extends Node
## The smoke test: builds one game and runs its sections (tests/smoke/*.gd, a SmokeSection each)
## in a fixed order, so a seed gives the same results. Run everything: godot --headless --path . res://tests/smoke_test.tscn
## Run some sections: add `-- only=charm,ui` (sections by name) or `-- class=cat,lion`
## (the sections that test those characters); tests/run_smoke.sh wraps both. `-- seed=N`
## picks the seed every run and placement starts from (default 1, so results repeat).
## Each section sets up what it needs, so any subset passes on its own. Changes to
## shared code still run the full suite (CLAUDE.md, section 5).

## The sections, in the order they run.
const SECTIONS: Array[String] = ["core", "power", "magic", "sense", "elements", "charm", "talents", "balance", "ui", "rest", "art", "boss",
	"systems", "lint"]
## The section that tests each character.
const CLASS_SECTION: Dictionary[String, String] = {"buffalo": "power", "bunny": "power", "sheep": "magic",
	"dragon": "magic", "fox": "sense", "lion": "sense", "cat": "charm", "raccoon": "charm"}


## The sections' scripts (tests/smoke/).
const CORE := preload("res://tests/smoke/core.gd")
const POWER := preload("res://tests/smoke/power.gd")
const MAGIC := preload("res://tests/smoke/magic.gd")
const SENSE := preload("res://tests/smoke/sense.gd")
const ELEMENTS := preload("res://tests/smoke/elements.gd")
const CHARM := preload("res://tests/smoke/charm.gd")
const TALENTS := preload("res://tests/smoke/talents.gd")
const BALANCE := preload("res://tests/smoke/balance.gd")
const UI := preload("res://tests/smoke/ui.gd")
const BOSS := preload("res://tests/smoke/boss.gd")
## Boss timer checks run before the map-dependent game starts.
const BOSS_PAUSE := preload("res://tests/smoke/boss_pause.gd")
const SYSTEMS := preload("res://tests/smoke/systems.gd")
const REST := preload("res://tests/smoke/rest.gd")
const ART := preload("res://tests/smoke/art.gd")
const LINT := preload("res://tests/smoke/lint.gd")

## The sections picked on the command line; empty runs them all.
var only: Array[String] = []
## The seed for the run's RNG and the test's own placement (seed=N).
var test_seed := 1
## Failed checks so far.
var failures := 0
## The game scene every section plays in.
var game: Game


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


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
	if _on("boss"):
		await _section(BOSS_PAUSE).run()
	Run.next_seed = test_seed
	_run.call_deferred()


## Whether a section runs: every one, or those picked on the command line.
func _on(section: String) -> bool:
	return only.is_empty() or section in only


func _run() -> void:
	Profile.use_path("user://smoke_test_profile.json", true)  # never touch the real save
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().create_timer(2.6).timeout
	if _on("core"):
		await _section(CORE).first_room()
	if _on("power"):
		await _section(POWER).attacks()
	if _on("core"):
		await _section(CORE).rewards()
	if _on("power"):
		# Job changes, upgrade skills and the Power-line talents.
		await _section(POWER).rules()
	if _on("magic"):
		# The Magic line: Sheep and Dragon, casting, Seals and Pacts, every spell.
		await _section(MAGIC).run()
	if _on("sense"):
		# The Sense line: Fox and Lion, the gun's cycle, every Sense skill.
		await _section(SENSE).run()
	if _on("elements"):
		# Elemental attack compounds and their hit effects; shields and guns.
		await _section(ELEMENTS).run()
	if _on("charm"):
		# The Charm line: Cat and Raccoon, the beast forms, every Charm skill.
		await _section(CHARM).run()
	if _on("talents"):
		await _section(TALENTS).run()
	if _on("balance"):
		_section(BALANCE).run()
	if _on("ui"):
		await _section(UI).run()
	if _on("rest"):
		# Before the bosses, which end in Megalopolis. Rest stops between regions: the heal, Julio and the warehouse swap.
		await _section(REST).run()
	if _on("art"):
		# Before the bosses too: its monster checks play in a room.
		await _section(ART).run()
	if _on("boss"):
		await _section(BOSS).run()
	if _on("systems"):
		_section(SYSTEMS).run(get_node("/root/Run"))
	if _on("lint"):
		_section(LINT).run()

	print("\n%s: %d failure(s)%s" % ["OK" if failures == 0 else "FAILED", failures,
		"" if only.is_empty() else " in " + ", ".join(only)])
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures else 0)


var _sections: Dictionary = {}  # script -> its SmokeSection, made on first use


## The section for `script`, made and added to the tree the first time it's asked for.
func _section(script: GDScript) -> SmokeSection:
	if not _sections.has(script):
		var s: SmokeSection = script.new()
		s.runner = self
		add_child(s)
		_sections[script] = s
	return _sections[script]
