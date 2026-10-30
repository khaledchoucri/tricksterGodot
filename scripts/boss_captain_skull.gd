class_name BossCaptainSkull
extends Boss
## Captain Skull, the Oops Wharf boss on the Wharf Field (scenes/boss_captain_skull.tscn). His
## BossMonsterparamEx row (2213): four bars (LifeCnt 3); Armor Breaker (1005) on every bar
## (SkillLeftLife 8), Burning Rave (1004) from his first (3), Shockvibe (1006) from his second
## (2), Bull's Eye (1003) and Shockwave (1001) from his third (1); summons (Crow, Quiem, Black
## Foe, Master Foe: 3-9 every 15 s, 40 in all) from his second (SummonLeftLife 2); M Cure from
## his third, fast on his last (HealLeftLife). A Fighter's cards, swung by a pirate.
##
## The fight, bar by bar:
##  1. He Armor Breaks up close (your DP down) and Burning Raves: a dash along a marked lane,
##     then two punches.
##  2. Shockvibe rings out from him (your AC down: your hits graze) and his crew comes aboard.
##  3. "To the Pain.": Bull's Eye (his AC up) and a Shockwave every 2 s, a marked lane of
##     ground he punches down; M Cure every 6 s.
##  4. M Cure every 1.5 s: a skill or a finisher breaks the cast off.
## Ours: the telegraphs and their shapes, the dash, the heal's cast and what breaks it.
##
## Tune keys (BossData.tune), with their defaults below: breaker_every, rave_every, vibe_every,
## wave_every, wave_mult, rave_mult.

## Armor Breaker (ESAction_Unshield lv2: DP -16% for 18 s, landing 54% of the time;
## SkillTime_1 6000 ms). Ours: a swing in a wedge, one hit.
const BREAKER_EVERY := 6.0
const BREAKER_RADIUS := 100.0
const BREAKER_ARC := 1.4
const BREAKER_WINDUP := 0.55
const BREAKER_CUT := 16.0
const BREAKER_FOR := 18.0
const BREAKER_CHANCE := 0.54
## Burning Rave (ESAction_Combo_Punch lv4: two hits of Ratio 1.4, range 80; SkillTime_0 4000 ms).
## Ours: he dashes up to RAVE_DASH along a lane marked RAVE_WINDUP, then punches twice.
const RAVE_EVERY := 4.0
const RAVE_DASH := 200.0
const RAVE_WIDTH := 44.0
const RAVE_WINDUP := 0.5
const RAVE_RADIUS := 90.0
const RAVE_ARC := 1.6
const RAVE_GAP := 0.25
const RAVE_MULT := 1.4
## Seconds his dash takes. Ours.
const RAVE_DASH_FOR := 0.15
## The step his dash checks the floor in (px). Ours.
const DASH_STEP := 8.0
## Shockvibe (ESAction ACDown lv6: AC -30% for 24 s, landing 70% of the time; SkillTime_2
## 5000 ms). Ours: a ring around him, its radius and wind-up.
const VIBE_EVERY := 5.0
const VIBE_RADIUS := 150.0
const VIBE_WINDUP := 0.9
const VIBE_CUT := 30.0
const VIBE_FOR := 24.0
const VIBE_CHANCE := 0.7
## Bull's Eye (lv6: AC +25% for 85 s, recast every 10 s, so it never lapses).
const BULLS_EYE := 0.25
## Shockwave (ESAction_Steel_Punch lv10 Ratio 2.65; SkillTime_4 2000 ms). Ours: a lane of
## ground in front of him, marked WAVE_WINDUP.
const WAVE_EVERY := 2.0
const WAVE_LENGTH := 240.0
const WAVE_WIDTH := 56.0
const WAVE_WINDUP := 0.6
const WAVE_MULT := 2.65

var raging := false
var _breaker_at := 0.0
var _rave_at := 0.0
var _vibe_at := 0.0
var _wave_at := 0.0
var _dash_vel := Vector2.ZERO
var _dash_until := 0.0


