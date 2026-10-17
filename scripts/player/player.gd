class_name Player
extends CharacterBody2D
## The player character (Run.cls; Buffalo for now). Owns movement, the input buffer, the
## state machine, the dash (which vaults obstacles) and damage in and out.
## The basic attack chain is the ComboAttack child (playing `combo`) and the
## three skill slots are the SkillCaster child. Run stats and talent cards
## modify damage, speed and effects. Base timings follow the Hades II
## reference in docs/poc/timing-reference.md.

signal died

enum State { MOVE, ATTACK, DASH, SKILL, HURT, DEAD }

const BODY_RADIUS := 11.0
const VAULT_HOP := 14.0
const SHADOW_RADIUS := 70.0
## Basic combo for each weapon family.
const FAMILY_COMBOS := {
	"sword": preload("res://data/combos/sword.tres"),
	"hammer": preload("res://data/combos/hammer.tres"),
}

@export var combo: ComboData
@export var move_speed := 175.0
@export var dash_distance := 115.0
@export var dash_time := 0.20
@export var dash_invuln := 0.27
@export var dash_cooldown := 0.42
## How much further than a normal dash a vault may carry to find landing room.
@export var vault_extra := 70.0
@export var input_buffer := 0.15
@export var hurt_invuln := 0.6

## Set by the game before the player enters the room.
var room: Room

var state := State.MOVE
var aim := Vector2(1, 1).normalized()  # ground-plane direction toward the cursor
var invulnerable_until := 0.0
var dash_ready_at := 0.0
## Knockback velocity, decaying; states add it to their movement.
var knock := Vector2.ZERO

var _t := 0.0
var _hit_this_dash: Array[Enemy] = []
var _buffered := ""
var _buffered_at := -10.0
var _dash_dir := Vector2.ZERO
var _mouse_aim := false  # aim follows the cursor once the mouse is used
var _phasing := false
var _vaulting := false
var _dash_len := 0.2
var _perfect_this_dash := false
var _chakra := 0.0
var _steps: Array[ComboStep] = []

@onready var sprite: ActorSprite = $Sprite
@onready var camera: Camera2D = $Camera
@onready var weapon: HeldWeapon = $Weapon
@onready var silhouette: Silhouette = $Silhouette
@onready var attack: ComboAttack = $ComboAttack
@onready var skills: SkillCaster = $SkillCaster


func _ready() -> void:
	add_to_group("player")
	sprite.setup(Run.cls.actor)
	refresh_gear()
	sprite.play_action("idle", Vector2(1, 1))


func now() -> float:
	return Events.time


## Matches the held weapon and the combo to the equipped weapon, and adds
## the Extra Swing trait's swing.
func refresh_gear() -> void:
	var w := Run.equipped("weapon")
	if w and Run.cls.armed:
		weapon.use(w.data.weapon_sprite())
	weapon.visible = Run.cls.armed
	weapon.set_process(Run.cls.armed)
	var family := Run.weapon_family() if Run.cls.id != &"trickster" else String(Profile.custom.get("kit", Run.weapon_family()))
	combo = Run.cls.combo if Run.cls.combo else FAMILY_COMBOS.get(family, FAMILY_COMBOS.get(Run.weapon_family(), combo))
	_steps = combo.steps.duplicate()
	if Run.has_trait(&"extra_swing") and _steps.size() >= 2:
		var extra: ComboStep = _steps[_steps.size() - 2].duplicate()
		extra.clockwise = not extra.clockwise
		extra.frames = Vector2i(extra.frames.y, extra.frames.x)
		_steps.insert(_steps.size() - 1, extra)


func combo_steps() -> Array[ComboStep]:
	if _steps.is_empty():
		refresh_gear()
	return _steps


## Keeps the camera inside `rect` plus a margin.
func set_camera_limits(rect: Rect2, margin: int) -> void:
	camera.limit_left = int(rect.position.x) - margin
	camera.limit_top = int(rect.position.y) - margin
	camera.limit_right = int(rect.end.x) + margin
	camera.limit_bottom = int(rect.end.y) + margin
	camera.make_current()
	camera.reset_smoothing()


## Called by the room: shows the silhouette while scenery hides the player.
func set_hidden_behind_scenery(hidden: bool) -> void:
	silhouette.visible = hidden and state != State.DEAD


func is_invulnerable() -> bool:
	return now() < invulnerable_until or state == State.DEAD


## Where the cursor is on the ground; without a mouse, a point ahead of the aim.
func cursor_point() -> Vector2:
	return get_global_mouse_position() if _mouse_aim else global_position + Combat.screen(aim) * 150.0


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_aim = true
	for action: String in ["attack", "dash"] + SkillCaster.SLOT_ACTIONS:
		if event.is_action_pressed(action):
			buffer_action(action)


## Queues an action as if just pressed; it stays valid for `input_buffer` seconds.
func buffer_action(action: String) -> void:
	_buffered = action
	_buffered_at = now()


## Consumes a buffered action if it's `action` and still fresh.
func take_buffer(action: String) -> bool:
	if _buffered == action and now() - _buffered_at <= input_buffer:
		_buffered = ""
		return true
	return false


