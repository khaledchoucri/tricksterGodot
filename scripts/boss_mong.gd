class_name BossMong
extends Boss
## Master Mong, the Coral Beach boss (scenes/boss_mong.tscn), monster 2215 (mon281.nri).
## Deviation (user, 2026-10-22): he fights in the Coral Beach boss room the Golden Mole used, cut from
## map_dg11b (MapInfoEx 152, "Coral Beach - Dark Cave", Mon_Coral_Dungeon2), not on his own map,
## map_fd11g (MapInfoEx 216, the same name: Mon_Coral_Play7, BossMon_Coral_Play7).
## His BossMonsterparamEx row (2215, read by the server's loader at 0x5ddb80) gives:
##  - three lives (LifeCnt 3): one HP pool drawn as three bars (Boss: his 2.9 x hp_mult is three
##    original lives), a life lost as each bar breaks, with the stagger and phase that follow;
##  - M Mana Storm (5104 Lv 7) on every life, Mana Shield (2013 Lv 4) from his second (LeftLife 2),
##    M Mana Ring (5103 Lv 5) and his heal on his last (LeftLife 1, HealLeftLife_0 1);
##  - his two lines (Speech_0 as he appears, Speech_1 as he calls the Thief Mongs), and NotEarthQuake 1:
##    his spells don't shake the screen.
## Deviation (user, 2026-10-22): three Thief Mongs (2189) with him from the start and five more at
## half HP, instead of the row's 3-4 every 20 s from his second life (SummonMin/Max, SummonTime,
## SummonLeftLife 2, 40 in all); his heal is a Cure cast a few times a fight; his spells are Mana
## Shield, Mana Ring and Mana Storm, so Mana Arrow (2001) is left out.
## Deviation (user, 2026-10-22): Thief Mongs steal: a hit that lands takes Galder, given back when
## the thief dies (thief_mong.tres steal_galder; Ours: 12 a hit, about a tenth of its GMax 124).
## A hardened variant (the original's Master Mong M, 2447) can reuse this scene with its own
## EnemyData (HP) and these exported knobs.
## Each spell's numbers are its ESAction / ESAII row at that level. The client draws these monster
## spells with the player's classes (it has no ESAMon class for them: ESAMagicRing, ESAMagicStormHit,
## ESAMagicWall), so they wear our player spells' effects and sounds (the scene's *_look cards).
## Left out: Rust (2011), which lowers your AP (his spells are the user's three), and his field
## tactics (Tactics_Mon281: Arrow Rush, Fire Breath, M Cure), which our monsters don't read; his
## GiveItem rows (Master and level 35-60 gear) are far above Coral Beach's gear levels.

## Reading: a skill row is active while his bars left (bars_left(), counting the one he is on)
## are at most its LeftLife; a row with LeftLife 0 (M Mana Storm) has no gate.
const SHIELD_LIVES := 2  # SkillLeftLife_0
const RING_LIVES := 1    # SkillLeftLife_3
const HEAL_LIVES := 1    # HealLeftLife_0
## Reading: how often a skill is tried is the larger of the row's SkillTime and the spell's CoolTime.
const STORM_EVERY := 5.0   # SkillTime_4 1500 ms, ESAII_Mon_MagicStorm CoolTime 5.0
const SHIELD_EVERY := 10.0 # SkillTime_0 5000 ms, ESAll_MagicWall CoolTime 10.0
const RING_EVERY := 2.0    # SkillTime_3 2000 ms, ESAII_Mon_MagicRing CoolTime 1.5
## Spell powers (each row's Comment), cast times (Delay), reaches (Range) and hit chances
## (ApplyRatio, the hit chance per the server's factory 0x685240).
const STORM_POWER := 1300.0  # ESAction_Mon_MagicStorm Lv 7, Radius 147
const STORM_DELAY := 1.0
const STORM_RANGE := 200.0
const STORM_RADIUS := 147.0
const STORM_APPLY := 0.72
const RING_POWER := 800.0    # ESAction_Mon_MagicRing Lv 5, Radius 120, three rings
const RING_DELAY := 0.3
const RING_RANGE := 240.0
const RING_RADIUS := 120.0
const RING_APPLY := 0.72
const RINGS := 3             # SkillParam2 5103: "makes 3 magic rings"
## Mana Shield (ESAction_MagicWall Lv 4): MD +19% for 115 s.
const SHIELD_MD := 0.19
const SHIELD_FOR := 115.0
## Reading: the original radii scaled as the player's own spells scale them (spell_burst.gd's
## SHRINK for the storm, mana_ring.gd's BURST for each ring).
const STORM_SHRINK := 0.6
const RING_BURST := 0.45
## The server's magic path (0x59c230): power x (MA - 49) / 100. Reading: a spell hits for his
## melee hit times that over his AP, so spells and blows keep the original's proportion.
const MA_FLOOR := 49.0
## Deviation (user, 2026-10-22): his Thief Mongs, three at the start and five at half HP.
const SUMMON_ID := &"thief_mong"
const HALF_HP := 0.5
## Ours: a moment after he appears before the first group comes, so they don't land on the door.
const SUMMON_DELAY := 1.5
## His heal (HealLevel_0 1 = M Cure Lv 1, ESAction_Mon_Heal Ratio 0.06 of one life's HP, a bar;
## HealTime_0 5000 ms).
const HEAL_SHARE := 0.06
const HEAL_EVERY := 5.0
const HEAL_CAST := 1.0  # Ours: he stands to cast it, a window to punish
## His own attack (samon281) and voice (BossSound bv_mon281), and the heal's (Cure has no card here).
const SND_CAST := "samon281.wav"
const SND_VOICE := "snd_bv_mon281.wav"
const SND_HEAL := "eff_healing1.wav"

