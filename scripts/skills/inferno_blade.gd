extends Skill
## Inferno Blade (1208): throws the sword spinning; it burns and cuts on the
## way out and back.


func _init() -> void:
	duration = 0.3
	anim = "throw"
	anim_frames = [3, 7]
	dash_cancel_at = 0.12


func update(t: float, _delta: float) -> void:
	if not once(t, 0.1):
		return
	var blade := ThrownBlade.new()
	blade.texture = player.weapon.texture
	blade.thrower = player
	blade.direction = Combat.screen(aim).normalized()
	blade.distance = 200.0 + 10.0 * level
	blade.room = room
	var burn := 4.0 + 2.0 * level
	blade.on_hit = func(e: Enemy) -> void:
		hit(e, damage(), 60.0, false, {"burn": burn})
		Audio.play("snd_p_208_ht.wav", -10.0, 0.1)
	player.weapon.lend()
	blade.returned.connect(player.weapon.give_back)
	blade.position = player.global_position  # before entering the tree: it starts from here
	room.add_child(blade)
	Audio.play("weapon001.wav", -4.0)
