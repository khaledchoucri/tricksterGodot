extends Skill
## Rain of Knives (3112, Explorer): knives thrown high come down on up to
## KillNum enemies around the cursor, each struck Count times (the client's
## ESAUpThrow: a throwing-knife effect over each, snd_s_212_ht as they land).
## The damage is shared between a target's strikes.

const GAP := 0.12


func _init() -> void:
	duration = 0.5
	anim = "throw"
	dash_cancel_at = 0.25


func start() -> void:
	var spot := target_spot()
	var foes := closest_in_circle(spot, param("radius", 150.0) * 0.6, int(param("targets", 3)))
	if foes.is_empty():
		Cake.play(room, "throwing-knife", spot)
		return
	var strikes := maxi(int(param("count", 3)), 1)
	var share := damage() / strikes
	linger()
	await wait_for(0.25)  # they go up first
	for s in strikes:
		for e in foes:
			if is_instance_valid(e) and e.is_hittable():
				if s == 0:
					Cake.play(room, "throwing-knife", e.global_position, {"follow": e})
				hit(e, share, 20.0, false)
		Audio.play("snd_s_212_ht.wav", -8.0)
		if not await wait_for(GAP):
			break
	release()
