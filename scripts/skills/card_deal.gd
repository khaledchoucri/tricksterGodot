extends Skill
## The Gambler's dealt hands: a card for each of the enemies around you.
##  - Full House (4501): up to five enemies, AP + 8 HV + 8 LK (ESAFullHouse
##    0x6dcb30 on the server). As the client plays it (ESAFullHouse
##    0x49b1b0, 0x49af00; ESAFullHouseHit 0x49b940, 0x49b6e0): a shining ray
##    on you ("ap"), then a flying card to each target ("fl", after 300 ms),
##    where the hand shows ("ke", C_601_full house_apply) before it goes off
##    ("ht"); a bad hand turns some of it back on you ("fail").
##  - Four of a Kind (4505): four cards for four enemies, only with four
##    around you (ESAFourCardDo 0x4c2960): "four_card" on you, and the four
##    suits (spades, clubs, hearts, diamonds: its "ke" list, one a target)
##    over them before the cards strike.

const COLOR := Color(1.0, 0.75, 0.9)
## When the cards leave your hand. Ours: the client waits 300 ms; a little
## less here, where the cast doesn't lock you in place as long.
const DEAL_AT := 0.2
## How long a target's hand shows before it goes off. Ours: the client holds
## Full House's for up to a second (0x49b6e0) and Four of a Kind's 500 ms
## (0x4c2d20), timed by the server; here it's a beat to read the hand.
const SHOW := 0.3
## Full House: the share of cards that come up wrong, and how much of that
## card's damage you take (the original's odds aren't in the client; ours).
const BAD_HAND := 0.2
const BAD_SHARE := 0.25
## Four of a Kind's count (its name; the table's KillNum is 4 at every level).
const FOUR := 4

var _pending := 0  # hands dealt that haven't gone off yet; the cast lingers until they have


static func cast_block(card: CardData, level: int, player: Player) -> String:
	if card.id != &"four_of_a_kind":
		return ""
	var n := 0
	for e in player.room.enemies:
		if e.is_hittable() and Combat.in_circle(player.global_position, e.global_position, card.param("radius", level, 160.0), e.body_radius):
			n += 1
	return "" if n >= FOUR else "Needs four enemies"


func _init() -> void:
	duration = 0.45
	anim = "cast"
	dash_cancel_at = 0.25


func update(t: float, _delta: float) -> void:
	if not once(t, DEAL_AT):
		return
	var radius := param("radius", 160.0)
	var most := FOUR if card.id == &"four_of_a_kind" else int(param("targets", 5))
	Ring.spawn(room.ground_fx, player.global_position, radius, 0.3, Color(COLOR, 0.85))
	var foes := closest_in_circle(player.global_position, radius, most)
	_pending = foes.size()
	if _pending > 0:
		linger()
	for i in foes.size():
		_deal(foes[i], i)
	feedback(0.04, 3.0)


## Deals the `index`-th card to `e`: it flies there when the card has a
## flying effect, shows the hand, then strikes.
func _deal(e: Enemy, index: int) -> void:
	var flying: Array = card.effects.get("fl", [])
	if not flying.is_empty():
		var item := ThrownItem.new()
		item.room = room
		item.target = e
		item.target_point = e.global_position
		item.cake = String(flying[0])
		item.on_hit = func(_e: Enemy) -> void:
			_show_hand(e, index)
		room.add_child(item)
		item.global_position = player.global_position + Combat.screen(Combat.ground(e.global_position - player.global_position).normalized()) * 12.0
	else:
		_show_hand(e, index)


func _show_hand(e: Enemy, index: int) -> void:
	if not is_instance_valid(e) or not e.is_hittable() or not is_instance_valid(room):
		_done_hand()
		return
	var hands: Array = card.effects.get("ke", [])
	if not hands.is_empty():
		Cake.play(room, String(hands[index % hands.size()]), e.global_position, {"follow": e, "hold": SHOW})
	card.play("ke", -10.0)
	if await wait_for(SHOW) and is_instance_valid(e) and e.is_hittable():
		_strike(e)
	_done_hand()


func _done_hand() -> void:
	_pending -= 1
	if _pending <= 0:
		release()


func _strike(e: Enemy) -> void:
	if card.id == &"full_house" and Run.rng.randf() < BAD_HAND:
		var back := roundi(damage() * BAD_SHARE)
		Run.take_damage(mini(back, Run.hp - 1))  # never fatal
		Events.text_shown.emit(player.global_position + Vector2(0, -70), "Bad hand", Color(1.0, 0.5, 0.5))
		effect("fail", e.global_position, {"follow": e})
		card.play("fail", -8.0)
		return
	hit(e, damage(), 80.0, true)
