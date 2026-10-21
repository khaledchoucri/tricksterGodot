extends SmokeSection
## Code rules the smoke test enforces (CLAUDE.md, sections 2 and 5).

## Card id literals allowed in shared code (scripts/ outside skills/ and tools/): CLAUDE.md,
## section 2. Lower it as hooks move into card data; it may never rise.
const CARD_ID_LITERALS_MAX := 0
## The most lines a script may have (CLAUDE.md asks for about 600), and the files allowed past it
## while their split is in CLAUDE.md's debt list.
const MAX_LINES := 700
const LONG_ALLOWED: Array[String] = ["game.gd"]


## Stats, types and traits, jobs and prerequisites, gear, weight and refining.
## Code rules the smoke test enforces (CLAUDE.md, sections 2 and 5).
func run() -> void:
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
	# No script grows past about 600 lines (CLAUDE.md, section 4): the lint allows 700, and game.gd
	# only while its split is in the debt list.
	var long_files: PackedStringArray = []
	for path in all_scripts:
		var n := FileAccess.get_file_as_string(path).count("\n")
		if n > MAX_LINES and not path.get_file() in LONG_ALLOWED:
			long_files.append("%s %d" % [path.get_file(), n])
	check(long_files.is_empty(), "no script is over %d lines%s" % [MAX_LINES, "" if long_files.is_empty() else ": " + ", ".join(long_files)])
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
