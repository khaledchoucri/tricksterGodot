extends Talent
## Shield of Heaven (2218): a barrier of its value % of your MA takes hits first; once
## broken it comes back after its Cooldown. The barrier is Run.barrier (the HUD shows it).


func tick(player: Player, _delta: float) -> void:
	if Run.barrier <= 0 and player.now() >= Run.barrier_back_at:
		Run.barrier = roundi(Run.stat("MA") * value() / 100.0)


func absorb(player: Player, amount: int) -> int:
	if Run.barrier <= 0:
		return amount
	var absorbed := mini(Run.barrier, amount)
	Run.barrier -= absorbed
	Ring.spawn(player.room.ground_fx, player.global_position, 30.0, 0.25, Color(1.0, 0.95, 0.6, 0.9))
	if Run.barrier <= 0:
		Run.barrier_back_at = player.now() + row("cooldown")
		Events.text_shown.emit(player.global_position + Vector2(0, -70), "Barrier broken", Color(1.0, 0.95, 0.6))
	return amount - absorbed
