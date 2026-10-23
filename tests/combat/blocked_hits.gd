extends SmokeTest
## Map-independent entry point for rejected-contact regression checks.

## Shared hit-acceptance section.
const BLOCKED_HITS := preload("res://tests/smoke/blocked_hits.gd")


func _ready() -> void:
	_section(BLOCKED_HITS).run()
	print("\n%s: %d blocked hit failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
