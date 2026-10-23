extends SmokeTest
## Map-independent entry point for the gun damage checks used by the Sense smoke section.


func _ready() -> void:
	_section(GUN_BONUSES).run()
	print("\n%s: %d gun bonus failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
