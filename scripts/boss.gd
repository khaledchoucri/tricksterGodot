class_name Boss
extends Enemy
## What every boss shares (each boss's own script extends this): HP in bars, the stagger as a
## bar breaks, the phase that follows, the heals of its BossMonsterparamEx row, the summons it
## calls and the buffs they cast on it, and the name card as it steps in. Its numbers are in
## its EnemyData's BossData (`boss`); see scripts/data/boss_data.gd.
##
## Bars: the server gives a boss LifeCnt lives, refilling its HP to MaxHP for each
## (GameServer.exe 0x5645d0), and the client draws one bar per life left (Trickster.bin
## 0x79f4e0, uBossHPInfoView). Here a boss's HP is one pool cut into bars of one original
## life each (Run.formulas.mob_hp of its row): Tutankhamen's and Tombeth's 3.8 x hp_mult is
## four bars, LifeCnt 3 + 1. A hardened boss with double HP shows twice the bars.
## Reading: a bar breaks when the pool falls past it, and damage beyond it carries on into
## the next, as the server's loop carries a hit past a life.

## Seconds a boss reels as a bar breaks: it can't act and still takes hits. Its next phase
## (and the heal its row may cast) begins as it recovers. Ours.
const STAGGER_FOR := 1.4
## Seconds it takes to step in while its name card shows (it can't be hit or act). Ours.
const INTRO_FOR := 1.6
## The chance each of its row's heals is cast when its timer comes round: `rand() & 1`
## (0x565af0).
const HEAL_CHANCE := 0.5
## Knockback a boss takes, as a share of what a monster would. Ours.
const KNOCKBACK_SHARE := 0.2

var boss: BossData
## How many bars its HP is drawn as, and the HP in each.
var bars := 1
var bar_hp := 1.0
## Bars left beyond the one it is on: the server's lives left (its +0x7f0).
var lives_left := 0
## Its summons as they arrive, by their role in its BossData (role -> Array[Enemy]).
var minions: Dictionary = {}

var _stagger_until := 0.0
var _phase_due := false
var _heal_at := 0.0
var _barrier := 0
var _barrier_aura: Aura
var _barrier_until := 0.0
var _empowered_until := 0.0
var _base_damage := 0
var _base_speeds := Vector2.ZERO
var _summon_at := -1.0
var _crew_called := 0
var _heal_due := 0
var _heal_lands_at := 0.0
var _heal_mark: Telegraph


func configure(p_data: EnemyData, stats_row: Dictionary, elite := false) -> void:
	super.configure(p_data, stats_row, elite)
	boss = data.boss if data.boss else BossData.new()
	var life := Run.formulas.mob_hp(stats, Run.route.region)
	bars = maxi(1, roundi(max_hp / life)) if life > 0.0 else 1
	bar_hp = float(max_hp) / bars
	lives_left = bars - 1
	_base_damage = damage
	_base_speeds = Vector2(walk_speed, run_speed)


func _ready() -> void:
	super._ready()
	_enter(State.SPAWN, INTRO_FOR)
	Events.enemy_spawned.connect(_on_spawned)
	Events.boss_intro.emit(display_name, boss.title, boss.line_open)
	if boss.line_open != "":
		Events.boss_spoke.emit(boss.line_open)
	if not boss.heals.is_empty():
		_heal_at = now() + float(boss.heals[0].get("every", 5.0))


## A number of its moveset: its BossData's `tune[key]`, else `default` (the boss's own,
## named in its script's header), so a hardened variant only changes data.
func num(key: String, default: float) -> float:
	return float(boss.tune.get(key, default))


## How many bars it has lost so far.
func bars_lost() -> int:
	return bars - 1 - lives_left


## The HP at the top of the bar it is on: heals never bring a broken bar back.
func bar_top() -> int:
	return roundi(bar_hp * (lives_left + 1))


