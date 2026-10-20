extends Skill
## Shuriken Master (3007, Fox's basic attack) and Poison Assault (3306): throw
## a hidden weapon at the enemy nearest the aim, as the client's
## ESAWeaponThrow (0x473690) throws it, flying for 300 ms (ThrownItem) and
## landing with throw_hit_drow. No item is used up (the user's rule); the
## flight shows a Big Needle, or a Shuriken from the Explorer on. Poison
## Assault only works from hiding, poisons, and pulls you out of it.

const AIM_ARC := deg_to_rad(60.0)
const NEEDLE := 11404
const SHURIKEN := 12015


func _init() -> void:
	duration = 0.3
	anim = "throw"
	dash_cancel_at = 0.12


func start() -> void:
	var from_hiding := card.id == &"poison_assault"
	if from_hiding and not Run.hidden:
		return
	if from_hiding:
		Run.hidden = false
	var reach := param("range", 200.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var item := ThrownItem.new()
	item.room = room
	item.target = foe
	item.target_point = foe.global_position if foe else player.global_position + Combat.screen(aim) * reach
	var path := "res://original_assets/icons/items/%d.png" % (SHURIKEN if Run.job.tier >= 2 else NEEDLE)
	item.icon = load(path) if ResourceLoader.exists(path) else null
	var amount := damage()
	var seconds := param("seconds", 0.0)
	linger()
	item.on_hit = func(e: Enemy) -> void:
		if e and is_instance_valid(room):
			Cake.play(room, "hit drow", e.global_position, {"follow": e})
			Audio.play("skill_throw_hit_dorw.wav", -8.0)
			var fx := {}
			if from_hiding and seconds > 0.0:
				fx = {"burn": amount * 0.1, "burn_for": seconds}  # the poison keeps hurting
			hit(e, amount, 50.0, false, fx)
		release()
	room.add_child(item)
	item.global_position = player.global_position + Combat.screen(aim) * 12.0
	card.play("ap", -8.0)
