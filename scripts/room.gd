class_name Room
extends Node2D
## One combat room cut from an original Trickster map. Builds the ground,
## depth-sorted props and collision from the exported map, runs the room's
## enemy waves, and opens exit doors once it's cleared. Owns the enemies it
## spawns and hands them their references.

signal cleared
signal door_entered(reward: String, feature: StringName)

const CELL := 16
const VIEW_MARGIN := 420.0
## How many enemies may wind up at once, so threats stay readable.
const MAX_ATTACKERS := 2
const MAX_SHOOTERS := 2
## Physics layers: 1 map obstacles, 2 player, 3 enemies, 4 room boundary.
const BOUNDARY_LAYER_BIT := 8
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss_mole.tscn")
const DOOR_SCENE := preload("res://scenes/door.tscn")
## Points on an actor's body, relative to its feet, checked for being hidden.
const BODY_POINTS: Array[Vector2] = [Vector2(0, -6), Vector2(0, -26), Vector2(0, -46), Vector2(-9, -26), Vector2(9, -26)]

var data: RoomData
var rect: Rect2
var map_info: Dictionary
var cols := 0
var rows := 0
var walk := PackedByteArray()       # 1 = walkable, per 16 px map cell
var reachable := PackedByteArray()  # walkable and connected to the entry
var astar := AStarGrid2D.new()
var entry := Vector2.ZERO
var world: Node2D
var ground_fx: Node2D
## Set by the game once the player is spawned.
var player: Player
var enemies: Array[Enemy] = []
var attackers: Array[Enemy] = []

var waves: Array = []
var wave := -1
var alive := 0
var pending := 0
var doors: Array[Door] = []
var props: Array[Prop] = []
var _cleared := false


func build(p_data: RoomData) -> bool:
	data = p_data
	rect = Rect2(data.rect)
	var dir := "res://original_assets/maps/%s/" % data.map
	if not FileAccess.file_exists(dir + "map.json"):
		push_warning("Missing exported map %s; run tools/setup_assets.py" % data.map)
		return false
	map_info = JSON.parse_string(FileAccess.get_file_as_string(dir + "map.json"))
	var view := rect.grow(VIEW_MARGIN).intersection(Rect2(0, 0, map_info.width, map_info.height))

	var ground := Sprite2D.new()
	ground.texture = load(dir + "ground.png")
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = view
	ground.position = view.position
	ground.z_index = -10
	add_child(ground)

	ground_fx = Node2D.new()
	ground_fx.z_index = -5
	add_child(ground_fx)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	_build_props(dir, view)
	var mask: Image = (load(dir + "collision.png") as Texture2D).get_image()
	_build_grids(mask)
	_build_collision(mask)
	return true


# ---------------------------------------------------------------- map

func _build_props(dir: String, view: Rect2) -> void:
	for group: Array in [["objects", world, 0], ["top", self, 20]]:
		for o: Dictionary in map_info[group[0]]:
			var info: Dictionary = map_info.sprites[o.sprite]
			var pos := Vector2(o.x, o.y)
			var anchor := Vector2(info.anchor[0], info.anchor[1])
			var bounds := Rect2(pos - anchor, Vector2(info.size[0], info.size[1]))
			if not view.intersects(bounds):
				continue
			var prop := Prop.new()
			prop.position = pos
			prop.setup(load(dir + "objects/%s.png" % o.sprite), anchor, group[0] == "top")
			prop.z_index = group[2]
			(group[1] as Node).add_child(prop)
			props.append(prop)


func _build_grids(mask: Image) -> void:
	cols = mask.get_width()
	rows = mask.get_height()
	walk.resize(cols * rows)
	for y in rows:
		for x in cols:
			walk[y * cols + x] = 1 if mask.get_pixel(x, y).a < 0.5 else 0
	var c0 := _cell(rect.position)
	var c1 := _cell(rect.end - Vector2.ONE)
	astar.region = Rect2i(c0, c1 - c0 + Vector2i.ONE)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL, CELL) / 2.0
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			astar.set_point_solid(Vector2i(x, y), not _open(x, y))
	_find_entry_and_reachable(c0, c1)


