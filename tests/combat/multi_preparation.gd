extends SmokeTest
## Map-independent entry point for dynamic-duration activation checks.

## Shared multi-hit preparation section.
const MULTI_PREPARATION := preload("res://tests/smoke/multi_preparation.gd")


func _ready() -> void:
	_section(MULTI_PREPARATION).run()
	print("\n%s: %d multi-hit preparation failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
