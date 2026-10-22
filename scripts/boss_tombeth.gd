class_name BossTombeth
extends Boss
## Tombeth, the Caballa Relics boss in the Trident Maze (scenes/boss_tombeth.tscn). His
## BossMonsterparamEx row (2072): four bars (LifeCnt 3); Power Blow (4001) on every bar,
## Mana Reflector (4008) and Magic Meltdown (4005) from his second (SkillLeftLife 2), Sturdy
## Shield (4007) and Final Blow (4012) from his third; summons (Chimu, Naranjo) from his
## second (SummonLeftLife 2); M Cure from his second bar, fast on his last (HealLeftLife).
##
## The fight, bar by bar:
##  1-2. Sturdy Shield spins round him: every hit on him is cut. He Power Blows up close.
##     From his second bar he raises Mana Reflector (spells hurt him less and part comes back
##     to you), casts Magic Meltdown (your MA down) and calls Chimu.
##  3-4. At half his HP he rages: the shield falls and his defences drop, he moves and swings
##     faster, Power Blows and Final Blows come quick, and he leaps and slams down, bringing
##     rocks down from the ceiling in an X across where you stand, each marked on the ground
##     first.
## Deviation (user, 2026-10-22): Mana Reflector lasts 10 s on a 30 s cooldown (lv8 holds 34 s);
## Sturdy Shield guards him before he rages and falls when he does (the row casts it from his
## third bar); the rage at half HP and its slam are the user's.
## Ours: the telegraphs, the shares, cooldowns within his row's SkillTimes, the X slam.
##
## Tune keys (BossData.tune), with their defaults below: blow_every, final_every,
## reflect_every, reflect_for, reflect_share, meltdown_every, shield_cut, rage_speed,
## rage_windup, rage_cooldown, rage_defence, slam_every, slam_arm, slam_step, slam_mult.

## Power Blow (ESAction_Strike lv4 Ratio 1.5, SkillTime_0 4000 ms): a telegraphed wedge.
const BLOW_EVERY := 4.0
const BLOW_RADIUS := 110.0
const BLOW_ARC := 1.6
const BLOW_WINDUP := 0.6
const BLOW_MULT := 1.5
## Final Blow (ESAction_StrikeOfSoul lv8 Ratio 1.85): a slow, huge blow all around him.
const FINAL_EVERY := 7.0
const FINAL_RADIUS := 95.0
const FINAL_WINDUP := 1.2
const FINAL_MULT := 1.85
## Mana Reflector (ESAction_Magic_Reflect lv8 Ratio 0.34): this share of a spell's damage
## comes back to you, and he takes that much less of it.
const REFLECT_EVERY := 30.0
const REFLECT_FOR := 10.0
const REFLECT_SHARE := 0.34
## Magic Meltdown (ESAction_Sleepy_Voice lv6): MA -30% for 22 s, landing 70% of the time,
## in a ring around him. Ours: every 12 s, its radius and wind-up.
const MELTDOWN_EVERY := 12.0
const MELTDOWN_RADIUS := 150.0
const MELTDOWN_WINDUP := 0.9
const MELTDOWN_CUT := 30.0
const MELTDOWN_FOR := 22.0
const MELTDOWN_CHANCE := 0.7
## Sturdy Shield (ESAction_StaticShield lv6: DP +20%). Ours: halves every hit on him while it
## spins (the user's "high defences": +20% DP alone is a few % here, and the bots at the end of
## chunk 1 broke his first two bars in seconds at 30%).
const SHIELD_CUT := 0.5
## The rage at half HP. Ours: speed and wind-up factors, cooldowns shortened to this share,
## and his DP and MD kept at this share.
const RAGE_SPEED := 1.3
const RAGE_WINDUP := 0.75
const RAGE_COOLDOWN := 0.5
const RAGE_DEFENCE := 0.5
## The leap and slam: a ring around where he lands, then rocks fall on an X centred where you
## stood, `SLAM_ARM` on each arm `SLAM_STEP` apart, each marked `ROCK_WARN` before it lands,
## the centre first and then outward. Ours.
const SLAM_EVERY := 10.0
const SLAM_LEAP := 0.55
const SLAM_RADIUS := 90.0
const SLAM_MULT := 1.2
const SLAM_ARM := 3
const SLAM_STEP := 52.0
const ROCK_RADIUS := 30.0
const ROCK_WARN := 0.9
const ROCK_STAGGER := 0.18
const ROCK_MULT := 0.8
## How high he leaps (screen pixels). Ours.
const LEAP_HEIGHT := 70.0

