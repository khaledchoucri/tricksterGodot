extends Skill
## Spells that leave an area on the ground for a while: Tesla Field (2123),
## Phoenix Rising (2124), Scorching Earth (2129), Deadly Fen (2130),
## Whirlwind (2116, fades if you move) and the Soul Master's Gardens and
## Domains (2311-2315, lowering one resistance of the monsters inside).
## Table rows: range, radius, seconds, targets, slow, resist, still.

const SHRINK := 0.6
const TICK := 0.6

## Which resistance each Garden or Domain lowers (the descriptions).
const LOWERS := {&"undines_garden": "Elec", &"raions_space": "Fire", &"salamanders_territory": "Earth",
	&"gnomes_domain": "Wind", &"sylphs_playground": "Water"}

var _field: SpellField
var _from := Vector2.ZERO


func _init() -> void:
	duration = 0.3
	anim = "cast"
	dash_cancel_at = 0.1


func start() -> void:
	_from = player.global_position
	var spot := target_spot()
	if card.id == &"phoenix_rising":
		var foe := nearest_to(spot, 90.0)
		if foe:
			spot = foe.global_position
	_field = SpellField.new()
	_field.room = room
	_field.radius = param("radius", 90.0) * SHRINK
	_field.life = param("seconds", 4.0)
	_field.tick = TICK
	_field.color = color()
	var cap := int(param("targets", 99))
	var lowers: String = LOWERS.get(card.id, "")
	_field.on_tick = func(inside: Array[Enemy]) -> void:
		for e: Enemy in inside.slice(0, cap):
			if lowers != "":
				e.apply_debuff("resist_" + lowers, param("resist"), TICK + 0.1)
				continue
			var fx := {}
			if param("slow") > 0.0:
				fx.debuffs = {"slow": [param("slow"), TICK + 0.3]}
			hit(e, damage(), 0.0, false, fx, _field.global_position)
		card.play("ke", -14.0)
	room.add_child(_field)
	_field.global_position = spot
	if has_effect("ke"):
		_field.quiet = true
		var keep := effect("ke", spot, {"hold": _field.life})
		_end_effect(spot, _field.life, keep)
	if card.id == &"whirlwind":
		var tw := Tornado.new()
		tw.room = room
		tw.direction = Vector2.ZERO
		tw.speed = 0.0
		tw.life = _field.life
		tw.on_hit = func(_e: Enemy) -> void:
			pass
		room.add_child(tw)
		tw.global_position = spot
		_watch_still(tw)


## The original's end effect when the field runs out (or Whirlwind fades).
func _end_effect(spot: Vector2, life: float, keep: Array[Cake]) -> void:
	linger()
	var until := player.now() + life
	while is_instance_valid(_field) and alive() and player.now() < until:
		if not await wait_for():
			break
	for k in keep:
		if is_instance_valid(k):
			k.stop()
	effect("ed", spot)
	release()


## Whirlwind's tornados are hard to control: they fade once the caster moves.
func _watch_still(tw: Node) -> void:
	linger()
	while is_instance_valid(_field) and alive():
		if not await wait_for():
			break
		if player.global_position.distance_to(_from) > 12.0:
			_field.ended = true
			if is_instance_valid(tw):
				tw.queue_free()
			break
	release()