## Whether an attack it started should stop: it died, left, or was staggered meanwhile.
func broken_off() -> bool:
	return state == State.DEAD or not is_inside_tree() or not is_instance_valid(room) \
		or not is_instance_valid(player) or now() < _stagger_until


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	_check_bars()
	_land_heal()
	if _phase_due and now() >= _stagger_until:
		_phase_due = false
		_on_phase(lives_left)
	_tick_heals()
	_tick_summons()
	if _empowered_until > 0.0 and now() >= _empowered_until:
		_empowered_until = 0.0
		damage = _base_damage
		walk_speed = _base_speeds.x
		run_speed = _base_speeds.y
	if is_instance_valid(_barrier_aura) and (_barrier <= 0 or now() >= _barrier_until):
		_barrier = 0
		_barrier_aura.end()


func _check_bars() -> void:
	var on := ceili(hp / bar_hp) - 1 if hp > 0 else 0
	while lives_left > on:
		lives_left -= 1
		_break_bar()


## A bar breaks: it reels for STAGGER_FOR, then its next phase begins.
func _break_bar() -> void:
	_cancel_attack()
	velocity = Vector2.ZERO
	_enter(State.HURT, STAGGER_FOR)
	_stagger_until = now() + STAGGER_FOR
	_phase_due = true
	sprite.play_action("hit", sprite.facing, 0.3, true)
	Ring.spawn(room.ground_fx, global_position, 90.0, 0.5, Color(1.0, 0.9, 0.6, 0.9))
	Events.shake_requested.emit(6.0)
	Events.hitstop_requested.emit(0.08)
	Audio.play("dmg_normal_c.wav", -3.0)
	Events.boss_health_changed.emit(self)


## Called as it recovers from a broken bar, with the lives (bars beyond this one) it has left.
## Bosses begin their next phase here.
func _on_phase(_lives: int) -> void:
	pass


## Its row's heals (0x565af0): each time the timer comes round, the first heal whose
## lives it is down to may be cast (a coin flip each); the timer restarts at that heal's
## time (or the first's when none is cast).
func _tick_heals() -> void:
	if boss.heals.is_empty() or now() < _heal_at or state == State.SPAWN:
		return
	var pick := 0
	for i in boss.heals.size():
		var h: Dictionary = boss.heals[i]
		if lives_left <= int(h.get("lives", 0)) and hp < bar_top() and Run.rng.randf() < HEAL_CHANCE:
			pick = i
			_cast_heal(roundi(float(h.get("share", 0.0)) * bar_hp))
			break
	_heal_at = now() + float(boss.heals[pick].get("every", 5.0))


## M Cure: at once, or after its cast (BossData.heal_cast) if no heavy hit breaks it off.
func _cast_heal(amount: int) -> void:
	if boss.heal_cast <= 0.0:
		heal(amount)
		return
	if _heal_due > 0:
		return
	_heal_due = amount
	_heal_lands_at = now() + boss.heal_cast
	_heal_mark = Telegraph.make("circle", boss.heal_cast, {"radius": body_radius + 24.0, "color": Color(0.45, 1.0, 0.55)})
	room.add_ground_fx(_heal_mark, global_position)
	Events.text_shown.emit(global_position + Vector2(0, -80), "M Cure", Color(0.5, 1.0, 0.55))


func _land_heal() -> void:
	if _heal_due > 0 and now() >= _heal_lands_at:
		heal(_heal_due)
		_heal_due = 0


## Whether an M Cure is being cast on it.
func healing() -> bool:
	return _heal_due > 0


## Its row's summon waves (BossData.summon_*): the first as it reaches SummonLeftLife, then
## every SummonTime, each SummonMin to SummonMax of its SummonMon, SummonTotalCnt in all.
func _tick_summons() -> void:
	if boss.summon_every <= 0.0 or boss.summon_pool.is_empty() or lives_left > boss.summon_lives \
			or _crew_called >= boss.summon_total or state == State.SPAWN or now() < _stagger_until:
		return
	if _summon_at < 0.0:
		_summon_at = now()
	if now() < _summon_at:
		return
	_summon_at = now() + boss.summon_every
	var count := mini(Run.rng.randi_range(boss.summon_min, boss.summon_max), boss.summon_total - _crew_called)
	_crew_called += count
	var by_id: Dictionary = {}
	for _i in count:
		var e: EnemyData = boss.summon_pool[Run.rng.randi() % boss.summon_pool.size()]
		by_id[e.id] = int(by_id.get(e.id, 0)) + 1
	for id: StringName in by_id:
		room.summon(global_position, id, by_id[id])
	if boss.line_summon != "":
		Events.boss_spoke.emit(boss.line_summon)


