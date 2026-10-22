extends SmokeTest
## Map-independent entry point for boss timer checks used by the Boss smoke section.


func _ready() -> void:
	await _section(BOSS_PAUSE).run()
	print("\n%s: %d boss pause failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)
