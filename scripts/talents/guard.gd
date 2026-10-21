extends Talent
## Guard (1107): blocks its value in physical hits outright, one back every Cooldown
## seconds. The blocks are kept in Run.guard_blocks (the HUD shows them).


func tick(player: Player, _delta: float) -> void:
	if Run.guard_blocks >= int(value()):
		Run.guard_back_at = player.now() + row("cooldown")
	elif player.now() >= Run.guard_back_at:
		Run.guard_blocks += 1
		Run.guard_back_at = player.now() + row("cooldown")


func guard(player: Player, magic: bool) -> bool:
	if magic or Run.guard_blocks <= 0:
		return false
	Run.guard_blocks -= 1
	player.invulnerable_until = player.now() + 0.25
	Events.text_shown.emit(player.global_position + Vector2(0, -70), "Guard", Color(0.85, 0.9, 1.0))
	Audio.play("weapon003.wav", -6.0)
	Ring.spawn(player.room.ground_fx, player.global_position, 30.0, 0.25, Color(0.85, 0.9, 1.0, 0.9))
	return true