var enraged := false
var reflect_until := 0.0
var reflect_ready_at := 0.0
var _blow_at := 0.0
var _final_at := 0.0
var _meltdown_at := 0.0
var _slam_at := 0.0
var _shield_aura: Aura
var _reflect_aura: Aura
var _chimu_called := false


func _ready() -> void:
	super._ready()
	var t := now() + INTRO_FOR
	_blow_at = t + 1.0
	_meltdown_at = t + 4.0
	_sturdy_shield()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	if is_instance_valid(_reflect_aura) and now() >= reflect_until:
		_reflect_aura.end()


## Whether Sturdy Shield spins round him (until he rages).
func shielded() -> bool:
	return not enraged


func _on_phase(lives: int) -> void:
	if lives <= 2 and not _chimu_called:
		_chimu_called = true
		Events.boss_spoke.emit(boss.line_summon)
		summon(&"minion", 2)
		reflect_ready_at = now()
	if lives <= 1 and not enraged:
		_enrage()


## Half his HP gone: the shield falls, his defences drop, and he speeds up.
func _enrage() -> void:
	enraged = true
	Events.boss_spoke.emit(boss.line_rage)
	if is_instance_valid(_shield_aura):
		_shield_aura.end()
	var keep := num("rage_defence", RAGE_DEFENCE)
	stats["DP"] = roundi(float(stats.get("DP", 0)) * keep)
	stats["MD"] = roundi(float(stats.get("MD", 0)) * keep)
	var speed := num("rage_speed", RAGE_SPEED)
	walk_speed *= speed
	run_speed *= speed
	_base_speeds *= speed
	attack.windup *= num("rage_windup", RAGE_WINDUP)
	attack.recover *= num("rage_windup", RAGE_WINDUP)
	summon(&"brute", 2)
	_slam_at = now() + 2.0
	_final_at = now()
	sprite.self_modulate = Color(1.25, 0.85, 0.85)
	Events.text_shown.emit(global_position + Vector2(0, -90), "Enraged", Color(1.0, 0.45, 0.35))


## Cooldowns run at RAGE_COOLDOWN of their length once he rages.
func _cooldown(seconds: float) -> float:
	return seconds * (num("rage_cooldown", RAGE_COOLDOWN) if enraged else 1.0)


func _windup(seconds: float) -> float:
	return seconds * (num("rage_windup", RAGE_WINDUP) if enraged else 1.0)


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if lives_left <= 2 and not enraged and now() >= reflect_ready_at:
		_mana_reflector()
	if lives_left <= 2 and now() >= _meltdown_at and dist < MELTDOWN_RADIUS + 60.0 and room.request_attack_token(self):
		_magic_meltdown()
		return
	if enraged and now() >= _slam_at and room.request_attack_token(self):
		_leap_slam()
		return
	if enraged and now() >= _final_at and dist < FINAL_RADIUS + 40.0 and room.request_attack_token(self):
		_final_blow()
		return
	if now() >= _blow_at and dist < BLOW_RADIUS + 20.0 and room.request_attack_token(self):
		_power_blow()
		return
	super._state_chase()


# ---------------------------------------------------------------- blows

