extends SmokeTest
## Map-independent entry point for the gun cover checks used by the Sense smoke section.

## Shared burst-visibility regression section.
const GUN_VISIBILITY := preload("res://tests/smoke/gun_visibility.gd")


func _ready() -> void:
	_section(GUN_VISIBILITY).run()
	print("\n%s: %d gun visibility failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
