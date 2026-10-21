extends Skill
## The Charm line's close strikes at the enemy in front, each with the
## server's own attack (the card's scaling, see tools/re/README.md):
##  - Power Blow (4001): AP; Titanium Wrist adds its share to the Ratio.
##  - Final Blow (4012): AP plus a tenth of the HP you've lost.
##  - Volley Kick (4101): AP + 16 HV; kicks the enemy into the air.
##  - 2 Hit Combo (4302): a Power Blow, then a Volley Kick, each stronger
##    with that skill's level (x (0.2 x level + 1) on the server).
##  - Beast forms only: Beast Claw (4106, lunges at the enemy), Fatal Wound
##    (4107, bleeds), Raging Nail (4303, ignores part of DP), Wild Nail
##    (4207, HV alone) and Heavy Hit (4503, sends the enemy flying).

const ARC := deg_to_rad(90.0)
## The original levels of card levels 1-8 (skill_trees.LEVELS).
const LEVELS := [1, 3, 6, 8, 11, 11, 11, 11]
const COLOR := Color(1.0, 0.8, 0.9)

var _foe: Enemy
var _lunge := Vector2.ZERO


func _init() -> void:
	duration = 0.34
	anim = "attack"
	dash_cancel_at = 0.16


func start() -> void:
	match card.id:
		&"volley_kick", &"heavy_hit":
			duration = 0.42
			anim = "weapon_crit"
		&"two_hit_combo":
			duration = 0.62
			anim = "attack"
		&"beast_claw":
			duration = 0.36
	var reach := param("range", 80.0) + 30.0
	_foe = nearest_in_wedge(aim, reach, ARC)
	if card.id == &"beast_claw" and _foe:
		# The Rush: close the distance before the claw lands.
		var to := Combat.ground(_foe.global_position - player.global_position)
		_lunge = to.normalized() * maxf(to.length() - _foe.body_radius - 18.0, 0.0) / 0.14


func movement(t: float) -> Vector2:
	return _lunge if t < 0.14 else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	if card.id == &"two_hit_combo":
		if once(t, 0.12, "blow"):
			_strike(damage(0.5) * _two_hit(&"power_blow"), 80.0, {})
		if once(t, 0.4, "kick"):
			player.sprite.play_action("weapon_crit", Combat.screen(aim), 0.2, true)
			_strike(damage(0.5) * _two_hit(&"volley_kick"), 40.0, {"stun": 0.7}, true)
		return
	if not once(t, 0.14 if card.id == &"beast_claw" else 0.1):
		return
	if not is_instance_valid(_foe) or not _foe.is_hittable():
		_foe = nearest_in_wedge(aim, param("range", 80.0) + 30.0, ARC)
	var amount := damage()
	var fx := {}
	var knock := 120.0
	var up := false
	match card.id:
		&"power_blow":
			var ratio := param("ratio", 1.0)
			if skill_mod("ratio") > 0.0 and ratio > 0.0:  # Titanium Wrist
				amount *= (ratio + skill_mod("ratio") / 100.0) / ratio
		&"volley_kick":
			fx.stun = 0.7
			knock = 40.0
			up = true
		&"fatal_wound":
			var seconds := param("seconds", 10.0)
			fx = {"burn": amount * param("bleed", 10.0) / 100.0 / seconds, "burn_for": seconds}
		&"raging_nail":
			fx.dp_keep = 1.0 - param("ignore", 0.0) / 100.0
		&"heavy_hit":
			# "Pushed away by a distance based on the caster's AP."
			knock = 260.0 + 4.0 * Run.stat("AP")
			fx.stun = 0.5
	_strike(amount, knock, fx, up)


func _strike(amount: float, knock: float, fx: Dictionary, up := false) -> void:
	if not is_instance_valid(_foe) or not _foe.is_hittable():
		return
	Slash.spawn(room, player.global_position + Vector2(0, -16), {"radius": param("range", 80.0), "arc": ARC,
		"dir": aim, "clockwise": aim.x >= 0.0, "sweep_time": 0.08, "life": 0.2, "width": 12.0, "color": COLOR})
	hit(_foe, amount, knock, true, fx)
	if up:
		launch(_foe, 40.0, 0.5)
	feedback(0.05, 3.5 if knock > 200.0 else 2.5)


## 2 Hit Combo's hits grow with the skill they come from: x (0.2 x its
## original level + 1), against level 1's 1.2.
func _two_hit(id: StringName) -> float:
	var lvl := Run.deck.card_level(id)
	if lvl <= 0:
		return 1.0
	return (0.2 * LEVELS[mini(lvl, LEVELS.size()) - 1] + 1.0) / 1.2
