extends SmokeSection
## The original art the game draws and how it plays: every monster of every region has its sprite
## and shows on every frame, standing monsters fidget, grazed ones dodge and echoes run; every shield
## is worn by every character that can carry one, in every direction of the poses it walks and stands in.

## The poses a worn shield must show in: the original's pivot files place shields on all of their
## frames (tools/pivots.py; the punchers through their equipped poses, ActorSprite.SHIELD_POSE).
const SHIELD_POSES: Array[String] = ["idle", "walk", "run"]
## The actions enemy.gd plays on every monster.
const MONSTER_ACTIONS: Array[String] = ["idle", "walk", "attack", "hit", "faint"]


func run() -> void:
	_monsters()
	_shields()
	await _fidget()


## A monster standing still plays its idle_auto clip through now and then, and goes back to idle.
func _fidget() -> void:
	if not is_instance_valid(game.room) or not is_instance_valid(game.player):
		game._load_room()  # an earlier section left the game without a room
		await wait(3.0)
	var e: Enemy = game.room.spawn(&"torobbie", game.room.random_spot(game.player.global_position, 260.0))
	var seen := {}
	for _i in 60 * int(Enemy.FIDGET_EVERY.y * 2.0 + 2.0):
		if not is_instance_valid(e):
			break
		if e.state != Enemy.State.SPAWN:
			e.state = Enemy.State.IDLE  # keep it standing: no chase, no wander
			e._state_len = 999.0
			e._wander_target = e.global_position
		seen[e.sprite.action] = true
		if seen.has("idle_auto") and e.sprite.action == "idle":
			break
		await get_tree().physics_frame
	check(seen.has("idle_auto") and seen.has("idle"), "a standing monster fidgets with its idle_auto clip and returns to idle (%s)"
		% ", ".join(seen.keys()))
	# A graze is the monster half evading: it shows its dodge clip; a clean hit shows its hit clip.
	var reactions: Array[String] = []
	for fx: Dictionary in [{"graze": true}, {}]:
		e.state = Enemy.State.IDLE
		e.take_hit(1, Vector2.RIGHT, 0.0, false, fx)
		reactions.append(e.sprite.action)
		await wait(0.5)
	check(reactions == ["dodge", "hit"], "a grazed monster dodges, a hit one flinches (%s)" % ", ".join(reactions))
	_remove(e)
	# An echo (another class's character) chases at a run, as a player does.
	var echo: Enemy = game.room.spawn(&"echo_bard", game.room.random_spot(game.player.global_position, 300.0))
	var ran := false
	for _i in 240:
		if not is_instance_valid(echo):
			break
		ran = ran or (echo.state == Enemy.State.CHASE and echo.sprite.action == "run")
		if echo.state == Enemy.State.IDLE:
			echo._state_len = 0.0  # chase now
		await get_tree().physics_frame
	check(ran, "a chasing echo runs")
	if is_instance_valid(echo):
		_remove(echo)


## Every monster a region or an echo can spawn has exported sprites with the actions enemy.gd plays,
## and no frame of any of its animations is blank.
func _monsters() -> void:
	var bad: PackedStringArray = []
	var count := 0
	var s := ActorSprite.new()
	add_child(s)
	for path: String in _enemy_paths():
		var e: EnemyData = load(path)
		count += 1
		if not s.setup(String(e.id)):
			bad.append("%s: no sprites" % e.id)
			continue
		var lacking := MONSTER_ACTIONS.filter(func(a: String) -> bool: return not s.has_action(a))
		if not lacking.is_empty():
			bad.append("%s: no %s" % [e.id, ", ".join(lacking)])
		for anim: StringName in s.sprite_frames.get_animation_names():
			for i in s.sprite_frames.get_frame_count(anim):
				var img := s.sprite_frames.get_frame_texture(anim, i).get_image()
				if img == null or img.get_used_rect().size == Vector2i.ZERO:
					bad.append("%s: %s frame %d is blank" % [e.id, anim, i])
					break
	s.queue_free()
	check(bad.is_empty() and count > 0, "all %d monsters have sprites with %s and no blank frame%s"
		% [count, ", ".join(MONSTER_ACTIONS), "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 8))])


## The EnemyData of every region (data/<region>/enemies) and the echoes.
func _enemy_paths() -> PackedStringArray:
	var out: PackedStringArray = []
	var dirs: PackedStringArray = ["res://data/echoes"]
	for region in DirAccess.get_directories_at("res://data"):
		if DirAccess.dir_exists_absolute("res://data/%s/enemies" % region):
			dirs.append("res://data/%s/enemies" % region)
	for dir in dirs:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tres"):
				out.append(dir.path_join(f))
	return out


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
