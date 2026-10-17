extends Skill
## Sonic Slash (1502, Gladiator): rush forward faster than sound, cutting
## the enemies along the line (up to the level's target count). Invulnerable
## for the rush.

const RUSH_TIME := 0.16
const WIDTH := 34.0
const COLOR := Color(0.75, 0.95, 1.0)

var _from := Vector2.ZERO
var _hit: Array[Enemy] = []


func _init() -> void:
	duration = 0.34
	anim = "weapon_crit"
	anim_frames = [3, 7]
	dash_cancel_at = 0.24
	invulnerable = true


func start() -> void:
	_from = player.global_position
	player.weapon.swing(aim, deg_to_rad(160.0), aim.x >= 0.0, 0.0, RUSH_TIME)
	Audio.play("snd_p_603_ht.wav", -4.0)
	Ring.spawn(room.ground_fx, _from, 30.0, 0.25, Color(COLOR, 0.8))


func movement(t: float) -> Vector2:
	return Combat.screen(aim).normalized() * (param("range", 120.0) / RUSH_TIME) if t < RUSH_TIME else Vector2.ZERO


func update(t: float, _delta: float) -> void:
	if t > RUSH_TIME + 0.05:
		return
	# Everything between the start and where Buffalo is now.
	var g_from := Combat.ground(_from)
	var g_now := Combat.ground(player.global_position)
	for e in room.enemies:
		if not e.is_hittable() or e in _hit or _hit.size() >= int(param("targets", 5)):
			continue
		var g := Combat.ground(e.global_position)
		var along := (g - g_from).dot((g_now - g_from).normalized()) if g_now != g_from else 0.0
		var closest := g_from.lerp(g_now, clampf(along / maxf((g_now - g_from).length(), 1.0), 0.0, 1.0))
		if g.distance_to(closest) <= WIDTH + e.body_radius:
			_hit.append(e)
			hit(e, damage(), 180.0)
			Sparks.burst(room, e.global_position + Vector2(0, -20), COLOR, 12, 160.0)
			feedback(0.04, 4.0)
	if once(t, RUSH_TIME, "trail"):
		Slash.spawn(room, player.global_position + Vector2(0, -14), {"radius": 70.0, "arc": deg_to_rad(160.0),
			"dir": aim, "clockwise": aim.x >= 0.0, "sweep_time": 0.08, "life": 0.25, "width": 18.0, "color": COLOR})
