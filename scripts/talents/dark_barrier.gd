extends Talent
## Dark Barrier (2212): turns its Reflect share of a physical hit back on the attacker (its
## dark resistance is a mod).


func retaliate(player: Player, attacker: Enemy, amount: int, magic: bool) -> void:
	if magic:
		return
	var back := amount * row("reflect") / 100.0
	if back >= 1.0:
		attacker.take_hit(roundi(back), Combat.ground(attacker.global_position - player.global_position).normalized(), 0.0, false)