## Keeps the largest connected walkable area; the entry is its point nearest
## the bottom middle of the room, where the player walks in.
func _find_entry_and_reachable(c0: Vector2i, c1: Vector2i) -> void:
	reachable.resize(cols * rows)
	reachable.fill(0)
	var seen := {}
	var best: Array[Vector2i] = []
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if not _open(x, y) or seen.has(Vector2i(x, y)):
				continue
			var comp: Array[Vector2i] = []
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while queue.size() > 0:
				var c: Vector2i = queue.pop_back()
				comp.append(c)
				for n: Vector2i in [c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP]:
					if n.x >= c0.x and n.x <= c1.x and n.y >= c0.y and n.y <= c1.y and not seen.has(n) and _open(n.x, n.y):
						seen[n] = true
						queue.append(n)
			if comp.size() > best.size():
				best = comp
	for c in best:
		reachable[c.y * cols + c.x] = 1
	entry = nearest_reachable(rect.position + rect.size * Vector2(0.5, 0.9))


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _open(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < cols and y < rows and walk[y * cols + x] == 1


func _build_collision(mask: Image) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# Map obstacles inside the room, traced from the walkability mask.
	var c0 := _cell(rect.position) - Vector2i.ONE
	var size := _cell(rect.end) - c0 + Vector2i(2, 2)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(mask.get_region(Rect2i(c0, size)), 0.5)
	for poly in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 0.6):
		var pts := PackedVector2Array()
		for p in poly:
			pts.append((p + Vector2(c0)) * CELL)
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		body.add_child(cp)
	# Room boundary, on its own layer: a dash can vault obstacles but never
	# leave the room.
	var edge := StaticBody2D.new()
	edge.collision_layer = BOUNDARY_LAYER_BIT
	edge.collision_mask = 0
	add_child(edge)
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var seg := SegmentShape2D.new()
		seg.a = corners[i]
		seg.b = corners[(i + 1) % 4]
		var cs := CollisionShape2D.new()
		cs.shape = seg
		edge.add_child(cs)


# ---------------------------------------------------------------- services for actors

func add_ground_fx(node: Node2D, at: Vector2) -> void:
	ground_fx.add_child(node)
	node.global_position = at


## Monsters in the room that are still fighting.
func live_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.state != Enemy.State.DEAD:
			n += 1
	return n


func request_attack_token(e: Enemy) -> bool:
	if e in attackers:
		return true
	if e.is_boss or attackers.size() < MAX_ATTACKERS:
		attackers.append(e)
		return true
	return false


func release_attack_token(e: Enemy) -> void:
	attackers.erase(e)


# ---------------------------------------------------------------- queries

func is_inside(p: Vector2) -> bool:
	return rect.has_point(p)


func is_walkable(p: Vector2) -> bool:
	if not rect.grow(-6.0).has_point(p):
		return false
	var c := _cell(p)
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows and reachable[c.y * cols + c.x] == 1


## Walkable with a little clearance, so spawns don't touch walls.
func is_open_spot(p: Vector2) -> bool:
	for d: Vector2 in [Vector2.ZERO, Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
		if not is_walkable(p + d):
			return false
	return true


func nearest_reachable(target: Vector2) -> Vector2:
	var best := rect.get_center()
	var best_d := INF
	var c0 := _cell(rect.position)
	var c1 := _cell(rect.end - Vector2.ONE)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if reachable[y * cols + x] != 1:
				continue
			var p := Vector2(x, y) * CELL + Vector2(CELL, CELL) / 2.0
			var d := p.distance_squared_to(target)
			if d < best_d and is_open_spot(p):
				best_d = d
				best = p
	return best


func random_spot(avoid: Vector2, min_dist: float) -> Vector2:
	for _i in 120:
		var p := Vector2(Run.rng.randf_range(rect.position.x + 40, rect.end.x - 40), Run.rng.randf_range(rect.position.y + 40, rect.end.y - 40))
		if is_open_spot(p) and p.distance_to(avoid) >= min_dist:
			return p
	return nearest_reachable(rect.get_center())


func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 8.0)
	for i in steps:
		if not is_walkable(a.lerp(b, float(i + 1) / (steps + 1))):
			return false
	return true


