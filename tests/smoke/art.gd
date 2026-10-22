extends SmokeSection
## The original art the game draws: every shield is worn by every character that can carry one, in
## every direction of the poses it walks and stands in.

## The poses a worn shield must show in: the original's pivot files place shields on all of their
## frames (tools/pivots.py; the punchers through their equipped poses, ActorSprite.SHIELD_POSE).
const SHIELD_POSES: Array[String] = ["idle", "walk", "run"]


func run() -> void:
	_shields()


## Every shield item has a worn sprite, and each character that can hold a shield shows it on every
## frame of SHIELD_POSES in all eight directions.
func _shields() -> void:
	var sprites := {}
	var no_art: PackedStringArray = []
	for f in DirAccess.get_files_at("res://data/items"):
		if not f.ends_with(".tres"):
			continue
		var it: ItemData = load("res://data/items/" + f)
		if it.slot == ItemData.Slot.SHIELD:
			if it.worn_sprite() == "":
				no_art.append(it.display_name)
			else:
				sprites[it.worn_sprite()] = true
	check(no_art.is_empty() and not sprites.is_empty(),
		"every shield has a worn sprite (%d sprites)%s" % [sprites.size(), "" if no_art.is_empty() else ": " + ", ".join(no_art)])
	var missing: PackedStringArray = []
	var s := ActorSprite.new()
	add_child(s)
	for actor: String in _shield_actors():
		s.setup(actor)
		s.shield_pose = true
		for item: String in sprites:
			s.wear("shield", item)
			var gaps := _unshown(s)
			if gaps != "":
				missing.append("%s/%s: %s" % [actor, item, gaps])
			s.wear("shield", "")
	s.queue_free()
	check(missing.is_empty(), "every shield shows on every frame of %s, in every direction, on every character that holds one%s"
		% [", ".join(SHIELD_POSES), "" if missing.is_empty() else ": " + "; ".join(missing.slice(0, 6))])


## The first pose and direction of SHIELD_POSES where the worn shield is hidden, or "".
func _unshown(s: ActorSprite) -> String:
	for act: String in SHIELD_POSES:
		for d: String in ActorSprite.DIRS:
			s.play_action(act, Vector2.from_angle(ActorSprite.DIRS.find(d) * PI / 4.0), 0.0, true)
			for i in s.sprite_frames.get_frame_count(s.animation):
				s.frame = i
				s.frame_changed.emit()  # frame 0 after a restart doesn't emit by itself
				if not s.worn_shown("shield"):
					return "%s_%s frame %d" % [act, d, i]
	return ""


## The characters of every class that can carry a shield (a gun takes both hands), every job's.
func _shield_actors() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://data/classes"):
		if not f.ends_with(".tres"):
			continue
		var cls: ClassData = load("res://data/classes/" + f)
		if cls.start_weapon and cls.start_weapon.family == "gun":
			continue
		var jobs: Array[JobData] = [cls.start_job]
		var i := 0
		while i < jobs.size():
			var actor := jobs[i].actor if jobs[i].actor != "" else cls.actor
			if not actor in out:
				out.append(actor)
			for j: JobData in jobs[i].next_jobs:
				if not j in jobs:
					jobs.append(j)
			i += 1
	return out
