extends Skill
## Shooting Spree (3203, Inventor) and Berserk (3501, Scientist): a burst of
## shots at up to MonNum random enemies around you, one each in quick
## succession (the client's ESAMeleeShot and ESAReckless pick them at random).
## They don't need the gun loaded and don't reload it.
## Like basic gunfire, cover blocks target selection and each subsequent shot.

const GAP := 0.07


func _init() -> void:
	duration = 0.45
	anim = "attack_gun"
	dash_cancel_at = 0.25


func start() -> void:
	var foes: Array[Enemy] = []
	for enemy: Enemy in enemies_in_circle(player.global_position, param("radius", 160.0) * 0.8):
		if room.line_clear(player.global_position, enemy.global_position):
			foes.append(enemy)
	Run.shuffle(foes)
	foes = foes.slice(0, maxi(int(param("targets", 2)), 1))
	if foes.is_empty():
		Audio.play("weapon_gun_shot.wav", -6.0)
		return
	var amount := damage()
	linger()
	for e in foes:
		if not alive():
			break
		if is_instance_valid(e) and e.is_hittable() and room.line_clear(player.global_position, e.global_position):
			Tracer.spawn(room, player.global_position + Vector2(0, -26), e.global_position + Vector2(0, -22))
			Audio.play("weapon_gun_shot.wav", -6.0)
			Cake.play(room, "gun_taget", e.global_position, {"follow": e})
			hit(e, amount, 40.0, false, {"gun": true}, player.global_position)
		if not await wait_for(GAP):
			break
	release()