## Where a dash from `from` along `dir` (screen space) for `dist` should land
## when map obstacles block the way: the dash's own end point if it's open
## ground past the obstacle, otherwise the first open spot past it, up to
## `extra` further. Returns -1.0 when nothing blocks the way or there's
## nowhere to land (then the dash just stops at the obstacle).
func vault_distance(from: Vector2, dir: Vector2, dist: float, extra: float) -> float:
	var step := 6.0
	var blocked_at := -1.0
	var d := step
	while d <= dist:
		if not is_walkable(from + dir * d):
			blocked_at = d
			break
		d += step
	if blocked_at < 0.0:
		return -1.0
	if is_open_spot(from + dir * dist) and not _blocked_between(from, dir, blocked_at, dist):
		return dist
	d = blocked_at
	while d <= dist + extra:
		if is_open_spot(from + dir * d):
			return d
		d += step
	return -1.0


## True if the ground is blocked again after the first obstacle, before `to`
## (e.g. a second wall), so landing at `to` would skip more than one obstacle.
func _blocked_between(from: Vector2, dir: Vector2, start: float, to: float) -> bool:
	var d := start
	var cleared := false
	while d <= to:
		var open := is_walkable(from + dir * d)
		if open:
			cleared = true
		elif cleared:
			return true
		d += 6.0
	return false


func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var from := _cell(a)
	var to := _cell(b)
	if not astar.is_in_boundsv(from) or not astar.is_in_boundsv(to):
		return PackedVector2Array()
	return astar.get_point_path(from, to, true)


# ---------------------------------------------------------------- encounter

func start_encounter(depth: int, elite: bool, boss: bool) -> void:
	waves = [[{"id": _boss_id(), "elite": false}]] if boss else _make_waves(depth, elite)
	_next_wave()


func _boss_id() -> StringName:
	for e in Run.route.region.enemies:
		if e.is_boss:
			return e.id
	return &""


func _make_waves(depth: int, elite: bool) -> Array:
	var pool: Array[EnemyData] = []
	for e in Run.route.region.enemies:
		if not e.is_boss and depth >= e.min_depth:
			pool.append(e)
	var out: Array = []
	var count := 2 if depth < 3 else 3
	for w in count:
		var budget := 3.0 + depth * 1.2 + w * 1.5 + Run.route.region_index() * 2.0
		var wave_list: Array[Dictionary] = []
		var shooters := 0
		while budget >= 1.0:
			# At most MAX_SHOOTERS ranged monsters a wave: a pack that backs off
			# and fires leaves a melee build nothing to do but chase.
			var options := pool.filter(func(e: EnemyData) -> bool:
				return e.cost <= budget and (e.kind != "shot" or shooters < MAX_SHOOTERS))
			if options.is_empty():
				break
			var pick: EnemyData = options[Run.rng.randi() % options.size()]
			# A featured monster (its den) fills about half of each wave.
			var featured := Run.enemy(Run.route.current_room().feature) if Run.route.current_room().feature != &"" else null
			if featured and featured in options and Run.rng.randf() < 0.5:
				pick = featured
			if pick.kind == "shot":
				shooters += 1
			wave_list.append({"id": pick.id, "elite": false})
			budget -= pick.cost
		for _i in ServerSettings.extra_per_wave():
			if not pool.is_empty():
				wave_list.append({"id": pool[Run.rng.randi() % pool.size()].id, "elite": false})
		if ServerSettings.pk_mode() and depth >= 1 and not wave_list.is_empty():
			wave_list[0].elite = true
		out.append(wave_list)
	var echo := Run.echo_here() if elite else null
	if echo:
		out[out.size() - 1].append({"id": echo.id, "elite": false})
	if elite:
		# One elite in each of the last two waves.
		for w in range(maxi(0, out.size() - 2), out.size()):
			out[w][0].elite = true
	return out


func _next_wave() -> void:
	if _cleared:
		return
	wave += 1
	if wave >= waves.size():
		_cleared = true
		cleared.emit()
		return
	var from := player.global_position if is_instance_valid(player) else entry
	for i in waves[wave].size():
		var e: Dictionary = waves[wave][i]
		spawn_with_warning(e.id, random_spot(from, 170.0), 0.15 * i, e.elite)


