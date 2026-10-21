extends Skill
## Mana Ring (2008, Sheep's basic attack): three rings appear beside you,
## then each swoops along its own curve to the enemy nearest the aim and
## bursts around it (the client's RingCake flight, see MagicFlight); the
## fragments hit the enemies close by as well. Its power is shared between
## the three bursts, so a monster caught in all three takes it all. Mana Ring
## Booster (2012) adds power.

const AIM_ARC := deg_to_rad(70.0)
const BURST := 0.45  # each burst's radius, as a share of the original's


func _init() -> void:
	duration = 0.2
	anim = "attack"
	dash_cancel_at = 0.05


func start() -> void:
	var reach := param("range", 200.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var center := foe.global_position if foe else player.global_position + Combat.screen(aim) * reach
	var radius := param("radius", 120.0) * BURST
	var power := damage() + skill_mod("power") * Run.formulas.skill_mult(card)  # Mana Ring Booster
	card.play("ap", -8.0)
	var left := [3]
	linger()  # the rings land after the cast is over
	for i in 3:
		var f := MagicFlight.new()
		f.room = room
		f.caster = player
		f.target = foe
		f.target_point = center
		f.appear = 0.5 / 3.0 * i
		f.fire = 0.5
		f.curve = true
		f.wait_steps = 1
		# The original ring ("magic ring", 70%, spinning at 1000 deg/s) and its
		# mist trail ("magic ring2": yun gi, 40/s, 0.5 s).
		f.sprite = "magic_ring"
		f.sprite_scale = 0.7
		f.sprite_alpha = 232.0 / 255.0
		f.spin = 1000.0
		f.pointed = false
		f.trail = "yun_gi"
		f.trail_speed = 100.0
		f.trail_alpha = 73.0 / 255.0
		f.trail_vary = false
		f.trail_shrink = true
		f.on_appear = func() -> void:
			card.play("launch", -10.0)
		f.on_hit = func(e: Enemy) -> void:
			if is_instance_valid(room):
				_burst(e.global_position if e else f.target_point, radius, power / 3.0)
			left[0] -= 1
			if left[0] <= 0:
				release()
		room.add_child(f)


func _burst(at: Vector2, radius: float, amount: float) -> void:
	var caught := enemies_in_circle(at, radius)
	if has_effect("ht"):
		effect("ht", at)
		_effect_hit.append_array(caught)  # one burst effect, not one per monster
	else:
		Ring.spawn(room.ground_fx, at, radius, 0.3, Color(0.65, 0.85, 1.0, 0.9))
	for e in caught:
		hit(e, amount, 60.0, false, {}, at)
