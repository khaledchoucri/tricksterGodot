extends SmokeTest
## Runs equipment health checks without loading maps or constructing a game.

func _ready() -> void:
	var section: SmokeSection = preload("res://tests/smoke/equip_hp.gd").new()
	section.runner = self
	add_child(section)
	section.run()
	section.free()
	get_tree().quit(1 if failures > 0 else 0)
