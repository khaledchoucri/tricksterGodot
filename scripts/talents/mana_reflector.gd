extends Talent
## Mana Reflector (4008): turns its share of a magic hit back on the caster (the share it
## takes off is its magic_damage_cut% mod).


func retaliate(player: Player, attacker: Enemy, amount: int, magic: bool) -> void:
	if not magic:
		return
	var share := value() / 100.0
	var reflected := amount * share / maxf(1.0 - share, 0.01)
	if reflected >= 1.0:
		attacker.take_hit(roundi(reflected), Combat.ground(attacker.global_position - player.global_position).normalized(), 0.0, false)
