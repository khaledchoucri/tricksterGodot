extends Skill
## Ghostly Whisper (2705, Dark Lord): the enemies nearest you are haunted
## and take damage every second, until it runs out or you move or cast
## again. Table rows: radius, seconds, targets.

const SHRINK := 0.7


func _init() -> void:
	duration = 0.3
	anim = "cast"
	dash_cancel_at = 0.1


func start() -> void:
	var foes := closest_in_circle(player.global_position, param("radius", 100.0) * SHRINK * 2.0, int(param("targets", 2)))
	_haunt(foes, param("seconds", 6.0))


func _haunt(foes: Array[Enemy], seconds: float) -> void:
	linger()
	var from := player.global_position
	var casts := _casts()
	for i in int(seconds):
		if not await wait_for(1.0) or player.global_position.distance_to(from) > 12.0 or _casts() != casts:
			break
		for e in foes:
			if is_instance_valid(e) and e.is_hittable():
				hit(e, damage(), 0.0, false, {}, e.global_position)
				Sparks.burst(room, e.global_position + Vector2(0, -30), color(), 8, 60.0, 0.5, 2.0, -40.0)
	release()


## Counts casts: a new one ends the whisper.
func _casts() -> int:
	return int(player.get_meta("casts", 0))
