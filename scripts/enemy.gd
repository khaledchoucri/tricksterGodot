class_name Enemy
extends CharacterBody2D
## Data-driven Coral Beach monster (scenes/enemy.tscn). Stats, speed and
## rewards come from the original MonsterParamEx2 row; the attack pattern
## ("kind") and its wind-up come from its EnemyData, since MMO monsters
## attacked instantly.

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
	"spin": {"range": 56.0, "windup": 0.7, "active": 0.35, "recover": 0.6, "shape": "circle",
		"radius": 64.0, "poise": 1},
	"shot": {"range": 260.0, "windup": 0.7, "active": 0.05, "recover": 0.9, "shape": "lane",
		"length": 120.0, "width": 18.0, "poise": 0, "keep_away": 150.0, "shot_speed": 210.0},
}
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
## Echoes keep the original formula: damage over it, HP per room of depth.
const DAMAGE_MULT := 1.25
const DEPTH_HP := 0.06

var data: EnemyData
var display_name := ""
var cfg: Dictionary = {}
var max_hp := 60
var hp := 60
var damage := 8
## The original row's twelve stats (Stats.KEYS); DP/MD reduce damage taken,
## AC and HV decide grazes and evasion.
var stats: Dictionary = {}
var elements: Dictionary = {}
var walk_speed := 70.0
var run_speed := 105.0
var body_radius := 14.0
var idle_stay := Vector2(3, 5)
var is_boss := false
var is_elite := false
var rewards := {"exp": 0, "tm": 0, "galder": 0}

## Set by the room before the enemy enters the tree.
var room: Room
var player: Player

var state := State.SPAWN
var _t := 0.0
var _state_len := 0.0
var _attack_dir := Vector2.RIGHT
var _telegraph: Telegraph
var _knock := Vector2.ZERO
var _pull := Vector2.ZERO  # extra velocity for this frame (Tornado Bomb)
var _hits_taken := 0
var _attack_landed := false
var _wander_target := Vector2.ZERO
var _path := PackedVector2Array()
var _path_at := -10.0

# Status effects from skill cards.
var break_until := 0.0
var break_bonus := 0.0
var burn_until := 0.0
var burn_dps := 0.0
var _burn_tick := 0.0
## Debuffs from the Power line's breaker talents: key -> [value, until].
## "dp", "ac", "perception" and "luck" lower that stat by value %; "guard"
## (Guard Break) leaves it unable to evade and without DP; "pinned"
## (Suffocate) keeps it from hiding.
var debuffs: Dictionary = {}

@onready var sprite: ActorSprite = $Sprite
@onready var shape: CollisionShape2D = $Shape


func configure(p_data: EnemyData, stats_row: Dictionary, elite := false) -> void:
	data = p_data
	cfg = KINDS[data.kind].duplicate()
	cfg.merge(data.tune, true)
	body_radius = data.body_radius
	is_boss = data.is_boss
	is_elite = elite
	display_name = Run.monster_name(data) if data.display_name != "" or stats_row.is_empty() else stats_row.get("name", String(data.id).capitalize())
	stats = Stats.from_monster(stats_row.get("stats", {}))
	elements = stats_row.get("elements", {})
	# Deeper rooms field tougher monsters.
	if data.echo:
		max_hp = roundi(float(stats.get("HP", 100)) * 0.6 * data.hp_mult * (1.0 + DEPTH_HP * Run.depth))
		damage = roundi(Run.raw_hit(stats) * DAMAGE_MULT * (1.0 + 0.04 * Run.depth))
	else:
		# The original stats only say how this monster compares to the rest of
		# its region; the depth curve sets how tough a room is (Run.mob_ehp).
		max_hp = roundi(Run.mob_ehp(stats, Run.region, Run.depth) * data.hp_mult * defense_mult())
		damage = Run.mob_hit(stats, Run.region, Run.depth)
	walk_speed = float(stats_row.get("walk_speed", 86.0)) * 0.8 * data.speed_mult
	run_speed = float(stats_row.get("run_speed", 119.0)) * 0.9 * data.speed_mult
	var stay: Array = stats_row.get("idle_stay", [3, 5])
	idle_stay = Vector2(stay[0], stay[1])
	var g: Array = stats_row.get("galder", [0, 20])
	rewards = {"exp": int(float(stats_row.get("exp", 100)) * 0.6),
		"tm": int(float(stats_row.get("tm", 30)) * Run.region.tm_scale),
		"galder": int(randi_range(int(g[0]), int(g[1])) * Run.region.galder_scale) if randf() < 0.6 else 0}
	if elite:
		display_name = "Elite " + display_name
		max_hp = int(max_hp * 2.5)
		damage = roundi(damage * 1.25)
		cfg.windup *= 0.85
		cfg.poise = -1 if cfg.poise < 0 else cfg.poise + 2
		for k: String in rewards:
			rewards[k] *= 2
	max_hp = roundi(max_hp * ServerSettings.monster_hp_mult())
	damage = roundi(damage * ServerSettings.monster_damage_mult())
	cfg.windup *= ServerSettings.windup_mult()
	hp = max_hp


