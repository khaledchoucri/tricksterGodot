extends Skill
## The Charm line's self skills:
##  - Evolution (4105, the Entertainer) and Metamorphosis (4206, the Card
##    Master): become the beast (trs001, trs002) for the table's Seconds,
##    with its stat changes (Run._form_stats). Needs 60% HP and MP; drains
##    MP; casting it again in the form returns you to normal.
##  - Beast's Instinct (4305): in Evolution, the beast's full power for its
##    Seconds, with no skills; Evolution ends with it.
##  - Flux Capacitor (4208): burns a share of max HP into MP.


func _init() -> void:
	duration = 0.5
	anim = "charge"
	dash_cancel_at = 0.4


func start() -> void:
	match card.id:
		&"evolution", &"metamorphosis":
			if Run.form == card.id:
				player.end_form()
			else:
				player.enter_form(card.id, param("seconds", 50.0))
		&"beasts_instinct":
			player.enter_form(&"evolution", param("seconds", 20.0), true)
		&"flux_capacitor":
			var burn := roundi(Run.max_hp * param("hp", 10.0) / 100.0)
			burn = mini(burn, Run.hp - 1)
			if burn > 0:
				Run.take_damage(burn)
				var gain := roundi(burn * card.value_at(level) / 100.0)
				Run.gain_mp(gain)
				Events.damage_shown.emit(player.global_position + Vector2(0, -70), gain, Color(0.5, 0.7, 1.0), false)
