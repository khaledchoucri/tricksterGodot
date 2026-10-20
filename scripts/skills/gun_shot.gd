extends Skill
## Lion's basic attack: a gun shot as the client's GunAttack (Trickster.bin
## 0x440680) fires it. An instant shot along the aim to the gun's range,
## stopped by walls ("obstacles impossible to penetrate"), striking up to 8
## monsters in its line; gun_taget and etc_gun_hit at each, etc_gun_shot at
## the gun (etc_gun_critical for an overcharged shot), a recoil shake. It
## needs the gun loaded and starts the reload (GunCycle). With Overcharge, a
## shot fired with the power gauge above the gun's zone does x1.2 (the
## server's power shot, 0x59d4a0) times Keen Sense's factor, and shows as a
## critical, as the server reports it. The basic shot never rolls an ordinary
## critical.
##
## Ours: the shot locks on to the enemy you point at (the spells' snap, or
## the nearest within AIM_ASSIST of the aim), so small, quick monsters can be
## hit.

const MAX_TARGETS := 8
const LINE_WIDTH := 24.0  # the shot's half-width on the ground
const POWER_MULT := 1.2
const AIM_ASSIST := deg_to_rad(15.0)


func _init() -> void:
	duration = 0.28
	anim = "attack_gun"
	dash_cancel_at = 0.12


func start() -> void:
	var gun := player.gun
	if not gun.fire():
		return
	var reach := gun.range()
	var dmg := card.value_at(level) * Run.gun_shot_mult()
	fire_line(self, assisted_aim(self, reach), reach, dmg, gun.last_power, {"no_crit": true})


## The aim, turned onto the enemy the player points at: the one nearest the
## cursor (as the spells snap), else the nearest within AIM_ASSIST of the aim.
## Walls must leave it in sight.
static func assisted_aim(s: Skill, reach: float) -> Vector2:
	var from := s.player.global_position
	var best: Enemy = null
	var best_d := INF
	for e in s.room.enemies:
		if not e.is_hittable() or not Combat.in_circle(from, e.global_position, reach) \
				or not s.room.line_clear(from, e.global_position):
			continue
		var d := Combat.ground(e.global_position - s.target).length()
		if d <= TARGET_SNAP and d < best_d:
			best = e
			best_d = d
	if best == null:
		for e in s.enemies_in_wedge(from, s.aim, reach, AIM_ASSIST * 2.0):
			if s.room.line_clear(from, e.global_position) and (best == null
					or e.global_position.distance_squared_to(from) < best.global_position.distance_squared_to(from)):
				best = e
	if best:
		return Combat.ground(best.global_position - from).normalized()
	return s.aim


## Shoots one line from the player along `dir` (ground) up to `reach`: the
## first walls stop it, up to MAX_TARGETS monsters in it are struck in order.
## Shared by the gun skills (gun_skill.gd).
static func fire_line(s: Skill, dir: Vector2, reach: float, amount: float, power: bool, fx := {}) -> int:
	var p := s.player
	p.gun.fired_at = p.now()
	var from := p.global_position
	var to := from + Combat.screen(dir.normalized()) * reach
	# Walls stop the shot where the line is first blocked.
	var steps := 32
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / steps)
		if not s.room.line_clear(from, at):
			to = from.lerp(to, float(i - 1) / steps)
			break
	var length := Combat.ground(to - from).length()
	var hit_list: Array[Enemy] = []
	for e in s.room.enemies:
		if not e.is_hittable():
			continue
		var rel := Combat.ground(e.global_position - from)
		var along := rel.dot(dir.normalized())
		if along < 0.0 or along > length + e.body_radius:
			continue
		if absf(rel.cross(dir.normalized())) <= LINE_WIDTH + e.body_radius:
			hit_list.append(e)
	hit_list.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	hit_list = hit_list.slice(0, MAX_TARGETS)
	Audio.play("weapon_gun_critical.wav" if power else "weapon_gun_shot.wav", -4.0)
	Tracer.spawn(s.room, from + Vector2(0, -26), to + Vector2(0, -22))
	var f := fx.duplicate()
	f.gun = true
	if power:
		amount *= POWER_MULT * (1.0 + Run.power_shot_bonus() / 100.0)
		f.power_shot = true  # shown as a critical; its power-shot factor is the whole bonus
	for e in hit_list:
		Cake.play(s.room, "gun_taget", e.global_position, {"follow": e})
		Audio.play("weapon_gun_hit.wav", -8.0)
		s.hit(e, amount, 40.0, power, f, from)
	Events.shake_requested.emit(3.5 if power else 2.0)
	return hit_list.size()
