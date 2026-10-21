extends Talent
## Oath of Light (2220): every 10 s, heals its share of your max HP; Sacred Oath (2504)
## adds its own (both declare "oath_of_light.heal%").

const EVERY := 10.0

var _wait := 0.0


func tick(player: Player, delta: float) -> void:
	_wait += delta
	if _wait < EVERY:
		return
	_wait -= EVERY
	var gain := maxi(1, roundi(Run.max_hp * (Run.mod("oath_of_light.heal%") / 100.0)))
	if Run.hp < Run.max_hp:
		Run.heal(gain)
		Events.damage_shown.emit(player.global_position + Vector2(0, -70), gain, Color(0.5, 1.0, 0.6), false)
