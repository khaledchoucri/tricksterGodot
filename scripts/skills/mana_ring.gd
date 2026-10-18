extends Skill
## Mana Ring (2008, Sheep's basic attack): three rings fly to the enemy
## nearest the aim and burst around it; the fragments hit the enemies close
## by as well. Its power is shared between the three bursts, so a monster
## caught in all three takes it all. Mana Ring Booster (2012) adds power.

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
	var power := damage() + Run.card_value(&"mana_ring_booster") * Run.skill_mult(card)
	for i in 3:
		var offset := Combat.screen(Vector2.from_angle(TAU * i / 3.0 + randf() * 0.5) * radius * 0.45)
		var spot := center + offset
		var orb := MagicOrb.new()
		orb.room = room
		orb.color = Color(0.65, 0.85, 1.0)
		orb.radius = 7.0
		orb.speed = 460.0
		orb.range_left = player.global_position.distance_to(spot)
		orb.direction = (spot - player.global_position).normalized()
		orb.on_hit = func(_e: Enemy) -> void:
			_burst(orb.global_position, radius, power / 3.0)
		room.add_child(orb)
		orb.global_position = player.global_position + Combat.screen(aim.rotated((i - 1) * 0.5)) * 16.0
	Audio.play("snd_skl_common_ki.wav", -10.0)


func _burst(at: Vector2, radius: float, amount: float) -> void:
	Ring.spawn(room.ground_fx, at, radius, 0.3, Color(0.65, 0.85, 1.0, 0.9))
	for e in enemies_in_circle(at, radius):
		hit(e, amount, 60.0, false, {}, at)
