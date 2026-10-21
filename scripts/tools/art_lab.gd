extends Node2D
## Art lab: plays imported characters (art_build/) on a Coral Beach room at
## game size, next to the current Buffalo, to judge generated animation in
## motion rather than as stills.
##
## Run from the editor (F6 on scenes/tools/art_lab.tscn) after importing art
## with art_import.tscn and letting Godot import the new sheets.
##   1-9        choose action          Left/Right  turn 45 degrees
##   W          walk around a circle   Space       pause / play
##   . (period) step one frame         M           mirror left-facing views
##   O          ink outline            P           palette lock
##   S          sword on / off         +/-         zoom
##   F12        screenshot to user://
## With `-- --shot <file.png>` it saves one screenshot and quits.

const STYLE := preload("res://shaders/actor_style.gdshader")
const SPACING := 90.0
const ORBIT := 60.0

var actors: Array[Node2D] = []
var actions: Array[String] = []
var action := 0
var facing := 1   # index into ActorSprite.DIRS
var walking := false
var paused := false
var mirror := false
var outline := true
var palette := false
var sword := true

var _room: Room
var _camera := Camera2D.new()
var _label := Label.new()
var _t := 0.0
var _home: Array[Vector2] = []


func _ready() -> void:
	_room = Room.new()
	add_child(_room)
	_room.build(Run.route.region.rooms[0])
	var center := _room.nearest_reachable(_room.rect.get_center())
	var names: Array[String] = ["buffalo"]
	if DirAccess.dir_exists_absolute("res://art_build"):
		for d in DirAccess.get_directories_at("res://art_build"):
			if FileAccess.file_exists("res://art_build/%s/%s.tres" % [d, d]):
				names.append(d)
	for i in names.size():
		var a := _make_actor(names[i], i > 0)
		a.position = center + Vector2((i - (names.size() - 1) / 2.0) * SPACING, 0)
		_room.world.add_child(a)
		actors.append(a)
		_home.append(a.position)
	var all := {}
	for a in actors:
		for act: String in (a.get_node("Sprite") as ActorSprite).available:
			all[act] = true
	actions.assign(all.keys())
	actions.sort()
	action = maxi(0, actions.find("idle"))
	_camera.zoom = Vector2(1.5, 1.5)
	_camera.position = center + Vector2(0, -30)
	add_child(_camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	ui.add_child(_label)
	_apply()
	var args := OS.get_cmdline_user_args()
	var shot := args.find("--shot")
	if shot >= 0 and shot + 1 < args.size():
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(args[shot + 1])
		get_tree().quit()


func _make_actor(actor_name: String, imported: bool) -> Node2D:
	var root := Node2D.new()
	root.name = actor_name
	var sprite := ActorSprite.new()
	sprite.name = "Sprite"
	root.add_child(sprite)
	sprite.setup(actor_name, "res://art_build" if imported else "res://original_assets/actors")
	if imported:
		var mat := ShaderMaterial.new()
		mat.shader = STYLE
		var pal_path := "res://art_build/%s/palette.png" % actor_name
		if FileAccess.file_exists(pal_path):
			mat.set_shader_parameter("palette", ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(pal_path))))
		sprite.material = mat
	var weapon := HeldWeapon.new()
	weapon.name = "Weapon"
	root.add_child(weapon)
	var label := Label.new()
	label.text = actor_name
	label.position = Vector2(-40, 8)
	label.size = Vector2(80, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	root.add_child(label)
	return root


func _apply() -> void:
	var act := actions[action] if actions.size() > 0 else "idle"
	var dir := Vector2.from_angle(TAU * facing / 8.0)
	for a in actors:
		var sprite: ActorSprite = a.get_node("Sprite")
		sprite.prefer_mirror = mirror
		var mat := sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("outline_on", outline)
			mat.set_shader_parameter("palette_on", palette)
		if not walking:
			sprite.play_action(act if sprite.has_action(act) else "idle", dir, 0.0, true)
		(a.get_node("Weapon") as CanvasItem).visible = sword
	_label.text = "%s  ·  facing %s%s%s  ·  outline %s  ·  palette %s  ·  sword %s%s\n1-9 action  ←/→ turn  W walk  Space pause  . step  M mirror  O outline  P palette  S sword  +/- zoom  F12 shot" % [
		act, ActorSprite.DIRS[facing], "  ·  mirrored" if mirror else "", "  ·  walking" if walking else "",
		"on" if outline else "off", "on" if palette else "off", "on" if sword else "off", "  ·  paused" if paused else ""]


func _process(delta: float) -> void:
	if not walking or paused:
		return
	_t += delta
	for i in actors.size():
		var a := actors[i]
		var ang := _t * 2.2 + i * 0.4
		var pos := _home[i] + Vector2(cos(ang) * ORBIT, sin(ang) * ORBIT * 0.5)
		var vel := pos - a.position
		a.position = pos
		var sprite: ActorSprite = a.get_node("Sprite")
		var act := "run" if sprite.has_action("run") else "walk"
		if vel.length() > 0.01:
			sprite.play_action(act, vel)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < actions.size():
		action = k - KEY_1
		walking = false
	elif k == KEY_LEFT:
		facing = posmod(facing - 1, 8)
	elif k == KEY_RIGHT:
		facing = posmod(facing + 1, 8)
	elif k == KEY_W:
		walking = not walking
		if not walking:
			for i in actors.size():
				actors[i].position = _home[i]
	elif k == KEY_SPACE:
		paused = not paused
		for a in actors:
			var s: ActorSprite = a.get_node("Sprite")
			if paused:
				s.pause()
			else:
				s.play()
	elif k == KEY_PERIOD:
		for a in actors:
			var s: ActorSprite = a.get_node("Sprite")
			s.pause()
			s.frame = (s.frame + 1) % s.sprite_frames.get_frame_count(s.animation)
		paused = true
	elif k == KEY_M:
		mirror = not mirror
	elif k == KEY_O:
		outline = not outline
	elif k == KEY_P:
		palette = not palette
	elif k == KEY_S:
		sword = not sword
	elif k == KEY_EQUAL or k == KEY_KP_ADD:
		_camera.zoom *= 1.25
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_camera.zoom /= 1.25
	elif k == KEY_F12:
		var path := "user://art_lab_%d.png" % Time.get_unix_time_from_system()
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return
	_apply()
