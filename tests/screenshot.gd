extends SceneTree
## Captures a mid-fight screenshot of the combat room.
## Run (needs a window): godot --path . -s res://tests/screenshot.gd -- <out.png>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://poc_screenshot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await create_timer(4.6).timeout
	var player: Player = arena.player
	for e in get_nodes_in_group("enemies"):
		e.global_position = player.global_position + Vector2(randf_range(-90, 90), randf_range(-50, 50))
	await create_timer(0.75).timeout
	player.aim = Combat.ground(Vector2(1, 0.4))
	player._start_attack(1)
	await create_timer(0.12).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
	quit()
