class_name Player
extends CharacterBody2D
## Buffalo (Power family, Knight line). WASD movement, a cursor-aimed sword
## combo (Combos.SWORD), a dash that vaults obstacles, and three skill slots
## (RMB, Q, E) holding the active skills in Run.loadout, paid for with MP.
## Run stats and talent cards modify damage, speed and effects. Base timings
## follow the Hades II reference in docs/poc/timing-reference.md.

signal died

enum State { MOVE, ATTACK, DASH, SKILL, HURT, DEAD }

const BODY_RADIUS := 11.0
const VAULT_HOP := 14.0
## Input actions for skill slots 1-3.
const SLOT_ACTIONS: Array[String] = ["skill", "skill_2", "skill_3"]
const HIT_SOUNDS: Array[String] = ["dmg_normal_a.wav", "dmg_normal_b.wav", "dmg_normal_c.wav", "dmg_normal_d.wav"]

@export var move_speed := 175.0
@export var dash_distance := 115.0
@export var dash_time := 0.20
@export var dash_invuln := 0.27
@export var dash_cooldown := 0.42
## How much further than a normal dash a vault may carry to find landing room.
@export var vault_extra := 70.0
@export var input_buffer := 0.15
@export var hurt_invuln := 0.6
## MP restored per enemy struck by the basic combo.
@export var mp_per_hit := 5

## Set by the game before the player enters the room.
var room: Room

var state := State.MOVE
var aim := Vector2(1, 1).normalized()  # ground-plane direction toward the cursor
var invulnerable_until := 0.0
var dash_ready_at := 0.0
var slot_ready_at: Array[float] = [0.0, 0.0, 0.0]

var _t := 0.0
var _swing_aim := aim  # aim locked in for the current swing
var _combo: Array[Dictionary] = []
var _combo_step := 0
var _window := -1
var _hit_this_window: Array[Enemy] = []
var _hit_this_dash: Array[Enemy] = []
var _buffered := ""
var _buffered_at := -10.0
var _dash_dir := Vector2.ZERO
var _knock := Vector2.ZERO
var _skill: Skill  # the cast in progress
var _mouse_aim := false  # aim follows the cursor once the mouse is used
var _phasing := false
var _vaulting := false
var _dash_len := 0.2

@onready var sprite: ActorSprite = $Sprite
@onready var camera: Camera2D = $Camera
@onready var weapon: HeldWeapon = $Weapon
@onready var silhouette: Silhouette = $Silhouette


func _ready() -> void:
	add_to_group("player")
	sprite.setup("buffalo")
	sprite.play_action("idle", Vector2(1, 1))


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Called by the room: shows the silhouette while scenery hides the player.
func set_hidden_behind_scenery(hidden: bool) -> void:
	silhouette.visible = hidden and state != State.DEAD


func is_invulnerable() -> bool:
	return now() < invulnerable_until or state == State.DEAD


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_aim = true
	for action: String in ["attack", "dash"] + SLOT_ACTIONS:
		if event.is_action_pressed(action):
			_buffered = action
			_buffered_at = now()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var mouse := get_global_mouse_position()
	if _mouse_aim and mouse.distance_to(global_position) > 4.0:
		aim = Combat.ground(mouse - global_position).normalized()
	_t += delta
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	match state:
		State.MOVE:
			_state_move()
		State.ATTACK:
			_state_attack()
		State.DASH:
			_state_dash()
		State.SKILL:
			_state_skill(delta)
		State.HURT:
			velocity = _knock
			if _t >= 0.18:
				_enter(State.MOVE)
	move_and_slide()
	if _phasing and state != State.DASH and state != State.SKILL and not _overlapping_enemy():
		set_phasing(false)
	_blink()


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _take_buffer(action: String) -> bool:
	if _buffered == action and now() - _buffered_at <= input_buffer:
		_buffered = ""
		return true
	return false


func _try_actions() -> bool:
	if _take_buffer("dash") and now() >= dash_ready_at:
		_start_dash()
		return true
	for i in SLOT_ACTIONS.size():
		if _take_buffer(SLOT_ACTIONS[i]):
			return _try_cast(i)
	if _take_buffer("attack"):
		_start_attack(0)
		return true
	return false


func _state_move() -> void:
	if _try_actions():
		return
	var input := _move_input()
	velocity = input * move_speed * Run.speed_mult() + _knock
	if input != Vector2.ZERO:
		sprite.play_action("run", input)
		sprite.speed_scale = 1.15 * Run.speed_mult()
	else:
		sprite.play_action("idle")


# ---------------------------------------------------------------- attacks

func _start_attack(step: int) -> void:
	if step == 0:
		_combo = Combos.SWORD
	_combo_step = step
	_window = -1
	var s := _combo[step]
	_enter(State.ATTACK)
	_swing_aim = aim  # each swing commits to the aim it started with
	sprite.play_action(s.anim, Combat.screen(_swing_aim), s.len / Run.attack_speed_mult(), true, s.get("frames", []))
	if s.get("slash", false):
		var w: Array = s.windows[0]
		weapon.swing(_swing_aim, deg_to_rad(s.arc), _sweeps_clockwise(s), w[0] / Run.attack_speed_mult(), w[1] / Run.attack_speed_mult())
	Audio.play(s.sound, -6.0)


