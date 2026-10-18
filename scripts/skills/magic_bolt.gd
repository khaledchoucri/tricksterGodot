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
	var reach := param("range", 200.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var arrows := 1
	var extra_share := 1.0
	if card.id == &"mana_arrow" and Run.card_level(&"arrow_rush") > 0:
		arrows = int(Run.card_value(&"arrow_rush"))
		extra_share = Run.card(&"arrow_rush").param("ratio", Run.card_level(&"arrow_rush")) / 100.0
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
