extends Node
## Captures a mid-fight screenshot of a run.
## Run (needs a window): godot --path . res://tests/screenshot.tscn -- <out.png>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://poc_screenshot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().create_timer(4.2).timeout
	var player: Player = game.player
	for e in get_tree().get_nodes_in_group("enemies"):
		e.global_position = game.room.random_spot(player.global_position, 60.0).lerp(player.global_position, 0.5)
	await get_tree().create_timer(0.7).timeout
	player.aim = Combat.ground(Vector2(1, 0.4))
	player._start_attack(0)
	await get_tree().create_timer(0.12).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
	get_tree().quit()
