extends SmokeTest
## Map-independent entry point for the enemy movement checks used by the Core smoke section.


func _ready() -> void:
	_section(ENEMY_CONTROL).run()
	print("\n%s: %d enemy control failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
