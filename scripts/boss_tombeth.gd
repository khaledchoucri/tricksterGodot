class_name BossTombeth
extends Enemy
## Tombeth, the Caballa Relics boss in the Trident Maze (scenes/boss_tombeth.tscn). From his
## BossMonsterparamEx row (2072): three lives; Power Blow (4001) every 4 s; summons (Chimu,
## Naranjo) from his second life; Mana Reflector (4008) and, on his last life, Sturdy Shield
## (4007) and Final Blow (4012); a heal as he loses a life; and his own speech lines.
## Ours: how each skill plays out (telegraphs, shares, timings within the row's times).
## Left out: Magic Meltdown (4005), which lowers your MA; the player has no debuffs yet.

## Power Blow (SkillTime_0 4000 ms): a wedge strike after a telegraph.
const BLOW_COOLDOWN := 4.0
const BLOW_RADIUS := 110.0
const BLOW_ARC := 1.6
const BLOW_WINDUP := 0.6
## Mana Reflector (SkillTime_1 6000 ms): this share of a spell's damage comes back to you.
const REFLECT_COOLDOWN := 6.0
const REFLECT_FOR := 3.0
const REFLECT_SHARE := 0.3
## Sturdy Shield (SkillTime_3 10000 ms): damage taken is cut by this while it spins.
const SHIELD_COOLDOWN := 10.0
const SHIELD_FOR := 4.0
const SHIELD_CUT := 0.5
## Final Blow (SkillTime_4): a slow, huge blow around him on his last life.
const FINAL_COOLDOWN := 7.0
const FINAL_RADIUS := 95.0
const FINAL_WINDUP := 1.2
const FINAL_MULT := 2.5
## His lives (LifeCnt 3): a life is lost at each of these HP shares.
const LIVES_AT: Array[float] = [0.66, 0.33]
## The heal as a life is lost (HealLeftLife/HealLevel), a share of max HP.
const HEAL_SHARE := 0.08
## His own lines (Speech_0, Speech_1 when summoning, Speech_RChange on his last life).
const LINE_OPEN := "I will show you hell.."
const LINE_SUMMON := "Come out!"
const LINE_RAGE := "KlaAtu Bar.aDa NikTo"

var _lives_lost := 0
var _blow_ready_at := 0.0
var _reflect_ready_at := 0.0
var _reflect_until := 0.0
var _shield_ready_at := 0.0
var _shield_until := 0.0
var _final_ready_at := 0.0


func _ready() -> void:
	super._ready()
	_blow_ready_at = now() + 2.5
	Events.boss_spoke.emit(LINE_OPEN)


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if _lives_lost >= 1 and now() >= _reflect_ready_at:
		_mana_reflector()
	if _lives_lost >= 2 and now() >= _shield_ready_at:
		_sturdy_shield()
	if _lives_lost >= 2 and now() >= _final_ready_at and dist < FINAL_RADIUS + 40.0 and room.request_attack_token(self):
		_final_blow()
		return
	if now() >= _blow_ready_at and dist < BLOW_RADIUS + 20.0 and room.request_attack_token(self):
		_power_blow()
		return
	super._state_chase()


## Power Blow: a telegraphed wedge in front of him.
func _power_blow() -> void:
	_blow_ready_at = now() + BLOW_COOLDOWN
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.RECOVER, BLOW_WINDUP + 0.5)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(_attack_dir), BLOW_WINDUP + 0.4, true)
	var warn := Telegraph.make("wedge", BLOW_WINDUP, {"dir": _attack_dir, "radius": BLOW_RADIUS, "arc": BLOW_ARC})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(BLOW_WINDUP, false, true).timeout
	room.release_attack_token(self)
	if state == State.DEAD or not is_inside_tree() or not is_instance_valid(player):
		return
	if is_instance_valid(warn):
		warn.trigger()
	Events.shake_requested.emit(3.0)
	Audio.play("dmg_normal_c.wav", -4.0)
	if not player.is_invulnerable() and Combat.in_wedge(global_position, player.global_position, _attack_dir,
			BLOW_RADIUS, BLOW_ARC, 10.0):
		player.take_hit(damage, Combat.ground(player.global_position - global_position).normalized(), 240.0, false,
			accuracy(), self)


## Final Blow: a long wind-up, then a huge blow all around him.
func _final_blow() -> void:
	_final_ready_at = now() + FINAL_COOLDOWN
	_enter(State.RECOVER, FINAL_WINDUP + 0.6)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(Combat.ground(player.global_position - global_position)),
		FINAL_WINDUP + 0.5, true)
	var warn := Telegraph.make("circle", FINAL_WINDUP, {"radius": FINAL_RADIUS})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(FINAL_WINDUP, false, true).timeout
	room.release_attack_token(self)
	if state == State.DEAD or not is_inside_tree() or not is_instance_valid(player):
		return
	if is_instance_valid(warn):
		warn.trigger()
	Ring.spawn(room.ground_fx, global_position, FINAL_RADIUS, 0.5, Color("c9a1ff"))
	Events.shake_requested.emit(6.0)
	Audio.play("dmg_normal_c.wav", -2.0)
	if not player.is_invulnerable() and Combat.in_circle(global_position, player.global_position, FINAL_RADIUS, 10.0):
		player.take_hit(roundi(damage * FINAL_MULT), Combat.ground(player.global_position - global_position).normalized(),
			320.0, false, accuracy(), self)


## Mana Reflector: for a while, part of every spell that hurts him comes back.
func _mana_reflector() -> void:
	_reflect_ready_at = now() + REFLECT_COOLDOWN
	_reflect_until = now() + REFLECT_FOR
	Ring.spawn(room.ground_fx, global_position, 44.0, REFLECT_FOR, Color(0.55, 0.75, 1.0, 0.8))


## Sturdy Shield: for a while, he takes less damage.
func _sturdy_shield() -> void:
	_shield_ready_at = now() + SHIELD_COOLDOWN
	_shield_until = now() + SHIELD_FOR
	Ring.spawn(room.ground_fx, global_position, 38.0, SHIELD_FOR, Color(0.95, 0.85, 0.5, 0.8))


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	if now() < _shield_until:
		amount = maxi(1, roundi(amount * (1.0 - SHIELD_CUT)))
	if now() < _reflect_until and fx.get("magic", false) and is_instance_valid(player) and not player.is_invulnerable():
		var back := roundi(amount * REFLECT_SHARE)
		if back > 0:
			player.take_hit(back, Combat.ground(player.global_position - global_position).normalized(), 0.0, true, 9999, self)
	super.take_hit(amount, dir, knockback * 0.2, heavy, fx)
	while _lives_lost < LIVES_AT.size() and hp > 0 and float(hp) / max_hp <= LIVES_AT[_lives_lost]:
		_lose_life()


## A life lost: he heals a little, speaks, and calls his servants.
func _lose_life() -> void:
	_lives_lost += 1
	hp = mini(max_hp, hp + roundi(max_hp * HEAL_SHARE))
	if _lives_lost == 1:
		Events.boss_spoke.emit(LINE_SUMMON)
		room.summon(global_position, &"chimu", 2)
	else:
		Events.boss_spoke.emit(LINE_RAGE)
		room.summon(global_position, &"chimu", 2)
		room.summon(global_position, &"naranjo", 2)