## The player spells whose effects and sounds his spells wear (data/skills/magic).
@export var storm_look: CardData
@export var ring_look: CardData
@export var shield_look: CardData
## Deviation (user, 2026-10-22): Thief Mongs with him from the start, and more at half HP.
@export var summon_start := 3
@export var summon_half := 5
## Deviation (user, 2026-10-22): Cure is cast a limited number of times a fight. Ours: three.
@export var heal_casts := 3

## Thief Mongs called so far.
var summoned := 0
## Each spell's casts so far, by name (tests and tuning read it).
var casts: Dictionary[String, int] = {}
## The MD he wears without Mana Shield.
var base_md := 0.0
var _storm_at := 0.0
var _shield_at := 0.0
var _shield_until := 0.0
var _ring_at := 0.0
var _cure_at := INF
var _half_called := false


func _ready() -> void:
	super._ready()
	base_md = float(stats.get("MD", 0))
	_storm_at = now() + INTRO_FOR + STORM_EVERY
	Audio.play(SND_VOICE, -4.0)
	await get_tree().create_timer(SUMMON_DELAY, false).timeout
	if state != State.DEAD and is_inside_tree():
		_summon(summon_start)


## Bars left, counting the one he is on (3, 2, then 1): his rows' LeftLife count.
func bars_left() -> int:
	return lives_left + 1


## Whether Mana Shield is up. Its +19% is of the MD he wears, the region's (Coral Beach's is 0).
func is_shielded() -> bool:
	return now() < _shield_until


## How hard a spell of `power` hits: his blow scaled by the magic path over his AP.
func spell_hit(power: float) -> int:
	var ap := maxf(float(stats.get("AP", 1)), 1.0)
	return maxi(1, roundi(damage * power * maxf(float(stats.get("MA", 0)) - MA_FLOOR, 0.0) / 100.0 / ap))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	if _shield_until > 0.0 and now() >= _shield_until:
		_shield_until = 0.0
		stats["MD"] = roundi(base_md)


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if bars_left() <= SHIELD_LIVES and now() >= _shield_at:
		_mana_shield()
	if bars_left() <= HEAL_LIVES and now() >= _cure_at and hp < bar_top():
		_cure()
		return
	if now() >= _storm_at and dist <= STORM_RANGE and room.request_attack_token(self):
		_mana_storm()
		return
	if bars_left() <= RING_LIVES and now() >= _ring_at and dist <= RING_RANGE and room.request_attack_token(self):
		_mana_ring()
		return
	super._state_chase()


## Stands and casts `spell` toward the player for `seconds`.
func _cast(spell: String, seconds: float) -> void:
	casts[spell] = casts.get(spell, 0) + 1
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.RECOVER, seconds + 0.3)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(_attack_dir), seconds + 0.2, true)
	Audio.play(SND_CAST, -6.0)


## Whether a spell lands: its ApplyRatio, and the player not dodging.
func _lands(apply: float) -> bool:
	return is_instance_valid(player) and not player.is_invulnerable() and Run.rng.randf() < apply


## Plays a look card's effects for `phase` at `at`; false if it has none to show.
func _look(card: CardData, phase: String, at: Vector2) -> bool:
	var shown := false
	if card:
		for name: String in card.effects.get(phase, []):
			shown = Cake.play(room, name, at) != null or shown
		card.play(phase, -4.0)
	return shown


