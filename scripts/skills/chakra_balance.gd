extends Skill
## Chakra Balance (1506, Gladiator): steadies the body and recovers a share of
## HP every few seconds for a while; taking a hit stops it. The original
## heals 100-800 HP every 2 s for 30 s; here 1-8% of your max HP.


func _init() -> void:
	duration = 0.4
	anim = "cast"
	dash_cancel_at = 0.2


func start() -> void:
	player.start_regen(param("value", 1.0) / 100.0, param("interval", 2.0), param("seconds", 30.0))
	Ring.spawn(room.ground_fx, player.global_position, 40.0, 0.4, Color(0.6, 1.0, 0.7, 0.9))
	Audio.play("eff_healing1.wav", -4.0)
