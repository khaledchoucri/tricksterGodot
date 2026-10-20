extends Skill
## Chain of Knives (3110, Explorer): knives (the table's Count, 2 to 4) at
## one enemy in quick succession, as the client's ESAChainThrow throws them
## (Trickster.bin 0x4b4ba0): one every 150 ms, each landing two steps
## (300 ms) after it leaves, with "hit drow". The damage is shared.

const AIM_ARC := deg_to_rad(60.0)
const GAP := 0.15
const NEEDLE := 11404
const SHURIKEN := 12015


func _init() -> void:
	duration = 0.45
	anim = "throw"
	dash_cancel_at = 0.2


func start() -> void:
	var foe := nearest_in_wedge(aim, param("range", 200.0), AIM_ARC)
	if foe == null:
		return
	var count := maxi(int(param("count", 2)), 1)
	var share := damage() / count
	var path := "res://original_assets/icons/items/%d.png" % (SHURIKEN if Run.job.tier >= 2 else NEEDLE)
	var icon: Texture2D = load(path) if ResourceLoader.exists(path) else null
	linger()
	var left := [count]
	for i in count:
		if i > 0 and not await wait_for(GAP):
			break
		var item := ThrownItem.new()
		item.room = room
		item.target = foe
		item.target_point = foe.global_position if is_instance_valid(foe) else player.global_position
		item.icon = icon
		item.on_hit = func(e: Enemy) -> void:
			if e and is_instance_valid(room):
				Cake.play(room, "hit drow", e.global_position, {"follow": e})
				Audio.play("skill_throw_hit_dorw.wav", -8.0)
				hit(e, share, 30.0, false)
			left[0] -= 1
			if left[0] <= 0:
				release()
		room.add_child(item)
		item.global_position = player.global_position + Combat.screen(aim) * 12.0
	if left[0] > 0 and not alive():
		release()