func _ready() -> void:
	super._ready()
	var t := now() + INTRO_FOR
	_rave_at = t + 1.0
	_breaker_at = t + 2.5


## His dash moves him as a body (Enemy's `_pull`), so walls, the room's edge and his crew stop him.
func _physics_process(delta: float) -> void:
	if now() < _dash_until and state != State.DEAD:
		_pull = _dash_vel
	super._physics_process(delta)


func _on_phase(lives: int) -> void:
	if lives <= 2 and _vibe_at == 0.0:
		_vibe_at = now() + 1.0
	if lives <= 1 and not raging:
		_rage()


## His third bar: "To the Pain.", Bull's Eye and the Shockwaves.
func _rage() -> void:
	raging = true
	Events.boss_spoke.emit(boss.line_rage)
	stats["AC"] = roundi(float(stats.get("AC", 50)) * (1.0 + BULLS_EYE))
	_wave_at = now() + 0.5
	sprite.self_modulate = Color(1.2, 0.9, 0.85)
	Events.text_shown.emit(global_position + Vector2(0, -90), "Bull's Eye", Color(1.0, 0.75, 0.4))


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if raging and now() >= _wave_at and dist < WAVE_LENGTH and room.request_attack_token(self):
		_shockwave()
		return
	if lives_left <= 2 and _vibe_at > 0.0 and now() >= _vibe_at and dist < VIBE_RADIUS + 40.0 \
			and room.request_attack_token(self):
		_shockvibe()
		return
	if now() >= _breaker_at and dist < BREAKER_RADIUS + 20.0 and room.request_attack_token(self):
		_armor_breaker()
		return
	if now() >= _rave_at and dist < RAVE_DASH + RAVE_RADIUS and room.request_attack_token(self):
		_burning_rave()
		return
	super._state_chase()


## Whether the player stands in a hit of his that lands now.
func _hits_player(inside: bool) -> bool:
	return inside and not player.is_invulnerable()


func _strike(mult: float, push: float) -> void:
	player.take_hit(roundi(damage * mult), Combat.ground(player.global_position - global_position).normalized(),
		push, false, accuracy(), self)


