extends SmokeTest
## Map-independent entry point for Charm activation checks.

## Shared Charm preparation section.
const CHARM_PREPARATION := preload("res://tests/smoke/charm_preparation.gd")


func _ready() -> void:
	_section(CHARM_PREPARATION).run()
	print("\n%s: %d Charm preparation failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
