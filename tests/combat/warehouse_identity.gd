extends SmokeTest
## Runs warehouse identity checks without constructing the game or loading maps.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/warehouse_identity.gd").new()
	section.runner = self
	add_child(section)
	section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
