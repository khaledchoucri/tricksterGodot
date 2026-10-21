extends Node
## Visual check for a carried gun: Lion idles, walks, shoots in every
## direction, dashes, casts and is hit, and each moment is saved with the
## animation playing and whether the gun is drawn. Saves <out>/gun_<n>.png
## and prints one line per capture. Run windowed (it renders):
##   godot res://tests/gun_qa.tscn -- out=C:/path [class=lion]

var out := ""
var who := "lion"
var n := 0
var game: Node
var p: Player


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("class="):
			who = a.substr(6)
	Profile.use_path("user://gun_qa_profile.json", true)
	Profile.class_id = who
	_go.call_deferred()


func _go() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	p = game.player
	for e: Enemy in game.room.enemies:
		e.global_position = game.room.random_spot(p.global_position, 600.0)
		e.apply_debuff("hold", 1.0, 999.0)
	await get_tree().create_timer(0.3).timeout
	await _shoot_at(Vector2.RIGHT, "idle")
	await _snap("idle (standing)")
	await get_tree().create_timer(1.0).timeout
	await _snap("idle, 1 s later")
	# Walk right.
	Input.action_press("move_right")
	for i in 4:
		await get_tree().create_timer(0.12).timeout
		await _snap("walk right")
	Input.action_release("move_right")
	await get_tree().create_timer(0.4).timeout
	# Shoot in eight directions.
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0)
		await _shoot_at(d, "shoot %d deg" % (k * 45))
	# Dash, a skill, a hit.
	p.aim = Vector2.RIGHT
	p.buffer_action("dash")
	await get_tree().create_timer(0.08).timeout
	await _snap("dash")
	await get_tree().create_timer(0.6).timeout
	Run.deck.cards[&"power_shot"] = 1
	Run.deck.loadout[0] = &"power_shot"
	Run.mp = Run.max_mp
	p.skills.slot_ready_at[0] = 0.0
	p.skills.try_cast(0)
	for i in 3:
		await get_tree().create_timer(0.08).timeout
		await _snap("power shot")
	await get_tree().create_timer(0.6).timeout
	p.take_hit(1, Vector2.LEFT, 0.0)
	await get_tree().create_timer(0.05).timeout
	await _snap("hit")
	get_tree().quit()


func _shoot_at(d: Vector2, label: String) -> void:
	p.gun.state = GunCycle.State.LOADED
	p.aim = d
	p.skills.slot_ready_at[SkillCaster.BASIC] = 0.0
	p.buffer_action("attack")
	for i in 3:
		await get_tree().create_timer(0.07).timeout
		await _snap(label)
	await get_tree().create_timer(0.3).timeout
	await _snap(label + ", after")


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var s := p.sprite
	var gun: Sprite2D = s._worn.get("gun", {}).get("sprite")
	print("%02d %-16s %s f%d  gun %s" % [n, label, s.animation, s.frame,
		"drawn" if gun and gun.visible else ("hidden" if gun else "NOT WORN")])
	var img := get_viewport().get_texture().get_image()
	var c := get_viewport().get_canvas_transform() * p.global_position
	img.get_region(Rect2i(int(c.x) - 80, int(c.y) - 130, 160, 150)).save_png("%s/gun_%02d.png" % [out, n])
	n += 1