func _state_attack() -> void:
	var s := _combo[_combo_step]
	var t := _t * Run.attack_speed_mult()  # swing time at normal speed
	var windows: Array = s.windows
	var last_window: Array = windows[windows.size() - 1]
	var lunge: float = s.lunge if t < last_window[1] else 0.0
	velocity = Combat.screen(_swing_aim) * lunge + _knock
	for i in windows.size():
		var w: Array = windows[i]
		if t >= w[0] and t <= w[1]:
			if _window != i:
				_window = i
				_hit_this_window.clear()
				if s.get("slash", false):
					_spawn_slash(s, (w[1] - w[0]) / Run.attack_speed_mult())
			_apply_swing(s)
	if t >= s.dash_cancel and _take_buffer("dash") and now() >= dash_ready_at:
		_start_dash()
		return
	if t >= s.chain_at and _combo_step + 1 < _combo.size() and _take_buffer("attack"):
		_start_attack(_combo_step + 1)
		return
	if t >= s.free_at:
		if _move_input() != Vector2.ZERO or t >= s.len:
			_enter(State.MOVE)
		elif _try_actions():
			return


func _apply_swing(s: Dictionary) -> void:
	var landed := false
	var crit_any := false
	var finisher: bool = s.get("finisher", false)
	for e in room.enemies:
		if e in _hit_this_window or not e.is_hittable():
			continue
		if Combat.in_wedge(global_position, e.global_position, _swing_aim, s.reach, deg_to_rad(s.arc), e.body_radius):
			_hit_this_window.append(e)
			crit_any = deal_hit(e, s.damage, Run.attack_mult(), s.knockback, finisher, _combo_fx(finisher)) or crit_any
			Run.gain_mp(mp_per_hit)
			landed = true
	if landed:
		Audio.play(HIT_SOUNDS[randi() % HIT_SOUNDS.size()], -4.0)
		Events.hitstop_requested.emit(s.hitstop * (1.6 if crit_any else 1.0))
		Events.shake_requested.emit(4.5 if finisher else 2.5)


## The sword art strikes clockwise facing right and counter-clockwise facing
## left; blade and trail follow it.
func _sweeps_clockwise(s: Dictionary) -> bool:
	return s.cw if _swing_aim.x >= 0.0 else not s.cw


func _spawn_slash(s: Dictionary, sweep: float) -> void:
	var finisher: bool = s.get("finisher", false)
	Slash.spawn(room, global_position + Vector2(0, -16), {"radius": s.reach, "arc": deg_to_rad(s.arc),
		"dir": _swing_aim, "clockwise": _sweeps_clockwise(s), "sweep_time": maxf(sweep, 0.05), "life": sweep + 0.16,
		"width": 18.0 if finisher else 13.0})


## Talent effects carried by basic attacks.
func _combo_fx(finisher: bool) -> Dictionary:
	var fx := {}
	if Run.card_level(&"flaming_fist") > 0:
		fx.burn = Run.card_value(&"flaming_fist")
	if finisher and Run.card_level(&"uppercut") > 0:
		fx.stun = Run.card_value(&"uppercut")
	return fx


## Damages an enemy with crits and Armor Breaker. Every hit the player deals
## (combo, dash, skills) comes through here. `from` sets the knockback
## direction. Returns true on a critical hit.
func deal_hit(e: Enemy, base: float, mult: float, knockback: float, heavy: bool, fx := {}, from := Vector2.INF) -> bool:
	var crit := randf() < Run.crit_chance()
	var amount := roundi(base * mult * (1.75 if crit else 1.0))
	var effects := fx.duplicate()
	effects.crit = crit
	if Run.card_level(&"armor_breaker") > 0:
		effects.break = Run.card_value(&"armor_breaker")
	if crit:
		Audio.play("etc_critical.wav", -6.0)
	var origin := global_position if from == Vector2.INF else from
	e.take_hit(amount, Combat.ground(e.global_position - origin).normalized(), knockback, heavy, effects)
	return crit


# ---------------------------------------------------------------- dash

func _start_dash() -> void:
	var input := _move_input()
	_dash_dir = input.normalized() if input != Vector2.ZERO else Combat.screen(aim).normalized()
	# Vault over obstacles when there's open ground to land on past them.
	var vault := room.vault_distance(global_position, _dash_dir, dash_distance, vault_extra)
	_vaulting = vault > 0.0
	_dash_len = dash_time * (vault / dash_distance if _vaulting else 1.0)
	set_collision_mask_value(1, not _vaulting)
	dash_ready_at = now() + _dash_len + dash_cooldown
	invulnerable_until = maxf(invulnerable_until, now() + maxf(dash_invuln, _dash_len + 0.05))
	set_phasing(true)  # pass through enemies, and don't shove them, while dashing
	_hit_this_dash.clear()
	_enter(State.DASH)
	var anim := "dodge" if sprite.has_action("dodge") else "run"
	sprite.play_action(anim, _dash_dir, _dash_len, true)
	Ring.spawn(room.ground_fx, global_position, 18.0, 0.25, Color(1, 1, 1, 0.6))
	Audio.play("etc_miss.wav", -8.0)


