extends SmokeTest
## Map-independent entry point for skill activation checks used by the Power smoke section.

## Shared preparation regression section.
const SKILL_PREPARATION := preload("res://tests/smoke/skill_preparation.gd")


func _ready() -> void:
	_section(SKILL_PREPARATION).run()
	print("\n%s: %d skill preparation failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
