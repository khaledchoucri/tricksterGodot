extends SmokeTest
## Map-independent entry point for ranged movement checks used by the Core smoke section.

## Shared retreat-slow regression section.
const RETREAT_SLOW := preload("res://tests/smoke/retreat_slow.gd")


func _ready() -> void:
	_section(RETREAT_SLOW).run()
	print("\n%s: %d retreat slow failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
