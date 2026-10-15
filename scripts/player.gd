class_name Player
extends CharacterBody2D
## Buffalo (Power family). WASD movement, cursor-aimed attacks, a dash with
## invulnerability, and the Shockwave skill. Timings follow the Hades II
## reference sheet in docs/poc/timing-reference.md and are meant to be tuned.

signal died
signal hp_changed(hp: int, max_hp: int)

enum State { MOVE, ATTACK, DASH, SKILL, HURT, DEAD }

@export var max_hp := 140
@export var move_speed := 175.0
@export var dash_distance := 115.0
@export var dash_time := 0.20
@export var dash_invuln := 0.27
@export var dash_cooldown := 0.42
@export var input_buffer := 0.15
@export var hurt_invuln := 0.6
@export var skill_cooldown := 5.0

## Combo steps. Times are seconds from the start of the swing.
const COMBO := [
	{"anim": "attack", "len": 0.34, "hit_from": 0.09, "hit_to": 0.16, "chain_at": 0.14,
	 "dash_cancel": 0.08, "free_at": 0.24, "damage": 22, "reach": 50.0, "arc": 115.0,
	 "knockback": 140.0, "lunge": 70.0, "hitstop": 0.045},
	{"anim": "attack2", "len": 0.44, "hit_from": 0.13, "hit_to": 0.26, "chain_at": 99.0,
	 "dash_cancel": 0.12, "free_at": 0.34, "damage": 36, "reach": 58.0, "arc": 150.0,
	 "knockback": 300.0, "lunge": 110.0, "hitstop": 0.075},
]
const SKILL := {"anim": "cast", "len": 0.5, "hit_at": 0.26, "damage": 30, "radius": 92.0,
	"knockback": 340.0, "hitstop": 0.08, "name": "Shockwave"}

var hp := max_hp
var state := State.MOVE
var aim := Vector2(1, 1).normalized()  # ground-plane direction toward the cursor
var invulnerable_until := 0.0
var dash_ready_at := 0.0
var skill_ready_at := 0.0

var _t := 0.0
var _combo_step := 0
var _hit_this_swing: Array = []
var _buffered := ""
var _buffered_at := -10.0
var _dash_dir := Vector2.ZERO
var _knock := Vector2.ZERO
var _skill_fired := false
var _mouse_aim := false  # aim follows the cursor once the mouse is used
var _phasing := false

@onready var sprite: ActorSprite = $Sprite
@onready var arena = get_tree().get_first_node_in_group("arena")


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	sprite.setup("buffalo")
	sprite.play_action("idle", Vector2(1, 1))
	hp_changed.emit(hp, max_hp)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func is_invulnerable() -> bool:
	return now() < invulnerable_until or state == State.DEAD


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_aim = true
	for action in ["attack", "skill", "dash"]:
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
			_state_attack(delta)
		State.DASH:
			_state_dash()
		State.SKILL:
			_state_skill()
		State.HURT:
			velocity = _knock
			if _t >= 0.18:
				_enter(State.MOVE)
	move_and_slide()
	if _phasing and state != State.DASH and not _overlapping_enemy():
		_set_phasing(false)
	_blink()


## While phasing, the player and enemies ignore each other's bodies. It ends
## once the dash is over and the player has stepped clear of every enemy, so
## nobody gets pushed out of an overlap.
func _set_phasing(on: bool) -> void:
	_phasing = on
	set_collision_layer_value(2, not on)
	set_collision_mask_value(3, not on)


func _overlapping_enemy() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state != Enemy.State.DEAD and global_position.distance_to(e.global_position) < 11.0 + e.body_radius + 2.0:
			return true
	return false


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
	if _take_buffer("skill") and now() >= skill_ready_at:
		_start_skill()
		return true
	if _take_buffer("attack"):
		_start_attack(0)
		return true
	return false


func _state_move() -> void:
	if _try_actions():
		return
	var input := _move_input()
	velocity = input * move_speed + _knock
	if input != Vector2.ZERO:
		sprite.play_action("run", input, 0.0)
		sprite.speed_scale = 1.15
	else:
		sprite.play_action("idle")