func _ready() -> void:
	add_to_group("enemies")
	(shape.shape as CircleShape2D).radius = body_radius
	sprite.setup(String(data.id))
	if data.echo:
		sprite.self_modulate = Color(0.7, 0.85, 1.4, 0.75)  # a ghost of a former player
	if is_elite:
		sprite.scale = Vector2(1.25, 1.25)
		sprite.self_modulate = Color(1.2, 1.05, 0.7)
	sprite.play_action("idle", Vector2(-1, 1))
	_enter(State.SPAWN, 0.5)
	sprite.modulate.a = 0.0


## When the player first landed a hit and how many hits it took (tuning data).
var first_hit_at := -1.0
var hits_taken := 0


func now() -> float:
	return Events.time


## Resistance to an element, in % (the original FireR, WaterR...).
func resist(element: String) -> float:
	return float(elements.get(element, 0))


## Damage multiplier from this monster's DP (or MD against magic).
func defense_mult(magic := false) -> float:
	var def := float(stats.get("MD" if magic else "DP", 0))
	if not magic:
		def *= 0.0 if debuff("guard") > 0.0 else 1.0 - debuff("dp") / 100.0
	return 100.0 / (100.0 + def)


## Chance an attack with accuracy `ac` only grazes this monster.
func evade_chance(ac: int) -> float:
	var hv: int = stats.get("HV", 0)
	if hv <= 0 or debuff("guard") > 0.0:
		return 0.0
	return hv / float(hv + ac + 150)


func accuracy() -> int:
	return roundi(stats.get("AC", 50) * (1.0 - debuff("ac") / 100.0))


## A debuff's value while it lasts, else 0.
func debuff(key: String) -> float:
	var d: Array = debuffs.get(key, [])
	return float(d[0]) if d.size() == 2 and now() < float(d[1]) else 0.0


## Applies or refreshes a debuff (the stronger value wins while both last).
func apply_debuff(key: String, value: float, seconds: float) -> void:
	debuffs[key] = [maxf(value, debuff(key)), now() + seconds]


## Burrowing and vanishing monsters check this first (Suffocate pins them).
func can_hide() -> bool:
	return debuff("pinned") <= 0.0


func is_hittable() -> bool:
	return state != State.DEAD and state != State.SPAWN


func _physics_process(delta: float) -> void:
	_t += delta
	_knock = _knock.move_toward(Vector2.ZERO, 700.0 * delta)
	_tick_status(delta)
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
		State.RECOVER, State.HURT:
			velocity = _knock
			if _t >= _state_len:
				_enter(State.CHASE)
		State.DEAD:
			velocity = _knock * 0.5
			if _t > 0.9:
				sprite.modulate.a = maxf(0.0, 1.0 - (_t - 0.9) / 0.5)
			if _t > 1.4:
				queue_free()
	if state != State.DEAD and state != State.SPAWN:
		velocity += _pull
	_pull = Vector2.ZERO
	move_and_slide()
	if sprite.modulate.r > 1.0:
		sprite.modulate = sprite.modulate.lerp(Color(1, 1, 1, sprite.modulate.a), minf(1.0, delta * 14.0))


func _tick_status(delta: float) -> void:
	if state == State.DEAD or now() >= burn_until:
		return
	_burn_tick += delta
	if int(now() * 10.0) % 2 == 0:
		sprite.modulate = Color(1.4, 0.9, 0.6, sprite.modulate.a)
	if _burn_tick < 0.5:
		return
	_burn_tick = 0.0
	var dmg := maxi(1, roundi(burn_dps * 0.5))
	hp = maxi(hp - dmg, 0)
	Events.damage_shown.emit(global_position + Vector2(0, -44), dmg, Color(1.0, 0.6, 0.25), false)
	if is_boss:
		Events.boss_health_changed.emit(self)
	if hp <= 0:
		_die(Vector2.DOWN)


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
	var to := player.global_position - global_position
	var dist := Combat.ground(to).length()
	if data.kind == "shot" and dist < cfg.keep_away:
		# Ranged enemies back away to keep their distance.
		var away := -to.normalized()
		if room.is_walkable(global_position + away * 24.0):
			velocity = away * walk_speed + _knock
			sprite.play_action("walk", away)
			return
	if dist <= cfg.range + body_radius and room.line_clear(global_position, player.global_position) \
			and room.request_attack_token(self):
		_start_windup()
		return
	var step := _steer_toward(player.global_position)
	velocity = step * run_speed + _knock
	sprite.play_action("walk", step if step != Vector2.ZERO else to)
	sprite.speed_scale = 1.3