func move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Starts whatever buffered action can start now. Returns true if one did.
func try_actions() -> bool:
	if take_buffer("dash") and can_dash():
		start_dash()
		return true
	for i in SkillCaster.SLOT_ACTIONS.size():
		if take_buffer(SkillCaster.SLOT_ACTIONS[i]):
			return skills.try_cast(i)
	if take_buffer("attack"):
		attack.start(0)
		return true
	return false


# ---------------------------------------------------------------- states

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var mouse := get_global_mouse_position()
	if _mouse_aim and mouse.distance_to(global_position) > 4.0:
		aim = Combat.ground(mouse - global_position).normalized()
	_t += delta
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if Run.card_level(&"chakra_balance") > 0:
		_chakra += Run.card_value(&"chakra_balance") * delta
		if _chakra >= 1.0:
			Run.gain_mp(int(_chakra))
			_chakra -= int(_chakra)
	match state:
		State.MOVE:
			_state_move()
		State.ATTACK:
			attack.update(delta)
		State.DASH:
			_state_dash()
		State.SKILL:
			skills.update(delta)
		State.HURT:
			velocity = knock
			if _t >= 0.18:
				enter(State.MOVE)
	move_and_slide()
	if _phasing and state != State.DASH and state != State.SKILL and not _overlapping_enemy():
		set_phasing(false)
	_blink()


func _state_move() -> void:
	if try_actions():
		return
	var input := move_input()
	velocity = input * move_speed * Run.speed_mult() + knock
	if input != Vector2.ZERO:
		sprite.play_action("run", input)
		sprite.speed_scale = 1.15 * Run.speed_mult()
	else:
		sprite.play_action("idle")


func enter(s: State) -> void:
	if state == State.SKILL and s != State.SKILL:
		skills.stop()
	state = s
	_t = 0.0
	if s != State.ATTACK:
		weapon.carry()
	if s != State.DASH:
		_end_vault()


# ---------------------------------------------------------------- dealing damage

## Damages an enemy with crits and Armor Breaker. Every hit the player deals
## (combo, dash, skills) comes through here. `from` sets the knockback
## direction. Returns true on a critical hit.
func deal_hit(e: Enemy, base: float, mult: float, knockback: float, heavy: bool, fx := {}, from := Vector2.INF) -> bool:
	var crit := randf() < Run.crit_chance()
	if Run.card_level(&"suffocate") > 0 and e.state == Enemy.State.HURT:
		mult *= 1.0 + Run.card_value(&"suffocate") / 100.0
	# Low accuracy against an evasive monster grazes for half damage, never misses.
	var graze := not crit and randf() < e.evade_chance(Run.stat("AC"))
	# Elemental attack from compounds adds its % on top, less the monster's resistance.
	var element := 1.0
	var el := Run.element_attack()
	for k: String in el:
		element += el[k] / 100.0 * (1.0 - e.resist(k) / 100.0)
	if Run.quirk(&"elite_bane") and (e.is_elite or e.is_boss):
		mult *= 1.1
	var crit_mult := 2.0 if Run.quirk(&"sharp_eye") else 1.75
	var amount := maxi(1, roundi(base * mult * element * (crit_mult if crit else 1.0) * (0.5 if graze else 1.0) * e.defense_mult()))
	var effects := fx.duplicate()
	effects.crit = crit
	effects.graze = graze
	if Run.card_level(&"armor_breaker") > 0:
		effects.break = maxf(effects.get("break", 0.0), Run.card_value(&"armor_breaker"))
	if Run.legend_on(&"pharaohs_gold") and randf() < 0.2:
		Run.galder += 4
		Events.text_shown.emit(e.global_position + Vector2(0, -60), "+4 G", Color(1.0, 0.85, 0.35))
	if crit:
		Audio.play("etc_critical.wav", -6.0)
		if Run.has_trait(&"lucky_strikes") and randf() < 0.3:
			Run.ore += 1
			Events.loot_found.emit("+1 " + Run.ORE_NAME)
	var origin := global_position if from == Vector2.INF else from
	e.take_hit(amount, Combat.ground(e.global_position - origin).normalized(), knockback, heavy, effects)
	return crit


# ---------------------------------------------------------------- dash

func can_dash() -> bool:
	return now() >= dash_ready_at


func start_dash() -> void:
	var input := move_input()
	_dash_dir = input.normalized() if input != Vector2.ZERO else Combat.screen(aim).normalized()
	# Vault over obstacles when there's open ground to land on past them.
	var reach := dash_distance * (1.25 if Run.quirk(&"long_dash") else 1.0)
	var vault := room.vault_distance(global_position, _dash_dir, reach, vault_extra)
	_vaulting = vault > 0.0
	_dash_len = dash_time * (vault / dash_distance if _vaulting else reach / dash_distance)
	set_collision_mask_value(1, not _vaulting)
	dash_ready_at = now() + _dash_len + dash_cooldown * Run.dash_cooldown_mult()
	_perfect_this_dash = false
	if Run.card_level(&"shadow") > 0:
		_shadow_strike(global_position)
	invulnerable_until = maxf(invulnerable_until, now() + maxf(dash_invuln, _dash_len + 0.05))
	set_phasing(true)  # pass through enemies, and don't shove them, while dashing
	_hit_this_dash.clear()
	enter(State.DASH)
	var anim := "dodge" if sprite.has_action("dodge") else "run"
	sprite.play_action(anim, _dash_dir, _dash_len, true)
	Ring.spawn(room.ground_fx, global_position, 18.0, 0.25, Color(1, 1, 1, 0.6))
	Audio.play("etc_miss.wav", -8.0)


