extends SmokeTest
## Isolated verification of angle-wrap and airborne observation checks; no production changes.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/transient_checks.gd").new()
	section.runner = self
	add_child(section)
	await section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
