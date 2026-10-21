extends Skill
## Bolt spells: Mana Arrow (2001, Dragon's basic attack), Dark Lance (2208)
## and Razor Gale (2126). A projectile flies at the enemy nearest the aim
## within range and hits it. Arrow Rush (2007) makes Mana Arrow loose more
## arrows at once, each extra one at its own share of the damage.

const AIM_ARC := deg_to_rad(60.0)


func _init() -> void:
	duration = 0.22
	anim = "attack"
	dash_cancel_at = 0.05


func start() -> void:
	if card.id == &"mana_arrow":
		_mana_arrows()
		return
	var reach := param("range", 200.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var arrows := 1
	var extra_share := 1.0
	if skill_mod("arrows") > 0.0:  # Arrow Rush
		arrows = int(skill_mod("arrows"))
		extra_share = skill_mod("extra_share") / 100.0
	var others: Array[Enemy] = closest_in_circle(foe.global_position, 120.0, arrows) if foe else ([] as Array[Enemy])
	for i in arrows:
		var orb := MagicOrb.new()
		orb.room = room
		orb.color = color()
		orb.range_left = reach
		orb.speed = 560.0 if card.id != &"razor_gale" else 480.0
		var spread := (i - (arrows - 1) / 2.0) * 0.18
		orb.direction = Combat.screen(aim.rotated(spread)).normalized()
		# Extra arrows spread over the enemies around the first target.
		orb.target = others[i % others.size()] if others.size() > 0 else null
		var share := 1.0 if i == 0 else extra_share
		orb.on_hit = func(e: Enemy) -> void:
			if e:
				hit(e, damage(share), 70.0, false)
		room.add_child(orb)
		orb.global_position = player.global_position + Combat.screen(aim) * 14.0
		if card.id == &"mana_arrow":
			# The original Mana Arrow: its arrow sprite with its afterimage.
			orb.sprite = "magic_arrow"
			orb.trail_sprite = "magic_arrow_jan_sang"
		elif has_effect("fl"):
			orb.quiet = true
			effect("fl", orb.global_position, {"follow": orb})
	Audio.play("snd_skl_common_ki.wav", -10.0)


## Mana Arrow as the original flies it (MagicFlight): the arrows appear
## one by one beside you over 0.3 s (Arrow Rush's count), spin, then each
## rushes at the target after a random wait of its own, so they land in quick
## succession. Extra arrows spread over the enemies around the first target.
func _mana_arrows() -> void:
	var reach := param("range", 200.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var arrows := 1
	var extra_share := 1.0
	if skill_mod("arrows") > 0.0:  # Arrow Rush
		arrows = int(skill_mod("arrows"))
		extra_share = skill_mod("extra_share") / 100.0
	var others: Array[Enemy] = closest_in_circle(foe.global_position, 120.0, arrows) if foe else ([] as Array[Enemy])
	var miss_at := player.global_position + Combat.screen(aim) * reach
	var left := [arrows]
	linger()  # the arrows land after the cast is over
	for i in arrows:
		var f := MagicFlight.new()
		f.room = room
		f.caster = player
		f.target = others[i % others.size()] if others.size() > 0 else null
		f.target_point = f.target.global_position if f.target else miss_at
		f.appear = 0.3 / arrows * i
		var share := 1.0 if i == 0 else extra_share
		f.on_appear = func() -> void:
			card.play("launch", -10.0)
		f.on_hit = func(e: Enemy) -> void:
			if e and is_instance_valid(room):
				# Each arrow plays the original impact (hit() shows it once a cast).
				effect("ht", e.global_position, {"follow": e})
				_effect_hit.append(e)
				hit(e, damage(share), 70.0, false)
			left[0] -= 1
			if left[0] <= 0:
				release()
		room.add_child(f)