## Power Blow: a telegraphed wedge in front of him.
func _power_blow() -> void:
	_blow_at = now() + _cooldown(num("blow_every", BLOW_EVERY))
	var windup := _windup(BLOW_WINDUP)
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.RECOVER, windup + 0.5)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(_attack_dir), windup + 0.4, true)
	var warn := Telegraph.make("wedge", windup, {"dir": _attack_dir, "radius": BLOW_RADIUS, "arc": BLOW_ARC})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(windup, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Events.shake_requested.emit(3.0)
	Audio.play("dmg_normal_c.wav", -4.0)
	if not player.is_invulnerable() and Combat.in_wedge(global_position, player.global_position, _attack_dir,
			BLOW_RADIUS, BLOW_ARC, 10.0):
		player.take_hit(roundi(damage * BLOW_MULT), Combat.ground(player.global_position - global_position).normalized(),
			240.0, false, accuracy(), self)


## Final Blow: a long wind-up, then a huge blow all around him.
func _final_blow() -> void:
	_final_at = now() + _cooldown(num("final_every", FINAL_EVERY))
	var windup := _windup(FINAL_WINDUP)
	_enter(State.RECOVER, windup + 0.6)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(Combat.ground(player.global_position - global_position)), windup + 0.5, true)
	var warn := Telegraph.make("circle", windup, {"radius": FINAL_RADIUS})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(windup, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Ring.spawn(room.ground_fx, global_position, FINAL_RADIUS, 0.5, Color("c9a1ff"))
	Events.shake_requested.emit(6.0)
	Audio.play("dmg_normal_c.wav", -2.0)
	if not player.is_invulnerable() and Combat.in_circle(global_position, player.global_position, FINAL_RADIUS, 10.0):
		player.take_hit(roundi(damage * FINAL_MULT), Combat.ground(player.global_position - global_position).normalized(),
			320.0, false, accuracy(), self)


## The leap: he jumps, slams down where he stood, and rocks fall on an X centred on you.
func _leap_slam() -> void:
	_slam_at = now() + num("slam_every", SLAM_EVERY)
	_enter(State.RECOVER, SLAM_LEAP + 0.8)
	velocity = Vector2.ZERO
	var centre := player.global_position
	var land := Telegraph.make("circle", SLAM_LEAP, {"radius": SLAM_RADIUS})
	room.add_ground_fx(land, global_position)
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", sprite.position.y - LEAP_HEIGHT, SLAM_LEAP * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", sprite.position.y, SLAM_LEAP * 0.5).set_ease(Tween.EASE_IN)
	_fall_rocks(centre)
	await get_tree().create_timer(SLAM_LEAP, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(land):
		land.trigger()
	Ring.spawn(room.ground_fx, global_position, SLAM_RADIUS, 0.5, Color(0.95, 0.8, 0.6, 0.9))
	Events.shake_requested.emit(8.0)
	Audio.play("dmg_normal_c.wav", -2.0)
	if not player.is_invulnerable() and Combat.in_circle(global_position, player.global_position, SLAM_RADIUS, 10.0):
		player.take_hit(roundi(damage * num("slam_mult", SLAM_MULT)), Combat.ground(player.global_position - global_position).normalized(),
			300.0, false, accuracy(), self)


## The X: the impact points, each with its delay (centre first, then outward).
func x_pattern(centre: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"at": centre, "delay": 0.0}]
	var arm := int(num("slam_arm", SLAM_ARM))
	var step := num("slam_step", SLAM_STEP)
	for i in range(1, arm + 1):
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			# The X lies on the floor: its arms are the ground's diagonals, squashed on screen.
			out.append({"at": centre + Combat.screen(d.normalized() * step * i), "delay": ROCK_STAGGER * i})
	return out


func _fall_rocks(centre: Vector2) -> void:
	for p: Dictionary in x_pattern(centre):
		_rock(p.at, SLAM_LEAP + float(p.delay))


