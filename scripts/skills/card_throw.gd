extends Skill
## The Charm line's throws at the enemy you aim at:
##  - Card Strike (4201): a card flicked with the wrist; it splashes those
##    within its Radius, less the further they are (the server's
##    ESACardThrow: x (1 - distance / Radius)).
##  - One Pair (4204): its cards leave together in a tight fan centred on the
##    enemy you aim at, each striking the first enemy on its line for its
##    share of the pair's damage; Lady Luck (4210) throws between its minimum
##    and maximum, each card adding its share.
##  - Galder Thrower (4002), Fist Full of Galders (4109, several throws) and
##    Furious Galder Throw (4209, a rolled handful): Galder spent from the
##    run's purse, striking through any defence (the server passes no DP).
## Cards fly as the client's own flying card (the card's "fl" effect,
## eft_skl_c_301_sut: ESACardThrow 0x47efc0, ESAOnePair 0x48b820); Galder as
## its item icon. No cards are used up (the user's no-ammunition rule);
## Galder is.

const AIM_ARC := deg_to_rad(60.0)
const EMPTY_CARD := 20400
const GALDERS := 200
const GAP := 0.12
## One Pair's fan: each card past the first opens it by CONE_STEP, up to
## CONE_MAX across (6 cards, Lady Luck's most). Deviation (user, 2026-10-22):
## a tight cone of about 30 degrees at full Lady Luck. The client fans the
## cards wider and only for show, all of them landing on the one target
## (ESAOnePair's flight 0x489ee0: 20 degrees x 1, 1.3 and 1.6 to each side,
## and a straight middle card when the count is odd).
const CONE_STEP := deg_to_rad(6.0)
const CONE_MAX := deg_to_rad(30.0)
## Ours: how wide a fanned card's line is when it looks for the first enemy
## it crosses (a card is about 23 px wide).
const CARD_LINE := 16.0
## Furious Galder Throw's handful (the server's 0x73df00): Galder and the
## chance in 100 of each.
const FURIOUS := [[1, 15], [200, 10], [300, 10], [400, 10], [500, 20], [600, 15], [700, 10], [800, 5], [1000, 5]]

var _galder := false


func _init() -> void:
	duration = 0.32
	anim = "throw"
	dash_cancel_at = 0.14


## The fan's angles for `cards` cards, from one side to the other: CONE_STEP
## apart, no wider than CONE_MAX in all.
static func fan_angles(cards: int) -> Array[float]:
	var out: Array[float] = []
	var spread := minf(CONE_STEP * (cards - 1), CONE_MAX)
	for i in cards:
		out.append(0.0 if cards < 2 else lerpf(-spread / 2.0, spread / 2.0, float(i) / (cards - 1)))
	return out


func start() -> void:
	_galder = card.id in [&"galder_thrower", &"fist_full_of_galders", &"furious_galder_throw"]
	var reach := param("range", 160.0)
	var foe := nearest_in_wedge(aim, reach, AIM_ARC)
	var throws := 1
	var amount := damage()
	match card.id:
		&"one_pair":
			_fan(foe, reach, amount / 2.0)  # the pair's damage, a card's share each
			return
		&"fist_full_of_galders":
			throws = int(param("count", 2))
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
		card.play("ap", -8.0)
		if not is_instance_valid(foe) or not foe.is_hittable():
			foe = nearest_in_wedge(aim, reach, AIM_ARC)
		_throw(foe, foe.global_position if foe else player.global_position + Combat.screen(aim) * reach, amount)
	release()


## One Pair: two cards, or Lady Luck's draw, thrown together in a fan around
## the line to `foe` (or straight ahead); each takes the first enemy its line
## crosses within reach, or falls at the end of it.
func _fan(foe: Enemy, reach: float, share: float) -> void:
	var cards := 2
	if skill_mod("cards_max") > 0.0:  # Lady Luck deals more cards
		cards = Run.rng.randi_range(int(skill_mod("cards_min")), int(skill_mod("cards_max")))
	var centre := Combat.ground(foe.global_position - player.global_position).normalized() if foe else aim
	card.play("ap", -8.0)
	var at := player.global_position
	for a: float in fan_angles(cards):
		var dir := centre.rotated(a)
		var struck := _first_on_line(dir, reach)
		# A card keeps to its line: it lands where the line crosses the enemy.
		var along := Combat.ground(struck.global_position - at).dot(dir) if struck else reach
		_throw(struck, at + Combat.screen(dir) * along, share, false)


## The nearest enemy whose body a card's line from the caster crosses.
func _first_on_line(dir: Vector2, reach: float) -> Enemy:
	var best: Enemy = null
	var at := player.global_position
	for e: Enemy in room.enemies:
		if e.is_hittable() and Combat.in_lane(at, e.global_position, dir, reach, CARD_LINE, e.body_radius):
			if best == null or e.global_position.distance_squared_to(at) < best.global_position.distance_squared_to(at):
				best = e
	return best


func _throw(foe: Enemy, to: Vector2, amount: float, homing := true) -> void:
	var item := ThrownItem.new()
	item.room = room
	item.target = foe
	item.target_point = to
	item.homing = homing
	var flying: Array = card.effects.get("fl", [])
	item.cake = "" if _galder or flying.is_empty() else String(flying[0])
	var path := Assets.item_icon(GALDERS if _galder else EMPTY_CARD)
	item.icon = load(path) if ResourceLoader.exists(path) else null
	linger()
	item.on_hit = func(e: Enemy) -> void:
		if e and is_instance_valid(room):
			_land(e, amount)
		release()
	room.add_child(item)
	item.global_position = player.global_position + Combat.screen(Combat.ground(to - player.global_position).normalized()) * 12.0


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