func spawn_with_warning(id: StringName, at: Vector2, delay: float, elite := false) -> void:
	pending += 1
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var warn := Telegraph.make("circle", 0.6, {"radius": 26.0, "color": Telegraph.SPAWN})
	add_ground_fx(warn, at)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(warn):
		warn.trigger()
	pending -= 1
	spawn(id, at, elite)


func spawn(id: StringName, at: Vector2, elite := false) -> Enemy:
	var enemy_data := Run.enemy(id)
	var scene: PackedScene = enemy_data.scene if enemy_data.scene else (BOSS_SCENE if enemy_data.is_boss else ENEMY_SCENE)
	var e: Enemy = scene.instantiate()
	e.configure(enemy_data, Run.monster_stats(enemy_data), elite)
	e.room = self
	e.player = player
	e.position = at
	world.add_child(e)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	alive += 1
	Events.enemy_spawned.emit(e)
	return e


func summon(at: Vector2, id: StringName, count: int) -> void:
	for i in count:
		var p := at + Vector2.from_angle(TAU * i / count) * Vector2(90, 45)
		if not is_open_spot(p):
			p = nearest_reachable(p)
		spawn_with_warning(id, p, 0.1 * i)


func _on_enemy_died(e: Enemy) -> void:
	alive -= 1
	enemies.erase(e)
	release_attack_token(e)
	if e.is_boss:
		for other in enemies.duplicate():
			if other.is_hittable():
				other.take_hit(9999, Vector2.DOWN, 0.0, true)
	if alive <= 0 and pending <= 0 and not _cleared:
		# Several deaths at once (a boss taking its summons with it) each get
		# here; only the first advances the wave.
		var at_wave := wave
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree() and alive <= 0 and pending <= 0 and wave == at_wave and not _cleared:
			_next_wave()


# ---------------------------------------------------------------- doors

## `features` (optional, one per door) names the monster each door's room
## leans on.
func open_doors(rewards: Array[String], features: Array[StringName] = []) -> void:
	var spots: Array[Vector2] = []
	var targets: Array[Vector2] = []
	if rewards.size() > 1:
		targets.append_array([Vector2(0.25, 0.12), Vector2(0.75, 0.12)])
	else:
		targets.append(Vector2(0.5, 0.1))
	for t in targets:
		var p := nearest_reachable(rect.position + rect.size * t)
		for other in spots:
			if p.distance_to(other) < 220.0:
				p = nearest_reachable(rect.position + rect.size * Vector2(1.0 - t.x, 0.35))
		spots.append(p)
	for i in rewards.size():
		var d: Door = DOOR_SCENE.instantiate()
		d.reward = rewards[i]
		if i < features.size() and features[i] != &"":
			d.feature = features[i]
			d.feature_name = Run.monster_name(Run.enemy(features[i]))
		d.position = spots[i]
		world.add_child(d)
		doors.append(d)


## Fades props that hide the player or an enemy. Returns true if the player is hidden.
func _update_occlusion() -> bool:
	var player_hidden := false
	for prop in props:
		var target := 1.0
		if is_instance_valid(player) and _hides(prop, player.global_position):
			target = Prop.HIDE_PLAYER_ALPHA
			player_hidden = true
		else:
			for e in enemies:
				if e.state != Enemy.State.DEAD and _hides(prop, e.global_position):
					target = Prop.HIDE_ENEMY_ALPHA
					break
		prop.target_alpha = target
	return player_hidden


func _hides(prop: Prop, feet: Vector2) -> bool:
	for p in BODY_POINTS:
		if prop.hides(feet + p, feet.y):
			return true
	return false


func _physics_process(_delta: float) -> void:
	var hidden := _update_occlusion()
	if is_instance_valid(player):
		player.set_hidden_behind_scenery(hidden)
	if doors.is_empty() or not is_instance_valid(player):
		return
	for d in doors:
		if d.ready_to_enter() and Combat.ground(player.global_position - d.global_position).length() < 30.0:
			var reward := d.reward
			var feature := d.feature
			for other in doors:
				other.queue_free()
			doors.clear()
			door_entered.emit(reward, feature)
			return