## How many its summon waves have called so far.
func crew_called() -> int:
	return _crew_called


## Heals it, never past the top of the bar it is on.
func heal(amount: int) -> void:
	var before := hp
	hp = mini(bar_top(), hp + amount)
	if hp <= before:
		return
	Events.damage_shown.emit(global_position + Vector2(0, -60), hp - before, Color(0.5, 1.0, 0.55), false)
	Sparks.burst(room, global_position + Vector2(0, -30), Color(0.5, 1.0, 0.55), 16, 90.0, 0.6, 2.5, -60.0)
	Events.boss_health_changed.emit(self)


## A shield over it (a guard's Mana Shield) that soaks `amount` of damage for `seconds`.
func shield(amount: int, seconds: float) -> void:
	_barrier = maxi(_barrier, amount)
	_barrier_until = now() + seconds
	if not is_instance_valid(_barrier_aura):
		_barrier_aura = Aura.attach(self, body_radius + 16.0, Color(0.55, 0.75, 1.0, 0.9))
	Events.text_shown.emit(global_position + Vector2(0, -80), "Mana Shield", Color(0.6, 0.8, 1.0))


func has_shield() -> bool:
	return _barrier > 0 and now() < _barrier_until


## Hits harder and moves faster for `seconds` (a lieutenant's Mad Spirit).
func empower(damage_mult: float, speed_mult: float, seconds: float) -> void:
	damage = roundi(_base_damage * damage_mult)
	walk_speed = _base_speeds.x * speed_mult
	run_speed = _base_speeds.y * speed_mult
	_empowered_until = now() + seconds
	Events.text_shown.emit(global_position + Vector2(0, -80), "Mad Spirit", Color(1.0, 0.55, 0.4))
	Sparks.burst(room, global_position + Vector2(0, -30), Color(1.0, 0.5, 0.35), 18, 120.0, 0.5)


func is_empowered() -> bool:
	return now() < _empowered_until


## Calls `count` of its summons of `role` around it.
func summon(role: StringName, count: int) -> void:
	var e: EnemyData = boss.summons.get(role)
	if e and count > 0:
		room.summon(global_position, e.id, count)


## The first of its summons of `role` still standing, or null.
func minion(role: StringName) -> Enemy:
	for e: Enemy in minions.get(role, []):
		if is_instance_valid(e) and e.state != State.DEAD:
			return e
	return null


func _on_spawned(e: Enemy) -> void:
	for role: StringName in boss.summons:
		if e.data == boss.summons[role]:
			minions[role] = minions.get(role, []) + [e]


## A line from a summon to it, as a summon's spell lands on it.
func show_cast_from(from: Enemy, color: Color) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.points = PackedVector2Array([from.global_position + Vector2(0, -30), global_position + Vector2(0, -30)])
	line.z_index = 14
	room.world.add_child(line)
	line.create_tween().tween_property(line, "modulate:a", 0.0, 0.5).finished.connect(line.queue_free)


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	if is_hittable() and has_shield() and debuff("frozen") <= 0.0:
		var soaked := mini(amount, _barrier)
		_barrier -= soaked
		amount -= soaked
		Ring.spawn(room.ground_fx, global_position, body_radius + 16.0, 0.25, Color(0.6, 0.8, 1.0, 0.9))
		if amount <= 0:
			Events.text_shown.emit(global_position + Vector2(0, -60), "Shield", Color(0.6, 0.8, 1.0))
			return
	if heavy and _heal_due > 0 and is_hittable():
		_heal_due = 0
		if is_instance_valid(_heal_mark):
			_heal_mark.queue_free()
		Events.text_shown.emit(global_position + Vector2(0, -80), "Interrupted", Color(1.0, 0.9, 0.5))
	super.take_hit(amount, dir, knockback * KNOCKBACK_SHARE, heavy, fx)
