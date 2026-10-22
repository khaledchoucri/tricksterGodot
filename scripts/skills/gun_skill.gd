extends Skill
## Gun skills that fire along the aim like the basic shot (gun_shot.gd's
## line): Power Shot (3202, a concentrated round), Double Shot (3206, two in
## a row: the second can't be dodged) and Shield Breaker (3207, a breaching
## round: the enemy takes more gun damage for its seconds). Their damage is a
## multiple of a gun shot (the table's Ratio). They need a gun but not a
## load, and leave the gun's cycle as it is (ours: in the original they used
## up bullets).

const GunShot := preload("res://scripts/skills/gun_shot.gd")


func _init() -> void:
	duration = 0.32
	anim = "attack_gun"
	dash_cancel_at = 0.15


func start() -> void:
	var reach := player.gun.range()
	var dir := GunShot.assisted_aim(self, reach)
	if card.id == &"shield_breaker":
		# The breaching round is 100% of a shot plus its breach (Ratio 0.2+),
		# with the same skill modifiers as the other gun skills.
		var fx := {"debuffs": {"gunbreak": [card.value_at(level), param("seconds", 5.0)]}}
		var amount := (100.0 + card.value_at(level)) * Run.formulas.skill_mult(card)
		GunShot.fire_line(self, dir, reach, amount, false, fx)
		return
	var shots := maxi(int(param("count", 1)), 1)
	var share := damage() / shots
	if shots == 1:
		GunShot.fire_line(self, dir, reach, share, false)
		return
	linger()
	for i in shots:
		# The second of a Double Shot can't be dodged (it never grazes).
		GunShot.fire_line(self, dir, reach, share, false, {"no_graze": i > 0})
		if i < shots - 1 and not await wait_for(0.1):
			break
	release()
