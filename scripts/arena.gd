extends Node2D
## Coral Beach combat-room proof of concept. Builds the room, the player, the
## HUD and the wave sequence in code, and hosts shared feedback effects
## (hit-stop, screen shake, damage numbers, ground effects).

const ARENA_HALF := Vector2(560, 280)  # half-extents of the diamond floor
const TILE := Vector2(64, 32)
const MAX_ATTACKERS := 2
const MONSTERS := {
	"torobbie": {"id": "2183", "kind": "melee", "radius": 12.0},
	"tottochi": {"id": "2185", "kind": "lunge", "radius": 16.0},
	"bustshell": {"id": "2186", "kind": "slam", "radius": 18.0},
	"golden_mole": {"id": "2037", "kind": "slam", "radius": 24.0},
}
const WAVES := [
	["torobbie", "torobbie", "torobbie"],
	["torobbie", "torobbie", "tottochi", "tottochi"],
	["tottochi", "tottochi", "bustshell", "torobbie", "torobbie"],
	["golden_mole"],
]

enum Phase { INTRO, FIGHT, BETWEEN, WIN, DEAD, MISSING }

var monster_data: Dictionary = {}
var phase := Phase.INTRO
var wave := -1
var alive := 0
var pending_spawns := 0
var attackers: Array = []
var run_time := 0.0
var kills := 0

var world: Node2D
var ground_fx: Node2D
var player: Player
var camera: Camera2D
var _shake := 0.0
var _hitstop_id := 0

# HUD
var hud: CanvasLayer
var hp_bar: ProgressBar
var hp_label: Label
var skill_label: Label
var dash_label: Label
var wave_label: Label
var log_box: VBoxContainer
var center_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_name: Label
var overlay: ColorRect


func _enter_tree() -> void:
	add_to_group("arena")


func _ready() -> void:
	randomize()
	_build_hud()
	if not FileAccess.file_exists("res://original_assets/actors/buffalo/buffalo.json"):
		phase = Phase.MISSING
		_center("Original assets not found.\nRun the export tools described in docs/poc/README.md, then reopen the project.")
		return
	var path := "res://original_assets/data/monsters.json"
	if FileAccess.file_exists(path):
		monster_data = JSON.parse_string(FileAccess.get_file_as_string(path))
	_build_room()
	_spawn_player()
	_intro()


# ---------------------------------------------------------------- room

func _build_room() -> void:
	var floor_node := Node2D.new()
	floor_node.name = "Floor"
	floor_node.z_index = -10
	floor_node.draw.connect(_draw_floor.bind(floor_node))
	add_child(floor_node)

	ground_fx = Node2D.new()
	ground_fx.name = "GroundFX"
	ground_fx.z_index = -5
	add_child(ground_fx)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var c := [Vector2(0, -ARENA_HALF.y), Vector2(ARENA_HALF.x, 0), Vector2(0, ARENA_HALF.y), Vector2(-ARENA_HALF.x, 0)]
	for i in 4:
		var seg := SegmentShape2D.new()
		seg.a = c[i]
		seg.b = c[(i + 1) % 4]
		var cs := CollisionShape2D.new()
		cs.shape = seg
		walls.add_child(cs)
	add_child(walls)


