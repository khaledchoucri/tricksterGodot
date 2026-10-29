class_name RunVeteran
extends RefCounted
## A later chunk's start (Run.veteran): the run begins at the chunk's level, in the job its tier
## reaches, with the type points and the earlier jobs' cards of a career that got that far
## (docs/design/systems-plan.md, "Jobs and chunks"). Chunk 1 (start level 1) has none of it.

## Draft picks still to be offered before the first room ("draft:N:L"), and the level they start at.
var draft_left := 0
var draft_level := 1
## Bots and tests: a ChunkData.veteran_cards spec played instead of the chunk's ("" keeps it).
var cards_override := ""


## Sets up a veteran start for chunk `c`, once the 1st job has begun (Run.new_run()).
func start(c: ChunkData) -> void:
	draft_left = 0
	if c.start_level <= 1:
		return
	var path := job_path(c)
	for i in range(1, path.size()):
		Run.start_job(path[i])
	Run.level = c.start_level
	Run.type_points = carried_points(c.start_level - 1)
	carry_cards(cards_override if cards_override != "" else c.veteran_cards)
	_arm(c)


## The jobs a character (`cls`, else the run's) holds in chunk `c`: its 1st job, then the next one
## at each tier up to the chunk's. Reading: a branch is the first open one (each 1st job has a
## single 2nd job).
func job_path(c: ChunkData, cls: ClassData = null) -> Array[JobData]:
	var out: Array[JobData] = [(cls if cls else Run.cls).start_job]
	while out[-1].tier < c.job_tier:
		var next: JobData = null
		for j in out[-1].next_jobs:
			if j.tier == out[-1].tier + 1 and j.unlocked():
				next = j
				break
		if next == null:
			break
		out.append(next)
	return out


## Type points for a veteran with `n` level-ups behind it: the spread of the character's last
## chunk clear (Profile.builds) scaled to `n`, or its type graph's when it has none (Ours). The
## remainder goes to the largest fractions, in the types' order.
func carried_points(n: int) -> Dictionary:
	var shape: Dictionary = Profile.builds.get(String(Run.cls.id), Run.cls.graph)
	var total := 0.0
	for t: String in Stats.TYPE_ORDER:
		total += maxf(0.0, float(shape.get(t, 0.0)))
	var out := {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	if total <= 0.0:
		return out
	var left := n
	var fractions: Array[Array] = []
	for t: String in Stats.TYPE_ORDER:
		var exact := n * maxf(0.0, float(shape.get(t, 0.0))) / total
		out[t] = floori(exact)
		left -= out[t]
		fractions.append([exact - floori(exact), Stats.TYPE_ORDER.find(t), t])
	fractions.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in left:
		out[fractions[i % fractions.size()][2]] += 1
	return out


## Carries the earlier jobs' cards by `spec` (ChunkData.veteran_cards).
func carry_cards(spec: String) -> void:
	var parts := spec.split(":")
	match parts[0]:
		"max":
			Run.deck.learn_earlier(0)
		"all":
			Run.deck.learn_earlier(int(parts[1]) if parts.size() > 1 else 1)
		"draft":
			draft_left = int(parts[1]) if parts.size() > 1 else 0
			draft_level = int(parts[2]) if parts.size() > 2 else 1
		"":
			pass
		_:
			push_error("unknown veteran_cards spec %s (see ChunkData.veteran_cards)" % spec)


## Ours: a veteran who brings no weapon from the warehouse (the loadout goes on over this one)
## starts with the class's weapon family at the chunk's first item level instead of its level-1
## piece, which can't scratch a monster at that level.
func _arm(c: ChunkData) -> void:
	if c.regions.is_empty() or Run.cls.start_weapon == null:
		return
	var top := c.regions[0].gear_levels.x
	var best: ItemData = Run.cls.start_weapon
	for it in Run.gear.items:
		if it.slot == ItemData.Slot.WEAPON and it.family == Run.cls.start_weapon.family and not it.legend \
				and it.level <= top and it.level > best.level:
			best = it
	Run.gear.equipment["weapon"] = GearItem.make(best)
