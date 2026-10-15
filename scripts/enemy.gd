class_name Enemy
extends CharacterBody2D
## Data-driven Coral Beach monster. Stats and movement come from the original
## MonsterParamEx2 row (via original_assets/data/monsters.json); the attack
## pattern and its wind-up are new, since MMO monsters attacked instantly.

signal died(enemy: Enemy)

enum State { SPAWN, IDLE, CHASE, WINDUP, ATTACK, RECOVER, HURT, DEAD }

## Attack patterns. "poise" is how many hits it shrugs off before staggering
## (0 = every hit staggers, -1 = never staggers).
const KINDS := {
	"melee": {"range": 42.0, "windup": 0.6, "active": 0.12, "recover": 0.55, "shape": "wedge",
		"radius": 54.0, "arc": 100.0, "poise": 0},
	"lunge": {"range": 150.0, "windup": 0.75, "active": 0.32, "recover": 0.7, "shape": "lane",
		"length": 160.0, "width": 36.0, "poise": 0},
	"slam": {"range": 70.0, "windup": 0.9, "active": 0.1, "recover": 0.85, "shape": "circle",
		"radius": 78.0, "poise": -1},
}

var monster_id := ""
var display_name := ""
var actor := ""
var kind := "melee"
var max_hp := 60
var hp := 60
var damage := 8
var walk_speed := 70.0
var run_speed := 105.0
var body_radius := 14.0
var idle_stay := Vector2(3, 5)
var is_boss := false

var state := State.SPAWN
var _t := 0.0
var _state_len := 0.0
var _attack_dir := Vector2.RIGHT
var _telegraph: Telegraph
var _knock := Vector2.ZERO
var _hits_taken := 0
var _attack_landed := false
var _wander_target := Vector2.ZERO

var sprite: ActorSprite
var arena
var player: Player


## Configure from a monsters.json entry. `scale` adjusts MMO numbers to action pacing.
func configure(id: String, data: Dictionary, p_actor: String, p_kind: String) -> void:
	monster_id = id
	actor = p_actor
	kind = p_kind
	display_name = data.get("name", p_actor.capitalize())
	var stats: Dictionary = data.get("stats", {})
	max_hp = int(round(float(stats.get("MAXHP", 100)) * 0.6))
	damage = int(round(6.0 + float(stats.get("AP", 4)) * 0.25))
	walk_speed = float(data.get("walk_speed", 86.0)) * 0.8
	run_speed = float(data.get("run_speed", 119.0)) * 0.9
	var stay: Array = data.get("idle_stay", [3, 5])
	idle_stay = Vector2(stay[0], stay[1])
	hp = max_hp


func _ready() -> void:
	add_to_group("enemies")
	arena = get_tree().get_first_node_in_group("arena")
	player = get_tree().get_first_node_in_group("player")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	sprite = ActorSprite.new()
	add_child(sprite)
	sprite.setup(actor)
	sprite.play_action("idle", Vector2(-1, 1))
	_enter(State.SPAWN, 0.5)
	sprite.modulate.a = 0.0


func is_hittable() -> bool:
	return state != State.DEAD and state != State.SPAWN


func _physics_process(delta: float) -> void:
	_t += delta
	_knock = _knock.move_toward(Vector2.ZERO, 700.0 * delta)
	match state:
		State.SPAWN:
			sprite.modulate.a = clampf(_t / _state_len, 0.0, 1.0)
			velocity = Vector2.ZERO
			if _t >= _state_len:
				_enter(State.CHASE)
		State.IDLE:
			_state_idle()
		State.CHASE:
			_state_chase()
		State.WINDUP:
			velocity = _knock
			if _t >= _state_len:
				_start_active()
		State.ATTACK:
			_state_attack()
		State.RECOVER:
			velocity = _knock
			if _t >= _state_len:
				_enter(State.CHASE)
		State.HURT:
			velocity = _knock
			if _t >= _state_len:
				_enter(State.CHASE)
		State.DEAD:
			velocity = _knock * 0.5
			if _t > 0.9:
				sprite.modulate.a = maxf(0.0, 1.0 - (_t - 0.9) / 0.5)
			if _t > 1.4:
				queue_free()
	move_and_slide()
	if sprite.modulate.r > 1.0:
		sprite.modulate = sprite.modulate.lerp(Color(1, 1, 1, sprite.modulate.a), minf(1.0, delta * 14.0))


