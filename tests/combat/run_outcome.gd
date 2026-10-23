extends SmokeTest
## Checks terminal banking without maps or asynchronous presentation.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/run_outcome.gd").new()
	section.runner = self
	add_child(section)
	section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