## Armor Breaker: a swing in front of him; struck, your DP drops for a while.
func _armor_breaker() -> void:
	_breaker_at = now() + num("breaker_every", BREAKER_EVERY)
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.RECOVER, BREAKER_WINDUP + 0.4)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(_attack_dir), BREAKER_WINDUP + 0.3, true)
	var warn := Telegraph.make("wedge", BREAKER_WINDUP, {"dir": _attack_dir, "radius": BREAKER_RADIUS, "arc": BREAKER_ARC})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(BREAKER_WINDUP, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Audio.play("dmg_normal_c.wav", -4.0)
	if _hits_player(Combat.in_wedge(global_position, player.global_position, _attack_dir, BREAKER_RADIUS, BREAKER_ARC, 10.0)):
		_strike(1.0, 200.0)
		if Run.rng.randf() < BREAKER_CHANCE:
			Run.apply_debuff("DP", BREAKER_CUT, BREAKER_FOR, "Armor Breaker")
			Events.text_shown.emit(player.global_position + Vector2(0, -80), "Armor Breaker: DP -%d%%" % roundi(BREAKER_CUT),
				Color(1.0, 0.7, 0.4))


## Burning Rave: a dash along a marked lane, then two punches where it ends.
func _burning_rave() -> void:
	_rave_at = now() + num("rave_every", RAVE_EVERY)
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	var reach := _open_reach(minf(RAVE_DASH, maxf(0.0, Combat.ground(player.global_position - global_position).length() - body_radius)))
	_enter(State.RECOVER, RAVE_WINDUP + RAVE_DASH_FOR + RAVE_GAP + 0.5)
	velocity = Vector2.ZERO
	var warn := Telegraph.make("lane", RAVE_WINDUP, {"dir": _attack_dir, "length": reach + RAVE_RADIUS, "width": RAVE_WIDTH})
	room.add_ground_fx(warn, global_position)
	sprite.play_action("attack", Combat.screen(_attack_dir), RAVE_WINDUP + 0.6, true)
	await get_tree().create_timer(RAVE_WINDUP, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	_dash_vel = Combat.screen(_attack_dir * reach / RAVE_DASH_FOR)
	_dash_until = now() + RAVE_DASH_FOR
	await get_tree().create_timer(RAVE_DASH_FOR, false).timeout
	var mult := num("rave_mult", RAVE_MULT)
	for i in 2:
		if broken_off():
			return
		Audio.play("dmg_normal_c.wav", -5.0)
		Sparks.burst(room, global_position + Combat.screen(_attack_dir * 40.0) + Vector2(0, -20), Color(1.0, 0.55, 0.25), 10, 90.0, 0.3)
		if _hits_player(Combat.in_wedge(global_position, player.global_position, _attack_dir, RAVE_RADIUS, RAVE_ARC, 10.0)):
			_strike(mult, 160.0)
		if i == 0:
			await get_tree().create_timer(RAVE_GAP, false).timeout


## How far along `_attack_dir` he can dash, up to `most`, before the floor ends.
func _open_reach(most: float) -> float:
	var d := 0.0
	while d + DASH_STEP <= most and room.is_walkable(global_position + Combat.screen(_attack_dir * (d + DASH_STEP))):
		d += DASH_STEP
	return d


## Shockvibe: a ring bursts from him; caught in it, your AC drops and your hits graze.
func _shockvibe() -> void:
	_vibe_at = now() + num("vibe_every", VIBE_EVERY)
	_enter(State.RECOVER, VIBE_WINDUP + 0.3)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(Combat.ground(player.global_position - global_position)), VIBE_WINDUP, true)
	var warn := Telegraph.make("circle", VIBE_WINDUP, {"radius": VIBE_RADIUS, "color": Color(0.95, 0.75, 0.3)})
	room.add_ground_fx(warn, global_position)
	room.release_attack_token(self)
	await get_tree().create_timer(VIBE_WINDUP, false).timeout
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Ring.spawn(room.ground_fx, global_position, VIBE_RADIUS, 0.5, Color(1.0, 0.8, 0.35, 0.9))
	if _hits_player(Combat.in_circle(global_position, player.global_position, VIBE_RADIUS, 10.0)) \
			and Run.rng.randf() < VIBE_CHANCE:
		Run.apply_debuff("AC", VIBE_CUT, VIBE_FOR, "Shockvibe")
		Events.text_shown.emit(player.global_position + Vector2(0, -80), "Shockvibe: AC -%d%%" % roundi(VIBE_CUT),
			Color(1.0, 0.85, 0.45))


## Shockwave: he punches the ground and it breaks along a marked lane in front of him.
func _shockwave() -> void:
	_wave_at = now() + num("wave_every", WAVE_EVERY)
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.RECOVER, WAVE_WINDUP + 0.3)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(_attack_dir), WAVE_WINDUP + 0.2, true)
	var warn := Telegraph.make("lane", WAVE_WINDUP, {"dir": _attack_dir, "length": WAVE_LENGTH, "width": WAVE_WIDTH})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(WAVE_WINDUP, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Events.shake_requested.emit(5.0)
	Audio.play("dmg_normal_c.wav", -2.0)
	for i in 4:
		Sparks.burst(room, global_position + Combat.screen(_attack_dir * WAVE_LENGTH * (i + 1) / 4.0), Color(0.85, 0.75, 0.6),
			8, 90.0, 0.35, 3.0)
	if _hits_player(Combat.in_lane(global_position, player.global_position, _attack_dir, WAVE_LENGTH, WAVE_WIDTH, 10.0)):
		_strike(num("wave_mult", WAVE_MULT), 260.0)