func _rock(at: Vector2, after: float) -> void:
	if after > ROCK_WARN:
		await get_tree().create_timer(after - ROCK_WARN, false).timeout
	if state == State.DEAD or not is_inside_tree():
		return
	var warn := Telegraph.make("circle", ROCK_WARN, {"radius": ROCK_RADIUS})
	room.add_ground_fx(warn, at)
	FallingRock.drop(room.world, at, ROCK_WARN)
	await get_tree().create_timer(ROCK_WARN, false).timeout
	if state == State.DEAD or not is_inside_tree() or not is_instance_valid(player):
		return
	if is_instance_valid(warn):
		warn.trigger()
	Sparks.burst(room, at, Color(0.75, 0.65, 0.55), 12, 110.0, 0.4, 3.0)
	if not player.is_invulnerable() and Combat.in_circle(at, player.global_position, ROCK_RADIUS, 10.0):
		player.take_hit(roundi(damage * ROCK_MULT), Combat.ground(player.global_position - at).normalized(), 180.0, false,
			accuracy(), self)


# ---------------------------------------------------------------- his guards

## Sturdy Shield: spins round him until he rages, cutting every hit.
func _sturdy_shield() -> void:
	_shield_aura = Aura.attach(self, body_radius + 10.0, Color(0.95, 0.85, 0.5, 0.85))


## Mana Reflector: for a while spells hurt him less, and the difference comes back to you.
func _mana_reflector() -> void:
	reflect_ready_at = now() + num("reflect_every", REFLECT_EVERY)
	reflect_until = now() + num("reflect_for", REFLECT_FOR)
	if is_instance_valid(_reflect_aura):
		_reflect_aura.queue_free()
	_reflect_aura = Aura.attach(self, body_radius + 22.0, Color(0.55, 0.75, 1.0, 0.9))
	Events.text_shown.emit(global_position + Vector2(0, -80), "Mana Reflector", Color(0.6, 0.8, 1.0))


func reflecting() -> bool:
	return now() < reflect_until


## Magic Meltdown: a ring bursts from him; caught in it, your MA drops for a while.
func _magic_meltdown() -> void:
	_meltdown_at = now() + _cooldown(num("meltdown_every", MELTDOWN_EVERY))
	_enter(State.RECOVER, MELTDOWN_WINDUP + 0.3)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(Combat.ground(player.global_position - global_position)), MELTDOWN_WINDUP, true)
	var warn := Telegraph.make("circle", MELTDOWN_WINDUP, {"radius": MELTDOWN_RADIUS, "color": Color(0.7, 0.4, 0.95)})
	room.add_ground_fx(warn, global_position)
	room.release_attack_token(self)
	await get_tree().create_timer(MELTDOWN_WINDUP, false).timeout
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Ring.spawn(room.ground_fx, global_position, MELTDOWN_RADIUS, 0.5, Color(0.75, 0.45, 1.0, 0.9))
	if not player.is_invulnerable() and Combat.in_circle(global_position, player.global_position, MELTDOWN_RADIUS, 10.0) \
			and Run.rng.randf() < MELTDOWN_CHANCE:
		Run.apply_debuff("MA", MELTDOWN_CUT, MELTDOWN_FOR, "Magic Meltdown")
		Events.text_shown.emit(player.global_position + Vector2(0, -80), "Magic Meltdown: MA -%d%%" % roundi(MELTDOWN_CUT),
			Color(0.8, 0.55, 1.0))


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	if not is_hittable():
		return
	if shielded():
		amount = maxi(1, roundi(amount * (1.0 - num("shield_cut", SHIELD_CUT))))
	if reflecting() and fx.get("magic", false):
		var back := roundi(amount * num("reflect_share", REFLECT_SHARE))
		amount = maxi(1, amount - back)
		if back > 0 and is_instance_valid(player) and not player.is_invulnerable():
			player.take_hit(back, Combat.ground(player.global_position - global_position).normalized(), 0.0, true, 9999, self)
	super.take_hit(amount, dir, knockback, heavy, fx)
