extends SmokeTest
## Runs isolated rune/deck level checks without maps.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/rune_level.gd").new()
	section.runner = self
	add_child(section)
	section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