func _start_attack(step: int) -> void:
	_combo_step = step
	_hit_this_swing.clear()
	var s: Dictionary = COMBO[step]
	_enter(State.ATTACK)
	sprite.play_action(s.anim, Combat.screen(aim), s.len, true)


func _state_attack(_delta: float) -> void:
	var s: Dictionary = COMBO[_combo_step]
	# Short forward lunge during the active part sells the weight of the punch.
	var lunge: float = s.lunge if _t < s.hit_to else 0.0
	velocity = Combat.screen(aim) * lunge + _knock
	if _t >= s.hit_from and _t <= s.hit_to:
		_apply_swing(s)
	if _t >= s.dash_cancel and _take_buffer("dash") and now() >= dash_ready_at:
		_start_dash()
		return
	if _t >= s.chain_at and _combo_step + 1 < COMBO.size() and _take_buffer("attack"):
		_start_attack(_combo_step + 1)
		return
	if _t >= s.free_at:
		if _move_input() != Vector2.ZERO or _t >= s.len:
			_enter(State.MOVE)
		elif _try_actions():
			return


func _apply_swing(s: Dictionary) -> void:
	var landed := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _hit_this_swing or not e.is_hittable():
			continue
		if Combat.in_wedge(global_position, e.global_position, aim, s.reach, deg_to_rad(s.arc), e.body_radius):
			_hit_this_swing.append(e)
			e.take_hit(s.damage, Combat.ground(e.global_position - global_position).normalized(), s.knockback, _combo_step == COMBO.size() - 1)
			landed = true
	if landed:
		arena.hitstop(s.hitstop)
		arena.shake(2.5 if _combo_step == 0 else 4.5)


func _start_dash() -> void:
	var input := _move_input()
	_dash_dir = input.normalized() if input != Vector2.ZERO else Combat.screen(aim).normalized()
	dash_ready_at = now() + dash_time + dash_cooldown
	invulnerable_until = maxf(invulnerable_until, now() + dash_invuln)
	_set_phasing(true)  # pass through enemies, and don't shove them, while dashing
	_enter(State.DASH)
	var anim := "dodge" if sprite.has_action("dodge") else "run"
	sprite.play_action(anim, _dash_dir, dash_time, true)
	arena.dash_trail(global_position)


func _state_dash() -> void:
	velocity = _dash_dir * (dash_distance / dash_time)
	if _t >= dash_time:
		_enter(State.MOVE)
		if not _try_actions():
			_state_move()


func _start_skill() -> void:
	skill_ready_at = now() + skill_cooldown
	_skill_fired = false
	_enter(State.SKILL)
	sprite.play_action(SKILL.anim, Combat.screen(aim), SKILL.len, true)


func _state_skill() -> void:
	velocity = _knock * 0.3
	if not _skill_fired and _t >= SKILL.hit_at:
		_skill_fired = true
		arena.shockwave(global_position, SKILL.radius)
		var landed := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_hittable() and Combat.in_circle(global_position, e.global_position, SKILL.radius, e.body_radius):
				e.take_hit(SKILL.damage, Combat.ground(e.global_position - global_position).normalized(), SKILL.knockback, true)
				landed = true
		arena.shake(6.0)
		if landed:
			arena.hitstop(SKILL.hitstop)
	if _t >= SKILL.hit_at + 0.06 and _take_buffer("dash") and now() >= dash_ready_at:
		_start_dash()
		return
	if _t >= SKILL.len:
		_enter(State.MOVE)


func take_hit(amount: int, from_dir: Vector2, knockback: float) -> void:
	if is_invulnerable():
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	arena.damage_number(global_position + Vector2(0, -70), amount, Color(1.0, 0.45, 0.4))
	arena.hitstop(0.06)
	arena.shake(5.0)
	invulnerable_until = now() + hurt_invuln
	_knock = Combat.screen(from_dir) * knockback
	if hp <= 0:
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


func _enter(s: State) -> void:
	state = s
	_t = 0.0


func _blink() -> void:
	var flicker := state != State.DASH and now() < invulnerable_until and state != State.DEAD
	sprite.modulate.a = 0.45 if flicker and int(now() * 20.0) % 2 == 0 else 1.0
