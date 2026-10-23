extends SmokeTest
## Map-independent entry point for buffered dash input checks.

## Shared input-buffer section.
const DASH_BUFFER := preload("res://tests/smoke/dash_buffer.gd")


func _ready() -> void:
	_section(DASH_BUFFER).run()
	print("\n%s: %d dash buffer failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
