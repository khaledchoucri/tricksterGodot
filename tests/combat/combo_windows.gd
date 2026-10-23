extends SmokeTest
## Map-independent entry point for combo timing checks used by the Power smoke section.


func _ready() -> void:
	_section(COMBO_WINDOWS).run()
	print("\n%s: %d combo window failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
