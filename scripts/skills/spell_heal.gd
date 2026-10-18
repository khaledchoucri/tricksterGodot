extends Skill
## Healing spells: Cure (2005), Catastrophe Heal (2207, more with luck) and
## Heart's Grace (2216). They recover a share of your max HP (the card's
## value, in %).


func _init() -> void:
	duration = 0.3
	anim = "cast"
	dash_cancel_at = 0.1


func start() -> void:
	var share := param("value") / 100.0
	if param("luck") > 0.0:
		share *= 1.0 + Run.stat("LK") / 100.0
	var amount := maxi(1, roundi(Run.max_hp * share))
	Run.heal(amount)
	Events.damage_shown.emit(player.global_position + Vector2(0, -70), amount, Color(0.5, 1.0, 0.6), false)
	if not has_effect("ap"):
		Ring.spawn(room.ground_fx, player.global_position, 40.0, 0.45, Color(0.6, 1.0, 0.7, 0.9))
		Sparks.burst(room, player.global_position + Vector2(0, -30), Color(0.7, 1.0, 0.8), 18, 90.0, 0.6, 2.5, -60.0)
	effect("ht", player.global_position, {"follow": player})
	effect("ed", player.global_position, {"follow": player})
	Audio.play("eff_healing1.wav", -4.0)
