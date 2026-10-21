extends Talent
## Berserker (1203): its rage (damage%, a mod) costs HP and MP while monsters are around,
## DRAIN a second (never fatal).

## Ours: HP and MP lost each second in a fight.
const DRAIN := 1.0

var _drain := 0.0


func tick(player: Player, delta: float) -> void:
	if not player.room or player.room.live_enemies() <= 0:
		return
	_drain += DRAIN * delta
	if _drain >= 1.0:
		var n := int(_drain)
		_drain -= n
		Run.mp = maxi(Run.mp - n, 0)
		if Run.hp > n:
			Run.take_damage(n)
