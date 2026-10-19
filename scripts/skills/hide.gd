extends Skill
## Hide (3301, Thief Master): vanish for its seconds. Monsters lose track of
## you; attacking or casting anything ends it (Sudden Attack and Poison
## Assault strike from it and end it themselves).


func _init() -> void:
	duration = 0.25
	anim = "cast"
	dash_cancel_at = 0.1


func start() -> void:
	Run.hidden = true
	Run.hidden_until = player.now() + param("seconds", 10.0)
	effect("ap", player.global_position, {"follow": player})
