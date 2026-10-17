extends Skill
## Clinch Release (1110, Boxer): recover at once from whatever holds you. It
## can be cast while staggered by a hit (Player._clinch_release), cancelling
## the stagger and its knockback, with a moment of safety after.


func _init() -> void:
	duration = 0.2
	anim = "guard"
	dash_cancel_at = 0.0
	invulnerable = true


func start() -> void:
	player.knock = Vector2.ZERO
	player.invulnerable_until = maxf(player.invulnerable_until, player.now() + 0.6)
	Ring.spawn(room.ground_fx, player.global_position, 36.0, 0.3, Color(1.0, 1.0, 0.85, 0.9))
	Ring.spawn(room.ground_fx, player.global_position, 22.0, 0.22, Color(1.0, 1.0, 1.0, 0.9))
	Events.text_shown.emit(player.global_position + Vector2(0, -70), "Clinch Release", Color(1.0, 0.95, 0.7))
	Audio.play("eff_energy.wav", -8.0)
