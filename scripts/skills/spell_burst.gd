extends Skill
## Spells that land at the cursor (within range) and burst on what's there:
## Drip Bomb, Mana Storm, Whirlwind Blaze, Incinerate, Summon Boulder, Shard
## of the Glacier, Tornado Blast, Hellfire, Aqua Bomb, Dragon Storm,
## Earthquake, Searing Light, Celestial Strike. Table rows: range, radius,
## targets (cap), chance + freeze (Shard of the Glacier).

const SHRINK := 0.6  # the original's radii, scaled to this game's rooms

var _spot := Vector2.ZERO


func _init() -> void:
	duration = 0.3
	anim = "cast"
	dash_cancel_at = 0.1


func start() -> void:
	_spot = target_spot()
	var c := color()
	var radius := param("radius", 70.0) * SHRINK
	var cap := int(param("targets", 99))
	if has_effect("ht"):
		# The original effect plays once where the spell lands.
		effect("ht", _spot)
		_effect_hit.append_array(closest_in_circle(_spot, radius, cap))
	else:
		Ring.spawn(room.ground_fx, _spot, radius, 0.4, Color(c, 0.95))
		Ring.spawn(room.ground_fx, _spot, radius * 0.55, 0.3, Color(1, 1, 1, 0.8))
		Sparks.burst(room, _spot + Vector2(0, -10), c, 22, 200.0, 0.45, 3.0)
		if card.element == "Elec" or card.element == "Light":
			Bolt.strike(room, _spot)
	var landed := false
	for e in closest_in_circle(_spot, radius, cap):
		var fx := {}
		if param("freeze") > 0.0 and Run.rng.randf() * 100.0 < param("chance"):
			fx.debuffs = {"hold": [1.0, param("freeze")]}
		hit(e, damage(), 140.0, true, fx, _spot)
		landed = true
	feedback(0.05 if landed else 0.0, 4.0)
