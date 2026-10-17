extends Skill
## Shockwave (1001): one blow with everything behind it, knocking nearby
## enemies down. Faint (Knight) and Guard Break (Boxer) ride on it.

const RADIUS := 95.0


func _init() -> void:
	duration = 0.5
	anim = "cast"
	dash_cancel_at = 0.32


func update(t: float, _delta: float) -> void:
	if not once(t, 0.26):
		return
	Ring.spawn(room.ground_fx, player.global_position, RADIUS)
	Ring.spawn(room.ground_fx, player.global_position, RADIUS * 0.6, 0.25)
	Sparks.burst(room, player.global_position, Color(0.9, 0.85, 0.7), 18, 180.0, 0.45, 3.0, 150.0)
	Audio.play("eff_energy.wav", -4.0)
	var landed := false
	for e in enemies_in_circle(player.global_position, RADIUS):
		hit(e, damage(), 340.0, true, _riders())
		landed = true
	feedback(0.08 if landed else 0.0, 6.0)


## Faint and Guard Break: each hit has their chance to apply.
func _riders() -> Dictionary:
	var fx := {}
	if Run.card_level(&"faint") > 0 and randf() * 100.0 < Run.card_value(&"faint"):
		fx.stun = Run.card(&"faint").param("seconds", 1)
	if Run.card_level(&"guard_break") > 0 and randf() * 100.0 < Run.card_value(&"guard_break"):
		fx.debuffs = {"guard": [1.0, Run.card(&"guard_break").param("seconds", 1)]}
	return fx