## Direct line when it's clear, otherwise follow a grid path around obstacles.
func _steer_toward(target: Vector2) -> Vector2:
	if room.line_clear(global_position, target):
		_path = PackedVector2Array()
		return (target - global_position).normalized()
	if now() - _path_at > 0.35 or _path.is_empty():
		_path = room.find_path(global_position, target)
		_path_at = now()
	while _path.size() > 0 and global_position.distance_to(_path[0]) < 10.0:
		_path.remove_at(0)
	if _path.is_empty():
		return (target - global_position).normalized()
	return (_path[0] - global_position).normalized()


func _wander() -> void:
	_wander_target = global_position + Vector2(randf_range(-80, 80), randf_range(-40, 40))
	_enter(State.IDLE, randf_range(idle_stay.x, idle_stay.y))


func _start_windup() -> void:
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	# Sense Breaker dulls its perception: it takes longer to see an attack through.
	var windup: float = cfg.windup * (1.0 + debuff("perception") / 100.0)
	_enter(State.WINDUP, windup)
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
	_telegraph = Telegraph.make(cfg.shape, windup, opts)
	room.add_ground_fx(_telegraph, global_position)
	# Hold the first frame of the attack as an anticipation pose.
	sprite.play_action("attack", Combat.screen(_attack_dir), 0.0, true)
	sprite.pause()
	sprite.frame = 0


func _start_active() -> void:
	_attack_landed = false
	_enter(State.ATTACK, cfg.active)
	sprite.play_action("attack", Combat.screen(_attack_dir), cfg.active + cfg.recover * 0.6, true)
	if is_instance_valid(_telegraph):
		_telegraph.trigger()
	if data.kind == "slam":
		Events.shake_requested.emit(3.0)
	if data.kind == "shot":
		_fire()


func _fire() -> void:
	var p: Projectile = PROJECTILE_SCENE.instantiate()
	p.direction = Combat.screen(_attack_dir).normalized()
	p.speed = cfg.shot_speed
	p.damage = damage
	p.accuracy = accuracy()
	p.room = room
	p.player = player
	p.position = global_position + Vector2(0, -18)
	room.world.add_child(p)


func _state_attack() -> void:
	if data.kind == "lunge":
		velocity = Combat.screen(_attack_dir) * (cfg.length / cfg.active)
	else:
		velocity = Vector2.ZERO
	if not _attack_landed and data.kind != "shot" and is_instance_valid(player):
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
			player.take_hit(damage, Combat.ground(player.global_position - global_position).normalized(), 220.0, false, accuracy())
	if _t >= _state_len:
		room.release_attack_token(self)
		_enter(State.RECOVER, cfg.recover)


## Drags the enemy this frame (screen-space velocity), e.g. toward a whirlwind.
func nudge(v: Vector2) -> void:
	_pull += v


## `fx` may hold "stun" (seconds), "break" (% bonus), "burn" (dps), "crit",
## "graze" and "debuffs" ({key: [value, seconds]}, see `debuffs`).
func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	if not is_hittable():
		return
	if first_hit_at < 0.0:
		first_hit_at = now()
	hits_taken += 1
	if now() < break_until:
		amount = roundi(amount * (1.0 + break_bonus / 100.0))
	hp = maxi(hp - amount, 0)
	var crit: bool = fx.get("crit", false)
	var color := Color(1.0, 0.85, 0.2) if crit else (Color(1, 0.93, 0.7) if heavy else Color.WHITE)
	if fx.get("graze", false):
		color = Color(0.7, 0.72, 0.75)
	Events.damage_shown.emit(global_position + Vector2(0, -50), amount, color, crit)
	sprite.modulate = Color(2.2, 2.2, 2.2, sprite.modulate.a)
	if fx.has("break"):
		break_bonus = fx.break
		break_until = now() + 4.0
	if fx.has("burn"):
		burn_until = now() + 3.0
		burn_dps = maxf(burn_dps, fx.burn)
	var applied: Dictionary = fx.get("debuffs", {})
	for k: String in applied:
		apply_debuff(k, applied[k][0], applied[k][1])
	var armored: bool = cfg.poise < 0 or (state == State.ATTACK and data.kind == "lunge")
	_knock = Combat.screen(dir) * knockback * (0.35 if armored else 1.0)
	if is_boss:
		Events.boss_health_changed.emit(self)
	if hp <= 0:
		_die(dir)
		return
	_hits_taken += 1
	var stun: float = fx.get("stun", 0.0)
	if stun > 0.0 and not is_boss:
		_cancel_attack()
		_enter(State.HURT, stun)
		sprite.play_action("hit", -Combat.screen(dir), 0.2, true)
	elif not armored and _hits_taken > cfg.poise:
		_cancel_attack()
		_enter(State.HURT, 0.28 if heavy else 0.2)
		sprite.play_action("hit", -Combat.screen(dir), 0.2, true)


func _cancel_attack() -> void:
	room.release_attack_token(self)
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
	Events.enemy_died.emit(self)


func _enter(s: State, length := 0.0) -> void:
	state = s
	_t = 0.0
	_state_len = length