func _state_dash() -> void:
	velocity = _dash_dir * (dash_distance / dash_time)
	if Run.has_trait(&"dash_casting") and not _vaulting:
		for i in SkillCaster.SLOT_ACTIONS.size():
			if take_buffer(SkillCaster.SLOT_ACTIONS[i]) and skills.try_cast(i):
				return
	if Run.card_level(&"counter_punch") > 0:
		for e in room.enemies:
			if e.is_hittable() and not e in _hit_this_dash and _touching(e, 8.0):
				_hit_this_dash.append(e)
				deal_hit(e, Run.card_value(&"counter_punch"), Run.attack_mult(), 120.0, false)
				Audio.play(ComboAttack.HIT_SOUNDS[0], -4.0)
				Events.hitstop_requested.emit(0.03)
	if _vaulting:
		sprite.position.y = -sin(PI * clampf(_t / _dash_len, 0.0, 1.0)) * VAULT_HOP
	if _t >= _dash_len:
		_end_vault()
		enter(State.MOVE)
		if not try_actions():
			_state_move()


## Shadow: a moment after a dash starts, the shadow left behind slashes.
func _shadow_strike(at: Vector2) -> void:
	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree() or room == null:
		return
	Slash.spawn(room, at + Vector2(0, -14), {"radius": SHADOW_RADIUS, "arc": TAU * 0.8, "dir": aim, "clockwise": true,
		"sweep_time": 0.12, "life": 0.3, "width": 16.0, "color": Color(0.45, 0.4, 0.7)})
	for e in room.enemies:
		if e.is_hittable() and Combat.in_circle(at, e.global_position, SHADOW_RADIUS, e.body_radius):
			deal_hit(e, Run.card_value(&"shadow"), Run.attack_mult(), 120.0, false, {}, at)


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


# ---------------------------------------------------------------- damage taken

## `magic` hits are reduced by MD instead of DP; `accuracy` is the
## attacker's AC, against the player's evasion.
func take_hit(amount: int, from_dir: Vector2, knockback: float, magic := false, accuracy := 50) -> void:
	if is_invulnerable():
		if state == State.DASH and Run.has_trait(&"perfect_dodge") and not _perfect_this_dash:
			_perfect_this_dash = true
			dash_ready_at = now()
			Events.text_shown.emit(global_position + Vector2(0, -70), "Perfect dodge", Color(1.0, 0.9, 0.5))
			Ring.spawn(room.ground_fx, global_position, 40.0, 0.3, Color(1.0, 0.9, 0.5, 0.9))
		return
	if randf() < Run.evade_chance(accuracy):
		invulnerable_until = now() + 0.25
		Events.text_shown.emit(global_position + Vector2(0, -70), "Evade", Color(0.75, 0.95, 1.0))
		Audio.play("etc_miss.wav", -8.0)
		return
	amount = maxi(1, roundi(amount * Run.damage_taken_mult(magic) * (0.75 if magic and Run.quirk(&"umbrella") else 1.0)))
	Run.take_damage(amount)
	Events.damage_shown.emit(global_position + Vector2(0, -70), amount, Color(1.0, 0.45, 0.4), false)
	Audio.play("shchr002.wav", -6.0)
	Events.hitstop_requested.emit(0.06)
	Events.shake_requested.emit(5.0)
	invulnerable_until = now() + hurt_invuln
	knock = Combat.screen(from_dir) * knockback
	if Run.hp <= 0 and Run.try_revive():
		# Rollback Cache or Second Wind: survive the blow, with a moment to recover.
		invulnerable_until = now() + 1.5
		Ring.spawn(room.ground_fx, global_position, 70.0, 0.5, Color(0.8, 0.6, 1.0, 0.9))
		Audio.play("eff_healing1.wav", -2.0)
		Events.revived.emit()
	if Run.hp <= 0:
		_die()
		return
	enter(State.HURT)
	sprite.play_action("hit", -Combat.screen(from_dir), 0.18, true)


func _die() -> void:
	enter(State.DEAD)
	velocity = Vector2.ZERO
	collision_layer = 0
	sprite.play_action("faint", Vector2.ZERO, 0.9, true)
	died.emit()
	Events.player_died.emit()


func _blink() -> void:
	var flicker := state != State.DASH and state != State.DEAD and now() < invulnerable_until
	sprite.modulate.a = 0.45 if flicker and int(now() * 20.0) % 2 == 0 else 1.0
