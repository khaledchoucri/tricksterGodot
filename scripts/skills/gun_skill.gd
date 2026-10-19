extends Skill
## Gun skills that fire the loaded gun (GunCycle; each starts a reload):
## Power Shot (3202, a concentrated round), Double Shot (3206, two in a row:
## the second can't be dodged) and Shield Breaker (3207, a breaching round:
## the enemy takes more gun damage for its seconds). They shoot along the
## aim like the basic shot (gun_shot.gd's line).

const GunShot := preload("res://scripts/skills/gun_shot.gd")


func _init() -> void:
	duration = 0.32
	anim = "attack_gun"
	dash_cancel_at = 0.15


func start() -> void:
	var gun := player.gun
	if not gun.fire():
		return
	var power := gun.last_power
	var reach := param("range", float(gun.gun.get("range", 220)))
	if card.id == &"shield_breaker":
		var fx := {"debuffs": {"gunbreak": [card.value_at(level), param("seconds", 5.0)]}}
		GunShot.fire_line(self, aim, reach, NORMAL_HIT_SHARE * Run.gun_shot_mult(), power, fx)
		return
	var shots := maxi(int(param("count", 1)), 1)
	var share := damage() / shots
	if shots == 1:
		GunShot.fire_line(self, aim, reach, share, power)
		return
	linger()
	for i in shots:
		# The second of a Double Shot can't be dodged (it never grazes).
		GunShot.fire_line(self, aim, reach, share, power or i > 0, {"no_graze": i > 0})
		if i < shots - 1 and not await wait_for(0.1):
			break
	release()


## Shield Breaker's round itself hits lightly (the breach is the point).
const NORMAL_HIT_SHARE := 29.0
