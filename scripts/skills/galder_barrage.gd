extends Skill
## Galder Barrage (4102, Entertainer; Echoes lend it too): Galder thrown in
## three directions toward the cursor, each volley bursting over its Radius
## (the server's ESAMultiGellderHit: Galder x Ratio, no DP). The Galder is
## paid from the run's purse by the caster; it scales with HV.

const SPREAD := deg_to_rad(28.0)
const COLOR := Color(1.0, 0.85, 0.35)


func _init() -> void:
	duration = 0.5
	anim = "throw"
	dash_cancel_at = 0.25


func start() -> void:
	var spot := target_spot(170.0)
	var to := spot - player.global_position
	var radius := param("radius", 60.0)
	Audio.play("etc_money.wav", -2.0)
	linger()
	for i in 3:
		var at := player.global_position + to.rotated(SPREAD * (i - 1))
		if not room.is_walkable(at):
			at = room.nearest_reachable(at)
		var coin := ThrownItem.new()
		coin.room = room
		coin.target_point = at
		var path := "res://original_assets/icons/items/200.png"
		coin.icon = load(path) if ResourceLoader.exists(path) else null
		coin.on_hit = func(_e: Enemy) -> void:
			if is_instance_valid(room):
				_burst(at, radius)
			if i == 2:
				release()
		room.add_child(coin)
		coin.global_position = player.global_position + Combat.screen(aim) * 12.0


func _burst(at: Vector2, radius: float) -> void:
	Sparks.burst(room, at + Vector2(0, -24), COLOR, 10, 160.0)
	Ring.spawn(room.ground_fx, at, radius, 0.25, Color(COLOR, 0.8))
	for e in enemies_in_circle(at, radius):
		hit(e, damage(), 60.0, false, {"pierce": true})
	Audio.play("etc_money.wav", -10.0)
	feedback(0.02, 1.5)
