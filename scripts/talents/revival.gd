extends Talent
## Revival (2221, Priest line): light brings you back from a fatal blow with its value % of
## your max HP, then not again for its Cooldown (Run.revival_ready_at).


func revive() -> bool:
	if Events.time < Run.revival_ready_at:
		return false
	Run.revival_ready_at = Events.time + card.param("cooldown", 1)
	Run.hp = maxi(1, roundi(Run.max_hp * value() / 100.0))
	Events.player_hp_changed.emit()
	return true