func _draw_floor(n: Node2D) -> void:
	var sand_a := Color("e9d3a8")
	var sand_b := Color("e2c995")
	var wet := Color("8fc6c4")
	var edge := Color("b98f5a")
	# Sea beyond the room so the edge reads as a shoreline.
	n.draw_rect(Rect2(-2000, -1200, 4000, 2400), Color("3f9ea6"))
	var steps := int(ARENA_HALF.x / (TILE.x / 2.0)) + 2
	for gx in range(-steps, steps):
		for gy in range(-steps, steps):
			var center := Vector2((gx - gy) * TILE.x / 2.0, (gx + gy) * TILE.y / 2.0)
			var k := absf(center.x) / ARENA_HALF.x + absf(center.y) / ARENA_HALF.y
			if k > 1.08:
				continue
			var col := sand_a if (gx + gy) % 2 == 0 else sand_b
			if k > 0.96:
				col = wet
			var pts := PackedVector2Array([
				center + Vector2(0, -TILE.y / 2.0), center + Vector2(TILE.x / 2.0, 0),
				center + Vector2(0, TILE.y / 2.0), center + Vector2(-TILE.x / 2.0, 0)])
			n.draw_colored_polygon(pts, col)
	var rim := PackedVector2Array([Vector2(0, -ARENA_HALF.y), Vector2(ARENA_HALF.x, 0),
		Vector2(0, ARENA_HALF.y), Vector2(-ARENA_HALF.x, 0), Vector2(0, -ARENA_HALF.y)])
	n.draw_polyline(rim, edge, 3.0, true)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.collision_layer = 0
	player.set_collision_layer_value(2, true)
	player.collision_mask = 0
	player.set_collision_mask_value(1, true)
	player.set_collision_mask_value(3, true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	player.add_child(shape)
	var sprite := ActorSprite.new()
	sprite.name = "Sprite"
	player.add_child(sprite)
	world.add_child(player)
	player.hp_changed.connect(_on_hp_changed)
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	player.add_child(camera)
	camera.make_current()


# ---------------------------------------------------------------- flow

func _intro() -> void:
	phase = Phase.INTRO
	_log("[Notice] Trickster service has ended. Thank you for playing.", Color("f07a62"))
	await get_tree().create_timer(1.0).timeout
	_log("[Coral Beach] Players online: 1", Color("94a7b2"))
	await get_tree().create_timer(1.0).timeout
	_log("[Hunter Yuri] Monsters are gathering on the beach. Clear them out!", Color("4cc2c4"))
	await get_tree().create_timer(1.2).timeout
	_next_wave()


func _next_wave() -> void:
	wave += 1
	if wave >= WAVES.size():
		_win()
		return
	phase = Phase.FIGHT
	var is_boss_wave: bool = WAVES[wave].has("golden_mole")
	wave_label.text = "Boss" if is_boss_wave else "Wave %d / %d" % [wave + 1, WAVES.size() - 1]
	_center("Real Golden Mole" if is_boss_wave else "Wave %d" % (wave + 1), 1.4)
	for i in WAVES[wave].size():
		_spawn_with_warning(WAVES[wave][i], _random_spawn_point(), 0.15 * i)


func _random_spawn_point() -> Vector2:
	for _i in 40:
		var p := Vector2(randf_range(-1, 1) * ARENA_HALF.x, randf_range(-1, 1) * ARENA_HALF.y) * 0.75
		if absf(p.x) / ARENA_HALF.x + absf(p.y) / ARENA_HALF.y > 0.8:
			continue
		if is_instance_valid(player) and p.distance_to(player.global_position) < 170.0:
			continue
		return p
	return Vector2(0, -ARENA_HALF.y * 0.5)


func _spawn_with_warning(key: String, at: Vector2, delay: float) -> void:
	pending_spawns += 1
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var warn := Telegraph.make("circle", 0.6, {"radius": 26.0, "color": Telegraph.SPAWN})
	add_ground_fx(warn, at)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(warn):
		warn.trigger()
	pending_spawns -= 1
	if phase == Phase.DEAD:
		return
	spawn_monster(key, at)


func spawn_monster(key: String, at: Vector2) -> Enemy:
	var def: Dictionary = MONSTERS[key]
	var e: Enemy = BossMole.new() if key == "golden_mole" else Enemy.new()
	e.body_radius = def.radius
	e.configure(def.id, monster_data.get(def.id, {}), key, def.kind)
	if key == "golden_mole":
		e.max_hp *= 3
		e.hp = e.max_hp
	e.position = at
	world.add_child(e)
	e.died.connect(_on_enemy_died)
	alive += 1
	if e.is_boss:
		boss_box.visible = true
		boss_name.text = e.display_name
		update_boss_bar(e)
		boss_speech(BossMole.LINES[0])
	return e


func summon_minions(at: Vector2, count: int) -> void:
	for i in count:
		var p := at + Vector2.from_angle(TAU * i / count) * Vector2(90, 45)
		_spawn_with_warning("torobbie", p, 0.1 * i)


func _on_enemy_died(e: Enemy) -> void:
	alive -= 1
	kills += 1
	release_attack_token(e)
	if e.is_boss:
		boss_box.visible = false
		for other in get_tree().get_nodes_in_group("enemies"):
			if other != e and other.is_hittable():
				other.take_hit(9999, Vector2.DOWN, 0.0, true)
	if alive <= 0 and pending_spawns <= 0 and phase == Phase.FIGHT:
		phase = Phase.BETWEEN
		await get_tree().create_timer(1.3).timeout
		if phase == Phase.BETWEEN:
			_next_wave()


func _win() -> void:
	phase = Phase.WIN
	wave_label.text = "Cleared"
	_log("[Notice] Coral Beach cleared in %s. Monsters defeated: %d." % [_fmt_time(run_time), kills], Color("e0b54d"))
	_center("Coral Beach cleared\n%s\n\nPress R to run it again" % _fmt_time(run_time))


func _on_player_died() -> void:
	phase = Phase.DEAD
	attackers.clear()
	await get_tree().create_timer(1.2).timeout
	overlay.visible = true
	var tw := create_tween()
	overlay.color = Color(0.05, 0.09, 0.12, 0.0)
	tw.tween_property(overlay, "color:a", 0.82, 0.6)
	_log("[System] Connection lost.", Color("f07a62"))
	await get_tree().create_timer(0.5).timeout
	_log("[System] Rolling back server state...", Color("f07a62"))
	_center("ROLLBACK\n\nYou reached wave %d.\nPress R to log in again." % (wave + 1))


func _process(delta: float) -> void:
	if phase == Phase.FIGHT or phase == Phase.BETWEEN:
		run_time += delta
	if Input.is_action_just_pressed("restart") and phase in [Phase.WIN, Phase.DEAD]:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	if camera:
		_shake = move_toward(_shake, 0.0, delta * 30.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if is_instance_valid(player):
		var t := player.now()
		skill_label.text = "Shockwave  [RMB]  " + ("ready" if t >= player.skill_ready_at else "%.1fs" % (player.skill_ready_at - t))
		dash_label.text = "Dash  [Space]  " + ("ready" if t >= player.dash_ready_at else "...")


func _fmt_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


# ---------------------------------------------------------------- shared feedback

## Limits how many enemies wind up at once so threats stay readable.
func request_attack_token(e: Enemy) -> bool:
	if e in attackers:
		return true
	if e.is_boss or attackers.size() < MAX_ATTACKERS:
		attackers.append(e)
		return true
	return false


func release_attack_token(e: Enemy) -> void:
	attackers.erase(e)


func hitstop(duration: float) -> void:
	_hitstop_id += 1
	var id := _hitstop_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _hitstop_id:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func add_ground_fx(node: Node2D, at: Vector2) -> void:
	ground_fx.add_child(node)
	node.global_position = at


func damage_number(at: Vector2, amount: int, color: Color) -> void:
	var l := Label.new()
	l.text = str(amount)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 50
	l.position = at + Vector2(randf_range(-10, 4), 0)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.tween_callback(l.queue_free)


func shockwave(at: Vector2, radius: float) -> void:
	var ring := Ring.new()
	ring.max_radius = radius
	add_ground_fx(ring, at)


func dash_trail(at: Vector2) -> void:
	var puff := Ring.new()
	puff.max_radius = 18.0
	puff.life = 0.25
	puff.color = Color(1, 1, 1, 0.6)
	add_ground_fx(puff, at)


func dust_burst(at: Vector2) -> void:
	var puff := Ring.new()
	puff.max_radius = 46.0
	puff.life = 0.45
	puff.color = Color("b98f5a")
	add_ground_fx(puff, at)


func update_boss_bar(e: Enemy) -> void:
	boss_bar.max_value = e.max_hp
	boss_bar.value = e.hp


func boss_speech(text: String) -> void:
	_log("[Real Golden Mole] " + text, Color("e0b54d"))


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var status := VBoxContainer.new()
	status.position = Vector2(20, 18)
	status.add_theme_constant_override("separation", 4)
	root.add_child(status)
	var name_label := _label("Buffalo  ·  Power", 15, Color("f4efe6"))
	status.add_child(name_label)
	hp_bar = _bar(Color("d9573f"), Vector2(240, 14))
	status.add_child(hp_bar)
	hp_label = _label("", 12, Color("f4efe6"))
	status.add_child(hp_label)
	skill_label = _label("", 12, Color("a8d8da"))
	status.add_child(skill_label)
	dash_label = _label("", 12, Color("a8d8da"))
	status.add_child(dash_label)

	wave_label = _label("", 16, Color("f4efe6"))
	wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wave_label.position = Vector2(-160, 18)
	wave_label.size = Vector2(140, 24)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(wave_label)

	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-220, 20)
	boss_box.custom_minimum_size = Vector2(440, 0)
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = _label("", 15, Color("e0b54d"))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = _bar(Color("e0b54d"), Vector2(440, 12))
	boss_box.add_child(boss_bar)

	log_box = VBoxContainer.new()
	log_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_box.position = Vector2(20, -150)
	log_box.custom_minimum_size = Vector2(560, 120)
	log_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(log_box)

	var hint := _label("WASD move  ·  LMB punch combo  ·  RMB Shockwave  ·  Space dash", 12, Color(1, 1, 1, 0.55))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 0
	hint.offset_right = -20
	hint.offset_top = -32
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	root.add_child(overlay)

	center_label = _label("", 30, Color("f4efe6"))
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(center_label)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.13))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _bar(color: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.1, 0.13, 0.85)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _on_hp_changed(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "HP %d / %d" % [hp, max_hp]


func _log(text: String, color: Color) -> void:
	var l := _label(text, 13, color)
	log_box.add_child(l)
	while log_box.get_child_count() > 6:
		log_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)


func _center(text: String, hold := 0.0) -> void:
	center_label.text = text
	center_label.modulate.a = 1.0
	if hold > 0.0:
		var tw := center_label.create_tween()
		tw.tween_interval(hold)
		tw.tween_property(center_label, "modulate:a", 0.0, 0.4)


## Expanding ground ring used for the Shockwave skill, dash puffs and dust.
class Ring extends Node2D:
	var max_radius := 90.0
	var life := 0.35
	var color := Color(1.0, 0.95, 0.8, 0.9)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var p := _t / life
		var r := max_radius * (0.3 + 0.7 * p)
		var pts := PackedVector2Array()
		for i in 41:
			var a := TAU * i / 40.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
		draw_polyline(pts, Color(color, color.a * (1.0 - p)), 3.0 * (1.0 - p) + 1.0, true)