func _state_idle() -> void:
	var to := _wander_target - global_position
	if to.length() > 6.0:
		velocity = to.normalized() * walk_speed + _knock
		sprite.play_action("walk", to)
	else:
		velocity = _knock
		sprite.play_action("idle")
	if _t >= _state_len:
		_enter(State.CHASE)


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		_wander()
		return
	var cfg: Dictionary = KINDS[kind]
	var to := player.global_position - global_position
	var dist := Combat.ground(to).length()
	if dist <= cfg.range + body_radius and arena.request_attack_token(self):
		_start_windup()
		return
	velocity = to.normalized() * run_speed + _knock
	sprite.play_action("walk", to)
	sprite.speed_scale = 1.3


func _wander() -> void:
	_wander_target = global_position + Vector2(randf_range(-80, 80), randf_range(-40, 40))
	_enter(State.IDLE, randf_range(idle_stay.x, idle_stay.y))


func _start_windup() -> void:
	var cfg: Dictionary = KINDS[kind]
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.WINDUP, cfg.windup)
	_hits_taken = 0
	var opts := {"dir": _attack_dir}
	match cfg.shape:
		"circle":
			opts.radius = cfg.radius
		"wedge":
			opts.radius = cfg.radius
			opts.arc = deg_to_rad(cfg.arc)
		"lane":
			opts.length = cfg.length
			opts.width = cfg.width
	_telegraph = Telegraph.make(cfg.shape, cfg.windup, opts)
	arena.add_ground_fx(_telegraph, global_position)
	# Hold the first frames of the attack as an anticipation pose.
	sprite.play_action("attack", Combat.screen(_attack_dir), 0.0, true)
	sprite.pause()
	sprite.frame = 0


func _start_active() -> void:
	var cfg: Dictionary = KINDS[kind]
	_attack_landed = false
	_enter(State.ATTACK, cfg.active)
	sprite.play_action("attack", Combat.screen(_attack_dir), cfg.active + cfg.recover * 0.6, true)
	if is_instance_valid(_telegraph):
		_telegraph.trigger()
	if kind == "slam":
		arena.shake(3.0)


func _state_attack() -> void:
	var cfg: Dictionary = KINDS[kind]
	if kind == "lunge":
		velocity = Combat.screen(_attack_dir) * (cfg.length / cfg.active)
	else:
		velocity = Vector2.ZERO
	if not _attack_landed and is_instance_valid(player):
		var hit := false
		match cfg.shape:
			"wedge":
				hit = Combat.in_wedge(global_position, player.global_position, _attack_dir, cfg.radius, deg_to_rad(cfg.arc), 10.0)
			"circle":
				hit = Combat.in_circle(global_position, player.global_position, cfg.radius, 10.0)
			"lane":
				hit = Combat.in_circle(global_position, player.global_position, body_radius + 14.0)
		if hit and not player.is_invulnerable():
			_attack_landed = true
			player.take_hit(damage, Combat.ground(player.global_position - global_position).normalized(), 220.0)
	if _t >= _state_len:
		arena.release_attack_token(self)
		_enter(State.RECOVER, cfg.recover)


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool) -> void:
	if not is_hittable():
		return
	hp = maxi(hp - amount, 0)
	arena.damage_number(global_position + Vector2(0, -50), amount, Color(1, 0.93, 0.7) if heavy else Color.WHITE)
	sprite.modulate = Color(2.2, 2.2, 2.2, sprite.modulate.a)
	var poise: int = KINDS[kind].poise
	var armored := poise < 0 or (state == State.ATTACK and kind == "lunge")
	_knock = Combat.screen(dir) * knockback * (0.35 if armored else 1.0)
	if hp <= 0:
		_die(dir)
		return
	_hits_taken += 1
	if not armored and _hits_taken > poise:
		_cancel_attack()
		_enter(State.HURT, 0.28 if heavy else 0.2)
		sprite.play_action("hit", -Combat.screen(dir), 0.2, true)


func _cancel_attack() -> void:
	arena.release_attack_token(self)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()


func _die(dir: Vector2) -> void:
	_cancel_attack()
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	_knock = Combat.screen(dir) * 260.0
	sprite.play_action("faint", -Combat.screen(dir), 0.8, true)
	died.emit(self)


func _enter(s: State, length := 0.0) -> void:
	state = s
	_t = 0.0
	_state_len = length
