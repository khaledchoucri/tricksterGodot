extends SmokeSection
## Idle wander uses the existing slow/DX factor, without slowing external knockback.

class StillSprite extends ActorSprite:
	## Animation is irrelevant to measured velocity and must not load asset files.
	func play_action(_act: String, _v := Vector2.ZERO, _duration := 0.0,
		_restart := false, _frames: Array = []) -> void:
		pass

class ClockEnemy extends Enemy:
	var clock := 10.0
	## Controlled gameplay time makes expiry synchronous and deterministic.
	func now() -> float:
		return clock


## Private actors only: no replaced autoload state, frames, signals or global RNG.
func run() -> void:
	var e := ClockEnemy.new()
	var sprite := StillSprite.new()
	e.sprite = sprite
	e.state = Enemy.State.IDLE
	e._state_len = 100.0
	e.walk_speed = 80.0
	e._wander_target = Vector2(120, 0)
	var rows: Array[Dictionary] = [{"slow": 0, "dx": 0, "factor": 1.0},
		{"slow": 50, "dx": 0, "factor": 0.5}, {"slow": 0, "dx": 50, "factor": 0.5},
		{"slow": 25, "dx": 25, "factor": 0.5}, {"slow": 100, "dx": 0, "factor": 0.2}]
	for row: Dictionary in rows:
		e.debuffs = {}
		e.apply_debuff("slow", row.slow, 1.0)
		e.apply_debuff("dx", row.dx, 1.0)
		e._state_idle()
		check(e.velocity.is_equal_approx(Vector2(80.0 * float(row.factor), 0)),
			"idle wander slow=%d DX=%d respects existing speed factor %.1f" % [row.slow, row.dx, row.factor])
	e.debuffs = {}
	e.apply_debuff("slow", 50.0, 1.0)
	e._knock = Vector2(15, -12)
	e._state_idle()
	check(e.velocity.is_equal_approx(Vector2(55, -12)), "slow affects walking but not knockback")
	e.clock = 11.0
	e._state_idle()
	check(e.velocity.is_equal_approx(Vector2(95, -12)), "slow expires on the gameplay clock")
	e._knock = Vector2.ZERO
	e._wander_target = Vector2(0, 120)
	e.clock = 10.0
	e._state_idle()
	check(e.velocity.is_equal_approx(Vector2(0, 40)), "slow applies equally in another wander direction")
	e.free()
	sprite.free()
