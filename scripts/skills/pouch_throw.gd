extends Skill
## Pouch of Pain (3105, Explorer): a heavy pouch lobbed at the cursor bursts
## on everything around where it lands. Poison Pouch (3305) poisons what it
## hits: its % of the damage again over its seconds.

const FLIGHT := 0.45


func _init() -> void:
	duration = 0.4
	anim = "throw"
	dash_cancel_at = 0.2


func start() -> void:
	var spot := target_spot()
	var from := player.global_position
	var radius := param("radius", 100.0) * 0.8
	var amount := damage()
	effect("fl", from)
	linger()
	var pouch := ThrownItem.new()
	pouch.room = room
	pouch.target_point = spot
	room.add_child(pouch)
	pouch.global_position = from + Combat.screen(aim) * 12.0
	pouch.on_hit = func(_e: Enemy) -> void:
		if is_instance_valid(room):
			_burst(spot, radius, amount)
		release()


func _burst(spot: Vector2, radius: float, amount: float) -> void:
	var poison := Run.card_value(&"poison_pouch")
	var seconds := Run.card(&"poison_pouch").param("seconds", Run.card_level(&"poison_pouch")) if poison > 0.0 else 0.0
	effect("ht", spot)
	for e in enemies_in_circle(spot, radius):
		_effect_hit.append(e)
		var fx := {}
		if poison > 0.0 and seconds > 0.0:
			fx = {"burn": amount * poison / 100.0 / seconds, "burn_for": seconds}
		hit(e, amount, 120.0, true, fx, spot)
	Events.shake_requested.emit(3.0)
