extends Skill
## Spells centred on the caster: Wind Blade (2111), Gravity Crush (2210),
## Radiant Strike (2214), Staff of Thunder (2302) and Raging Storm (2305).
## They hit the enemies nearest you within the radius, up to the target
## count. Table rows: radius, targets.

const SHRINK := 0.7


func _init() -> void:
	duration = 0.4
	anim = "cast"
	dash_cancel_at = 0.15


func start() -> void:
	var radius := param("radius", 110.0) * SHRINK
	var c := color()
	if not has_effect("ap") and not has_effect("ht"):
		Ring.spawn(room.ground_fx, player.global_position, radius, 0.45, Color(c, 0.95))
		Ring.spawn(room.ground_fx, player.global_position, radius * 0.6, 0.35, Color(1, 1, 1, 0.7))
		Sparks.burst(room, player.global_position + Vector2(0, -20), c, 26, 240.0, 0.45, 3.0)
	var landed := false
	for e in closest_in_circle(player.global_position, radius, int(param("targets", 99))):
		if card.element == "Elec" and not has_effect("ht"):
			Bolt.strike(room, e.global_position)
		hit(e, damage(), 200.0 if card.id != &"gravity_crush" else -120.0)
		landed = true
	feedback(0.06 if landed else 0.0, 5.0)
