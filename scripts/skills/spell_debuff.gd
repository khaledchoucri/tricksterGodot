extends Skill
## Spells that hinder rather than hurt (or only a little): Mana Web (2010,
## slower), Rust (2011, weaker hits), Botulism Cloud (2125, attacks take
## twice as long), Dark Distractor (2215, slower), Icey Shackles (2127,
## frozen: no moving, acting or being hurt), Hinder Snare (2201, enemies
## around you held until you move or are hit) and Dimensional Rift (2316,
## swallowed, then thrown out hurt). Table rows: range, radius, seconds,
## targets.

const SHRINK := 0.6
## Which debuff each spell applies (Enemy.debuffs).
const DEBUFF := {&"mana_web": "dx", &"rust": "ap", &"botulism_cloud": "delay", &"dark_distractor": "slow",
	&"icey_shackles": "frozen", &"hinder_snare": "hold", &"dimensional_rift": "frozen"}

var _held: Array[Enemy] = []


func _init() -> void:
	duration = 0.3
	anim = "cast"
	dash_cancel_at = 0.1


func start() -> void:
	var around_me := param("self") > 0.0
	var spot := player.global_position if around_me else target_spot()
	var radius := param("radius", 50.0) * (SHRINK if around_me or card.id == &"dimensional_rift" else 1.0)
	var key: String = DEBUFF.get(card.id, "slow")
	var seconds := param("seconds", 5.0)
	var c := color()
	Ring.spawn(room.ground_fx, spot, radius, 0.5, Color(c, 0.9))
	Sparks.burst(room, spot + Vector2(0, -12), c, 16, 140.0, 0.5, 2.5)
	for e in closest_in_circle(spot, radius, int(param("targets", 99))):
		if card.id == &"icey_shackles":
			hit(e, damage(), 0.0, false, {}, spot)  # the damage lands before the ice sets
		e.apply_debuff(key, param("value", 1.0) if key in ["dx", "ap", "slow"] else 1.0, seconds)
		e.sprite.modulate = Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, e.sprite.modulate.a)
		_held.append(e)
		effect("ke", e.global_position, {"follow": e, "hold": seconds})
	if card.id == &"dimensional_rift":
		_rift_out(seconds)
	elif card.id == &"hinder_snare":
		_snare(seconds)


## The rift lets go after its time and the swallowed take its damage.
func _rift_out(seconds: float) -> void:
	linger()
	await player.get_tree().create_timer(seconds).timeout
	for e in _held:
		if is_instance_valid(e) and e.is_hittable():
			e.debuffs.erase("frozen")
			hit(e, damage(), 180.0, true)
			Ring.spawn(room.ground_fx, e.global_position, 30.0, 0.3, Color(color(), 0.9))
	release()


## Hinder Snare holds only while the caster stays put and unhurt.
func _snare(seconds: float) -> void:
	linger()
	var from := player.global_position
	var hp := Run.hp
	var until := player.now() + seconds
	while is_instance_valid(player) and player.now() < until:
		await player.get_tree().physics_frame
		if player.global_position.distance_to(from) > 12.0 or Run.hp < hp:
			break
	for e in _held:
		if is_instance_valid(e):
			e.debuffs.erase("hold")
	release()
