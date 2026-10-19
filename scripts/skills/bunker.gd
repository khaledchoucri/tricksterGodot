extends Skill
## Bunker (3505, Scientist): dig in for its seconds. You can't move or make
## regular attacks, the bunker takes the hits (its HP: the card's % of your
## max HP) and ends when they or the time run out. Skills still work.
## Bunker Release (3506) cuts its time by 10 s.


func _init() -> void:
	duration = 0.3
	anim = "cast"
	dash_cancel_at = 0.0


func start() -> void:
	if card.id == &"bunker_release":
		if Run.in_bunker(player.now()):
			Run.bunker_until -= 10.0
		return
	Run.bunker_until = player.now() + param("seconds", 30.0)
	Run.bunker_hp = roundi(Run.max_hp * card.value_at(level) / 100.0)
	Audio.play("snd_s_605_ap.wav", -6.0)
	effect("ap", player.global_position, {"follow": player, "hold": param("seconds", 30.0)})
