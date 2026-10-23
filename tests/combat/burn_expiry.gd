extends SmokeTest
## Map-independent entry point for the burn checks used by the Elements smoke section.


func _ready() -> void:
	_section(BURN_EXPIRY).run()
	print("\n%s: %d burn expiry failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