## M Mana Storm: a storm where the player stands, after its cast time.
func _mana_storm() -> void:
	_storm_at = now() + STORM_EVERY
	_cast("storm", STORM_DELAY)
	var at := player.global_position
	var radius := STORM_RADIUS * STORM_SHRINK
	var warn := Telegraph.make("circle", STORM_DELAY, {"radius": radius})
	room.add_ground_fx(warn, at)
	await get_tree().create_timer(STORM_DELAY, false).timeout
	room.release_attack_token(self)
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	if not _look(storm_look, "ht", at):
		Ring.spawn(room.ground_fx, at, radius, 0.5, Color(0.65, 0.85, 1.0, 0.9))
	if Combat.in_circle(at, player.global_position, radius, 10.0) and _lands(STORM_APPLY):
		player.take_hit(spell_hit(STORM_POWER), Combat.ground(player.global_position - at).normalized(), 200.0,
			true, accuracy(), self)


## M Mana Ring: three rings swoop to where the player stood and burst there.
func _mana_ring() -> void:
	_ring_at = now() + RING_EVERY
	_cast("ring", RING_DELAY)
	var at := player.global_position
	var radius := RING_RADIUS * RING_BURST
	var warn := Telegraph.make("circle", 1.2, {"radius": radius})
	room.add_ground_fx(warn, at)
	_look(ring_look, "ap", global_position)
	room.release_attack_token(self)
	var warn_ref: WeakRef = weakref(warn)  # the warning may be gone before the last ring lands
	for i in RINGS:
		var f := MagicFlight.new()
		f.room = room
		f.caster = self
		f.target_point = at
		f.appear = 0.5 / RINGS * i
		f.fire = 0.5
		f.curve = true
		f.wait_steps = 1
		# As mana_ring.gd: the original ring and its mist trail.
		f.sprite = "magic_ring"
		f.sprite_scale = 0.7
		f.sprite_alpha = 232.0 / 255.0
		f.spin = 1000.0
		f.pointed = false
		f.trail = "yun_gi"
		f.trail_speed = 100.0
		f.trail_alpha = 73.0 / 255.0
		f.trail_vary = false
		f.trail_shrink = true
		f.on_appear = func() -> void:
			if ring_look:
				ring_look.play("launch", -10.0)
		f.on_hit = func(_e: Enemy) -> void:
			_ring_burst(at, radius, warn_ref.get_ref() as Telegraph)
		room.add_child(f)


func _ring_burst(at: Vector2, radius: float, warn: Telegraph) -> void:
	if state == State.DEAD or not is_instance_valid(room) or not is_instance_valid(player):
		return
	if is_instance_valid(warn):
		warn.trigger()
	if not _look(ring_look, "ht", at):
		Ring.spawn(room.ground_fx, at, radius, 0.3, Color(0.65, 0.85, 1.0, 0.9))
	if Combat.in_circle(at, player.global_position, radius, 10.0) and _lands(RING_APPLY):
		player.take_hit(spell_hit(RING_POWER), Combat.ground(player.global_position - at).normalized(), 120.0,
			true, accuracy(), self)


## Mana Shield: his MD up for a while (no cast: it doesn't stop him).
func _mana_shield() -> void:
	_shield_at = now() + SHIELD_EVERY
	if is_shielded():
		return
	_shield_until = now() + SHIELD_FOR
	casts["shield"] = casts.get("shield", 0) + 1
	stats["MD"] = roundi(base_md * (1.0 + SHIELD_MD))
	if not _look(shield_look, "ap", global_position):
		Ring.spawn(room.ground_fx, global_position, 40.0, 0.6, Color(0.55, 0.75, 1.0, 0.8))


## Calls `count` Thief Mongs around him.
func _summon(count: int) -> void:
	summoned += count
	Events.boss_spoke.emit(boss.line_summon)
	room.summon(global_position, SUMMON_ID, count)


## Cure: he stands, then a share of his max HP comes back, while his casts last.
func _cure() -> void:
	_cast("heal", HEAL_CAST)
	_cure_at = now() + HEAL_EVERY if casts.heal < heal_casts else INF
	await get_tree().create_timer(HEAL_CAST, false).timeout
	if broken_off():
		return
	heal(roundi(bar_hp * HEAL_SHARE))
	Audio.play(SND_HEAL, -6.0)
	Ring.spawn(room.ground_fx, global_position, 36.0, 0.5, Color(0.6, 1.0, 0.6, 0.85))


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	super.take_hit(amount, dir, knockback, heavy, fx)
	if hp <= 0:
		return
	if not _half_called and float(hp) / max_hp <= HALF_HP:
		_half_called = true
		_summon(summon_half)


## A bar broken (Boss): on his last he starts to Cure himself.
func _on_phase(_lives: int) -> void:
	if bars_left() <= HEAL_LIVES and casts.get("heal", 0) < heal_casts and _cure_at == INF:
		_cure_at = now() + HEAL_EVERY
