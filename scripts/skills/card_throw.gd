extends Skill
## The Charm line's throws at the enemy you aim at:
##  - Card Strike (4201): an Empty Card flicked with the wrist; it splashes
##    those within its Radius, less the further they are (the server's
##    ESACardThrow: x (1 - distance / Radius)).
##  - One Pair (4204): two cards at one enemy; Lady Luck (4210) throws
##    between its minimum and maximum, each card adding its share.
##  - Galder Thrower (4002), Fist Full of Galders (4109, several throws) and
##    Furious Galder Throw (4209, a rolled handful): Galder spent from the
##    run's purse, striking through any defence (the server passes no DP).
## No cards are used up (the user's no-ammunition rule); Galder is.

const AIM_ARC := deg_to_rad(60.0)
const EMPTY_CARD := 20400
const GALDERS := 200
const GAP := 0.12
## Furious Galder Throw's handful (the server's 0x73df00): Galder and the
## chance in 100 of each.
const FURIOUS := [[1, 15], [200, 10], [300, 10], [400, 10], [500, 20], [600, 15], [700, 10], [800, 5], [1000, 5]]

var _galder := false


func _init() -> void:
	duration = 0.32
	anim = "throw"
	dash_cancel_at = 0.14


func start() -> void:
	_galder = card.id in [&"galder_thrower", &"fist_full_of_galders", &"furious_galder_throw"]
	var reach := param("range", 160.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var throws := 1
	var amount := damage()
	match card.id:
		&"fist_full_of_galders":
			throws = int(param("count", 2))
		&"one_pair":
			var cards := 2
			if Run.card_level(&"lady_luck") > 0:
				var lady := Run.card(&"lady_luck")
				var lvl := Run.card_level(&"lady_luck")
				cards = Run.rng.randi_range(int(lady.param("min", lvl)), int(Run.card_value(&"lady_luck")))
			throws = cards
			amount = amount / 2.0  # the pair's damage, a card's share each
		&"furious_galder_throw":
			var roll := _roll()
			amount *= roll
			Events.text_shown.emit(player.global_position + Vector2(0, -70), "%d G!" % roll, Color(1.0, 0.85, 0.35))
	if throws > 1:
		duration = 0.32 + GAP * (throws - 1)
	linger()
	for i in throws:
		if i > 0 and not await wait_for(GAP):
			release()
			return
		if _galder:
			Audio.play("etc_money.wav", -6.0)
		_throw(foe, reach, amount)
	release()


func _throw(foe: Enemy, reach: float, amount: float) -> void:
	if not is_instance_valid(foe) or not foe.is_hittable():
		foe = nearest_in_wedge(aim, reach, AIM_ARC)
	var item := ThrownItem.new()
	item.room = room
	item.target = foe
	item.target_point = foe.global_position if foe else player.global_position + Combat.screen(aim) * reach
	var path := "res://original_assets/icons/items/%d.png" % (GALDERS if _galder else EMPTY_CARD)
	item.icon = load(path) if ResourceLoader.exists(path) else null
	linger()
	item.on_hit = func(e: Enemy) -> void:
		if e and is_instance_valid(room):
			_land(e, amount)
		release()
	room.add_child(item)
	item.global_position = player.global_position + Combat.screen(aim) * 12.0
	card.play("ap", -8.0)


func _land(e: Enemy, amount: float) -> void:
	var fx := {"pierce": true} if _galder else {}
	hit(e, amount, 50.0, false, fx)
	if card.id == &"card_strike":
		var radius := param("radius", 12.0)
		for other in enemies_in_circle(e.global_position, radius + 20.0):
			if other == e:
				continue
			var d := Combat.ground(other.global_position - e.global_position).length()
			var share := clampf(1.0 - d / maxf(radius + 20.0, 1.0), 0.0, 1.0)
			if share > 0.05:
				hit(other, amount * share, 40.0, false)
	if _galder:
		Sparks.burst(room, e.global_position + Vector2(0, -24), Color(1.0, 0.85, 0.35), 8, 140.0)


## A Furious handful's Galder, as the server rolls it.
func _roll() -> int:
	var r := Run.rng.randi() % 100
	for row: Array in FURIOUS:
		r -= int(row[1])
		if r < 0:
			return int(row[0])
	return 1000
