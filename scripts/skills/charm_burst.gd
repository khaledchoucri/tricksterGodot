extends Skill
## The Charm line's area skills, each with the server's own attack (the
## card's scaling):
##  - Siren Song (4104): your voice, a cone ahead (Angle) up to MonNum
##    enemies; HP x 0.1 + DP x 0.5.
##  - Sharp Scream (4304, beast form): a scream around you, Count enemies.
##  - Impelling Rage (4205) and Power Charging (4502): your force pushes up
##    to five enemies around you back by the Radius (the server's magic
##    formula: MA against MD); Power Charging roots them.
##  - Full House (4501): cards dealt to up to five enemies around you,
##    AP + 8 HV + 8 LK; a card that comes up wrong turns on you.
##  - Mass Destruction (4211): a huge bomb that hurts KillNum enemies around
##    and leaves you with the table's share of your HP.
##  - Four of a Kind (4505): four cards for four enemies, only with four.
##  - [Summon] Card Soldier (4504, beast form): a soldier numbered from
##    MinCard to MaxCard strikes at the cursor, harder the higher its number
##    (the server's x (number / 6 + 0.1)).

const COLOR := Color(1.0, 0.75, 0.9)
## Full House: the share of cards that come up wrong, and how much of that
## card's damage you take (the original's odds aren't in the client; ours).
const BAD_HAND := 0.2
const BAD_SHARE := 0.25


static func cast_block(card: CardData, level: int, player: Player) -> String:
	match card.id:
		&"mass_destruction":
			if Run.hp < Run.max_hp * 0.8:
				return "Needs 80% HP"
		&"four_of_a_kind":
			var n := 0
			for e in player.room.enemies:
				if e.is_hittable() and Combat.in_circle(player.global_position, e.global_position, card.param("radius", level, 160.0), e.body_radius):
					n += 1
			if n < 4:
				return "Needs four enemies"
	return ""


func _init() -> void:
	duration = 0.45
	anim = "cast"
	dash_cancel_at = 0.25


func start() -> void:
	match card.id:
		&"siren_song", &"sharp_scream":
			anim = "attack2"
		&"mass_destruction":
			anim = "charge"
			duration = 0.6


func update(t: float, _delta: float) -> void:
	if not once(t, 0.5 if card.id == &"mass_destruction" else 0.15):
		return
	var at := player.global_position
	match card.id:
		&"siren_song":
			var reach := param("range", 160.0)
			var arc := deg_to_rad(maxf(param("angle", 30.0), 30.0))
			var foes := enemies_in_wedge(at, aim, reach, arc)
			_sort_near(foes, at)
			Slash.spawn(room, at + Vector2(0, -20), {"radius": reach, "arc": arc, "dir": aim, "clockwise": true,
				"sweep_time": 0.12, "life": 0.3, "width": 18.0, "color": COLOR})
			for e in foes.slice(0, int(param("targets", 2))):
				hit(e, damage(), 90.0, true)
		&"sharp_scream":
			_ring(at, param("radius", 140.0))
			for e in closest_in_circle(at, param("radius", 140.0), int(param("targets", 2))):
				hit(e, damage(), 90.0, true)
		&"impelling_rage", &"power_charging":
			var radius := param("radius", 100.0)
			_ring(at, radius)
			var fx := {"stun": param("stun", 0.0)} if card.id == &"power_charging" else {}
			for e in closest_in_circle(at, radius, int(param("targets", 5))):
				hit(e, damage(), 260.0 + radius, true, fx)
		&"full_house":
			var radius := param("radius", 160.0)
			_ring(at, radius)
			for e in closest_in_circle(at, radius, int(param("targets", 5))):
				if Run.rng.randf() < BAD_HAND:
					var back := roundi(damage() * BAD_SHARE)
					Run.take_damage(mini(back, Run.hp - 1))  # never fatal
					Events.text_shown.emit(at + Vector2(0, -70), "Bad hand", Color(1.0, 0.5, 0.5))
				else:
					hit(e, damage(), 80.0, true)
		&"mass_destruction":
			var radius := param("radius", 120.0)
			_ring(at, radius)
			Sparks.burst(room, at + Vector2(0, -20), Color(1.0, 0.6, 0.3), 28, 260.0)
			for e in closest_in_circle(at, radius, int(param("targets", 4))):
				hit(e, damage(), 300.0, true)
			# "You'll be injured the most": left with HpRemainRatio of your HP.
			var left := maxi(1, roundi(Run.max_hp * param("hp_left", 20.0) / 100.0))
			if Run.hp > left:
				Run.take_damage(Run.hp - left)
			feedback(0.1, 9.0)
		&"four_of_a_kind":
			var radius := param("radius", 160.0)
			var foes := closest_in_circle(at, radius, 4)
			_ring(at, radius)
			for e in foes:
				hit(e, damage(), 80.0, true)
		&"card_soldier":
			var spot := target_spot(160.0)
			var number := Run.rng.randi_range(int(param("min", 2)), int(param("max", 5)))
			Events.text_shown.emit(spot + Vector2(0, -60), "Card %d" % number, Color(1.0, 0.85, 0.6))
			effect("ht", spot)
			for e in closest_in_circle(spot, 50.0, 1):
				hit(e, damage(number / 6.0 + 0.1), 120.0, true)
	feedback(0.04, 3.0)


func _ring(at: Vector2, radius: float) -> void:
	Ring.spawn(room.ground_fx, at, radius, 0.3, Color(COLOR, 0.85))


func _sort_near(foes: Array[Enemy], at: Vector2) -> void:
	foes.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
