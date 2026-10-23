extends SmokeTest
## Runs idle-wander status checks without maps or a game scene.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/idle_slow.gd").new()
	section.runner = self
	add_child(section)
	section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