func _state_dash() -> void:
	velocity = _dash_dir * (dash_distance / dash_time)
	if Run.card_level(&"counter_punch") > 0:
		for e in room.enemies:
			if e.is_hittable() and not e in _hit_this_dash and _touching(e, 8.0):
				_hit_this_dash.append(e)
				deal_hit(e, Run.card_value(&"counter_punch"), Run.attack_mult(), 120.0, false)
				Audio.play(HIT_SOUNDS[0], -4.0)
				Events.hitstop_requested.emit(0.03)
	if _vaulting:
		sprite.position.y = -sin(PI * clampf(_t / _dash_len, 0.0, 1.0)) * VAULT_HOP
	if _t >= _dash_len:
		_end_vault()
		_enter(State.MOVE)
		if not _try_actions():
			_state_move()


func _end_vault() -> void:
	if not _vaulting:
		return
	_vaulting = false
	sprite.position.y = 0.0
	set_collision_mask_value(1, true)
	if not room.is_walkable(global_position):
		global_position = room.nearest_reachable(global_position)


## While phasing, the player and enemies ignore each other's bodies. It ends
## once the dash or skill is over and the player has stepped clear of every
## enemy, so nobody gets pushed out of an overlap.
func set_phasing(on: bool) -> void:
	_phasing = on
	set_collision_layer_value(2, not on)
	set_collision_mask_value(3, not on)


func _touching(e: Enemy, slack: float) -> bool:
	return global_position.distance_to(e.global_position) < BODY_RADIUS + e.body_radius + slack


func _overlapping_enemy() -> bool:
	for e in room.enemies:
		if e.state != Enemy.State.DEAD and _touching(e, 2.0):
			return true
	return false


# ---------------------------------------------------------------- skills

## Where the cursor is on the ground; without a mouse, a point ahead of the aim.
func cursor_point() -> Vector2:
	return get_global_mouse_position() if _mouse_aim else global_position + Combat.screen(aim) * 150.0


## Casts the skill in `slot` if one is equipped, off cooldown and affordable.
func _try_cast(slot: int) -> bool:
	var id: StringName = Run.loadout[slot]
	if id == &"" or now() < slot_ready_at[slot]:
		return false
	var card := Run.region.card(id)
	if not Run.spend_mp(card.mp_cost):
		Events.mp_short.emit()
		return false
	var skill: Skill = card.behavior.new()
	skill.card = card
	skill.level = Run.card_level(id)
	skill.player = self
	skill.room = room
	skill.aim = aim
	skill.target = cursor_point()
	slot_ready_at[slot] = now() + card.cooldown_at(skill.level) * Run.skill_cooldown_mult()
	_enter(State.SKILL)
	_skill = skill
	if skill.invulnerable:
		invulnerable_until = maxf(invulnerable_until, now() + skill.duration)
		set_phasing(true)
	sprite.play_action(skill.anim, Combat.screen(aim), skill.duration, true, skill.anim_frames)
	skill.start()
	Events.skill_cast.emit(slot)
	return true


func _state_skill(delta: float) -> void:
	velocity = _skill.movement(_t) + _knock * 0.3
	_skill.update(_t, delta)
	if _t >= _skill.dash_cancel_at and _take_buffer("dash") and now() >= dash_ready_at:
		_start_dash()
		return
	if _t >= _skill.duration:
		_enter(State.MOVE)


# ---------------------------------------------------------------- damage taken

func take_hit(amount: int, from_dir: Vector2, knockback: float) -> void:
	if is_invulnerable():
		return
	amount = maxi(1, roundi(amount * Run.damage_taken_mult()))
	Run.take_damage(amount)
	Events.damage_shown.emit(global_position + Vector2(0, -70), amount, Color(1.0, 0.45, 0.4), false)
	Audio.play("shchr002.wav", -6.0)
	Events.hitstop_requested.emit(0.06)
	Events.shake_requested.emit(5.0)
	invulnerable_until = now() + hurt_invuln
	_knock = Combat.screen(from_dir) * knockback
	if Run.hp <= 0:
		_die()
		return
	_enter(State.HURT)
	sprite.play_action("hit", -Combat.screen(from_dir), 0.18, true)


func _die() -> void:
	_enter(State.DEAD)
	velocity = Vector2.ZERO
	collision_layer = 0
	sprite.play_action("faint", Vector2.ZERO, 0.9, true)
	died.emit()
	Events.player_died.emit()


func _enter(s: State) -> void:
	if _skill and s != State.SKILL:
		var ending := _skill
		_skill = null
		ending.finish()
	state = s
	_t = 0.0
	if s != State.ATTACK:
		weapon.carry()
	if s != State.DASH:
		_end_vault()


func _blink() -> void:
	var flicker := state != State.DASH and state != State.DEAD and now() < invulnerable_until
	sprite.modulate.a = 0.45 if flicker and int(now() * 20.0) % 2 == 0 else 1.0
