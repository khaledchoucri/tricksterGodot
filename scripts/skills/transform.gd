extends Skill
## The Charm line's self skills:
##  (Evolution and Metamorphosis are talents here: Run.deck.add_card makes them
##  the form, with its stat changes in Run._form_stats().)
##  - Beast's Instinct (4305): in Evolution, the beast's full power for its
##    Seconds, with no skills and an MP drain.
##  - Flux Capacitor (4208): burns a share of max HP into MP.


func _init() -> void:
	duration = 0.5
	anim = "charge"
	dash_cancel_at = 0.4


func start() -> void:
	match card.id:
		&"beasts_instinct":
			player.start_instinct(param("seconds", 20.0))
		&"flux_capacitor":
			var burn := roundi(Run.max_hp * param("hp", 10.0) / 100.0)
			burn = mini(burn, Run.hp - 1)
			if burn > 0:
				Run.take_damage(burn)
				var gain := roundi(burn * card.value_at(level) / 100.0)
				Run.gain_mp(gain)
				Events.damage_shown.emit(player.global_position + Vector2(0, -70), gain, Color(0.5, 0.7, 1.0), false)
