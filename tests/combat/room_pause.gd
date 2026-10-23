extends SmokeTest
## Runs asynchronous gameplay-delay checks after no map-dependent game has been constructed.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/room_pause.gd").new()
	section.runner = self
	add_child(section)
	await section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
