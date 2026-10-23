class_name Enemy
extends CharacterBody2D
## Data-driven Coral Beach monster (scenes/enemy.tscn). Stats, speed and
## rewards come from the original MonsterParamEx2 row; the attack pattern
## ("kind") and its wind-up come from its EnemyData, since MMO monsters
## attacked instantly.

signal died(enemy: Enemy)

enum State { SPAWN, IDLE, CHASE, WINDUP, ATTACK, RECOVER, HURT, DEAD }

## Loaded on first use, not preloaded: projectile.gd refers back to Enemy,
## and that cycle could leave a preloaded scene empty (Tutankhamen's curse
## once failed with "node count is 0").
static var _projectile_scene: PackedScene


static func projectile_scene() -> PackedScene:
	if _projectile_scene == null:
		_projectile_scene = load("res://scenes/projectile.tscn")
	return _projectile_scene
## Echoes keep the original formula: damage over it, HP per room of depth.
const DAMAGE_MULT := 1.25
const DEPTH_HP := 0.06

var data: EnemyData
var display_name := ""
## Its attack pattern, with its own overrides applied (a copy: elites and Heat change it).
var attack: AttackPattern
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
## Debuffs from skills and talents: key -> [value, until].
## "dp", "ac", "perception" and "luck" lower that stat by value %; "guard"
## (Guard Break) leaves it unable to evade and without DP; "pinned"
## (Suffocate) keeps it from hiding. From the Magic line: "dx" and "slow"
## slow it by value % (DX also slows its wind-ups); "ap" cuts its damage;
## "delay" doubles its wind-ups; "fear" stops it attacking; "hold" stops it
## moving and acting; "frozen" holds it and keeps it from being hurt;
## "resist_<Element>" lowers that resistance.
var debuffs: Dictionary = {}

## How opaque the client draws it: 1 - CharacterInfo TransRate / 100 (Punisher Aposis is a
## 30% see-through Aposis).
var opacity := 1.0
var _fidget_at := 0.0

@onready var sprite: ActorSprite = $Sprite
@onready var shape: CollisionShape2D = $Shape


func configure(p_data: EnemyData, stats_row: Dictionary, elite := false) -> void:
	data = p_data
	attack = data.attack.tuned(data.tune)
	body_radius = data.body_radius
	is_boss = data.is_boss
	is_elite = elite
	display_name = Run.formulas.monster_name(data) if data.display_name != "" or stats_row.is_empty() else stats_row.get("name", String(data.id).capitalize())
	stats = Stats.from_monster(stats_row.get("stats", {}))
	elements = stats_row.get("elements", {})
	opacity = 1.0 - float(stats_row.get("trans_rate", 0)) / 100.0
	# Deeper rooms field tougher monsters.
	if data.echo:
		max_hp = roundi(float(stats.get("HP", 100)) * 0.6 * data.hp_mult * (1.0 + DEPTH_HP * Run.route.depth))
		damage = roundi(Run.raw_hit(stats) * DAMAGE_MULT * (1.0 + 0.04 * Run.route.depth))
	else:
		# As tough as its original level makes it (Run.formulas.mob_hp), whatever the room.
		max_hp = roundi(Run.formulas.mob_hp(stats, Run.route.region) * data.hp_mult)
		damage = Run.formulas.mob_hit(stats, Run.route.region)
		if is_boss:
			# A boss's original level is far above its region's (Tutankhamen is
			# 71 among 18-33): it keeps its own HP, but wears the region's armour.
			var norm: Dictionary = Run.formulas.region_norm(Run.route.region)
			stats["DP"] = roundi(norm.DP)
			stats["MD"] = roundi(norm.MD)
	walk_speed = float(stats_row.get("walk_speed", 86.0)) * 0.8 * data.speed_mult
	run_speed = float(stats_row.get("run_speed", 119.0)) * 0.9 * data.speed_mult
	var stay: Array = stats_row.get("idle_stay", [3, 5])
	idle_stay = Vector2(stay[0], stay[1])
	var g: Array = stats_row.get("galder", [0, 20])
	rewards = {"exp": int(float(stats_row.get("exp", 100)) * 0.6),
		"tm": int(float(stats_row.get("tm", 30)) * Run.route.region.tm_scale),
		"galder": int(Run.rng.randi_range(int(g[0]), int(g[1])) * Run.route.region.galder_scale) if Run.rng.randf() < 0.6 else 0}
	if elite:
		display_name = "Elite " + display_name
		max_hp = int(max_hp * 2.5)
		damage = roundi(damage * 1.25)
		attack.windup *= 0.85
		attack.poise = -1 if attack.poise < 0 else attack.poise + 2
		for k: String in rewards:
			rewards[k] *= 2
	max_hp = roundi(max_hp * ServerSettings.monster_hp_mult())
	damage = roundi(damage * ServerSettings.monster_damage_mult())
	attack.windup *= ServerSettings.windup_mult()
	hp = max_hp


func _ready() -> void:
	add_to_group("enemies")
	(shape.shape as CircleShape2D).radius = body_radius
	sprite.setup(String(data.id))
	if data.echo:
		sprite.self_modulate = Color(0.7, 0.85, 1.4, 0.75)  # a ghost of a former player
	sprite.scale *= data.sprite_scale  # on top of its sheet's display_scale
	if is_elite:
		sprite.scale *= 1.25
		sprite.self_modulate = Color(1.2, 1.05, 0.7)
	sprite.self_modulate.a *= opacity
	sprite.play_action("idle", Vector2(-1, 1))
	_enter(State.SPAWN, 0.5)
	sprite.modulate.a = 0.0


## Galder this monster has stolen from you (EnemyData.steal_galder), returned when it dies.
var stolen := 0
## The colour of a theft and its return over your head.
const STOLEN_COLOR := Color(0.95, 0.8, 0.3)
## When the player first landed a hit and how many hits it took (tuning data).
var first_hit_at := -1.0
var hits_taken := 0


func now() -> float:
	return Events.time


## The element its attacks carry: the one it resists most, if any (the
## original tables give monsters resistances, not an attack element).
func attack_element() -> String:
	var best := ""
	for k: String in elements:
		if k == "Physical":
			continue  # a resistance only, never an element
		if float(elements[k]) > 0.0 and (best == "" or float(elements[k]) > float(elements[best])):
			best = k
	return best


## Resistance to an element, in % (the original FireR, WaterR...).
## The Soul Master's Gardens and Domains lower it while the monster stands in them.
func resist(element: String) -> float:
	return float(elements.get(element, 0)) - debuff("resist_" + element)


## Damage multiplier from this monster's DP (or MD against magic), against
## an attacker with `attack` AP (or MA). Defence weighs against the
## attacker's own stat, so outgrowing a monster also outgrows its armour
## (my reading: the original's formula is server-side).
func defense_mult(magic := false, attack := 100.0, keep := 1.0) -> float:
	var def := float(stats.get("MD" if magic else "DP", 0)) * keep
	if not magic:
		def *= 0.0 if debuff("guard") > 0.0 else 1.0 - debuff("dp") / 100.0
	else:
		def *= 1.0 - debuff("md") / 100.0  # Magic Def Breaker
	return attack / (attack + maxf(def, 0.0)) if attack > 0.0 else 1.0


## Gun hits meet HV instead of DP, at 30 per point against the attack's 20
## (the server's gun formula, 0x59d440); Lock-on lowers it.
const GUN_HV_WEIGHT := 1.5
## Reading: the original monsters' 자동행동 clip (idle_auto) is their fidget while they stand.
## Ours: how many seconds apart a standing monster plays it.
const FIDGET_EVERY := Vector2(3.0, 7.0)


func gun_defense_mult(attack: float) -> float:
	var hv := float(stats.get("HV", 0)) * (1.0 - debuff("hv") / 100.0) * GUN_HV_WEIGHT
	if debuff("guard") > 0.0:
		hv = 0.0
	return attack / (attack + maxf(hv, 0.0)) if attack > 0.0 else 1.0


## Chance an attack with accuracy `ac` only grazes this monster.
func evade_chance(ac: int) -> float:
	var hv := roundi(float(stats.get("HV", 0)) * (1.0 - debuff("hv") / 100.0))  # Lock-on
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
	if key in ["hold", "frozen", "fear"]:
		if is_boss:
			return  # bosses shrug off holds, as they do stuns
		if state == State.WINDUP or state == State.ATTACK:
			_cancel_attack()
			_enter(State.CHASE)
	debuffs[key] = [maxf(value, debuff(key)), now() + seconds]


## Burrowing and vanishing monsters check this first (Suffocate pins them).
func can_hide() -> bool:
	if debuff("pinned") > 0.0:
		return false
	# Revealing Eye: nothing hides within its radius of you.
	var eye := Run.mod("reveal_radius")
	return not (eye > 0.0 and is_instance_valid(player) and Combat.in_circle(global_position, player.global_position, eye))


## Held in place (Hinder Snare, ice, a rift): no AI movement or attacking.
## Forced knockback and pulls remain possible.
func is_held() -> bool:
	return debuff("hold") > 0.0 or debuff("frozen") > 0.0


## Movement speed factor from slows.
func speed_factor() -> float:
	return clampf(1.0 - (debuff("slow") + debuff("dx")) / 100.0, 0.2, 1.0)


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
	if is_held():
		velocity = _knock
		sprite.play_action("idle")
		return
	var to := _wander_target - global_position
	if to.length() > 6.0:
		velocity = to.normalized() * walk_speed + _knock
		sprite.play_action("walk", to)
	else:
		velocity = _knock
		_stand()
	if _t >= _state_len:
		_enter(State.CHASE)


## Stands idle, playing its fidget clip now and then.
func _stand() -> void:
	if sprite.action == "idle_auto" and sprite.is_playing():
		return
	if sprite.has_action("idle_auto") and now() >= _fidget_at:
		if _fidget_at > 0.0:
			sprite.play_once("idle_auto")
		_fidget_at = now() + randf_range(FIDGET_EVERY.x, FIDGET_EVERY.y)  # visual only
		if sprite.action == "idle_auto":
			return
	sprite.play_action("idle")


func _state_chase() -> void:
	if is_held():
		velocity = _knock
		sprite.play_action("idle")
		return
	if not is_instance_valid(player) or player.state == Player.State.DEAD or Run.hidden:
		_wander()  # Hide: they lose you
		return
	var to := player.global_position - global_position
	var dist := Combat.ground(to).length()
	if attack.ranged and dist < attack.keep_away:
		# Ranged enemies back away to keep their distance.
		var away := -to.normalized()
		if room.is_walkable(global_position + away * 24.0):
			velocity = away * walk_speed * speed_factor() + _knock
			sprite.play_action("walk", away)
			return
	# Entrancing Wink: an entranced monster can't cast its magic (its shots).
	var silenced := attack.ranged and debuff("silence") > 0.0
	if dist <= attack.range + body_radius and debuff("fear") <= 0.0 and not silenced and room.line_clear(global_position, player.global_position) \
			and room.request_attack_token(self):
		_start_windup()
		return
	var step := _steer_toward(player.global_position)
	velocity = step * run_speed * speed_factor() + _knock
	if sprite.has_action("run"):
		sprite.play_action("run", step if step != Vector2.ZERO else to)  # echoes run as players do
	else:
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
	_wander_target = global_position + Vector2(Run.rng.randf_range(-80, 80), Run.rng.randf_range(-40, 40))
	_enter(State.IDLE, Run.rng.randf_range(idle_stay.x, idle_stay.y))


func _start_windup() -> void:
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	# Sense Breaker dulls its perception: it takes longer to see an attack through.
	var windup: float = attack.windup * (1.0 + (debuff("perception") + debuff("dx")) / 100.0) * (2.0 if debuff("delay") > 0.0 else 1.0)
	_enter(State.WINDUP, windup)
	_hits_taken = 0
	var opts := {"dir": _attack_dir}
	match attack.shape:
		"circle":
			opts.radius = attack.radius
		"wedge":
			opts.radius = attack.radius
			opts.arc = deg_to_rad(attack.arc)
		"lane":
			opts.length = attack.length
			opts.width = attack.width
	_telegraph = Telegraph.make(attack.shape, windup, opts)
	room.add_ground_fx(_telegraph, global_position)
	# Hold the first frame of the attack as an anticipation pose.
	sprite.play_action("attack", Combat.screen(_attack_dir), 0.0, true)
	sprite.pause()
	sprite.frame = 0


func _start_active() -> void:
	_attack_landed = false
	_enter(State.ATTACK, attack.active)
	sprite.play_action("attack", Combat.screen(_attack_dir), attack.active + attack.recover * 0.6, true)
	if is_instance_valid(_telegraph):
		_telegraph.trigger()
	if attack.shakes:
		Events.shake_requested.emit(3.0)
	if attack.ranged:
		_fire()


func _fire() -> void:
	var p: Projectile = projectile_scene().instantiate()
	p.direction = Combat.screen(_attack_dir).normalized()
	p.speed = attack.shot_speed
	p.damage = maxi(1, roundi(damage * (1.0 - debuff("ma") / 100.0)))  # Magic Meltdown
	p.accuracy = accuracy()
	p.shooter = self
	p.room = room
	p.player = player
	p.position = global_position + Vector2(0, -18)
	room.world.add_child(p)


func _state_attack() -> void:
	if attack.dashes:
		velocity = Combat.screen(_attack_dir) * (attack.length / attack.active)
	else:
		velocity = Vector2.ZERO
	if not _attack_landed and not attack.ranged and is_instance_valid(player):
		var hit := false
		match attack.shape:
			"wedge":
				hit = Combat.in_wedge(global_position, player.global_position, _attack_dir, attack.radius, deg_to_rad(attack.arc), 10.0)
			"circle":
				hit = Combat.in_circle(global_position, player.global_position, attack.radius, 10.0)
			"lane":
				hit = Combat.in_circle(global_position, player.global_position, body_radius + 14.0)
		if hit and not player.is_invulnerable():
			_attack_landed = true
			var hp_before := Run.hp
			player.take_hit(damage, Combat.ground(player.global_position - global_position).normalized(), 220.0, false, accuracy(), self)
			if data.steal_galder > 0 and Run.hp < hp_before:
				_steal()
	if _t >= _state_len:
		room.release_attack_token(self)
		_enter(State.RECOVER, attack.recover)


## Drags the enemy this frame (screen-space velocity), e.g. toward a whirlwind.
func nudge(v: Vector2) -> void:
	_pull += v


## `fx` may hold "stun" (seconds), "break" (% bonus), "burn" (dps), "crit",
## "graze" and "debuffs" ({key: [value, seconds]}, see `debuffs`).
func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	if not is_hittable():
		return
	if debuff("frozen") > 0.0:
		return  # Icey Shackles: frozen solid, it can't be hurt
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
		# An expired burn cannot lend its strength or partial tick to a new one.
		if now() >= burn_until:
			burn_dps = 0.0
			_burn_tick = 0.0
		burn_until = now() + float(fx.get("burn_for", 3.0))
		burn_dps = maxf(burn_dps, fx.burn)
	var applied: Dictionary = fx.get("debuffs", {})
	for k: String in applied:
		apply_debuff(k, applied[k][0], applied[k][1])
	var armored: bool = attack.poise < 0 or (state == State.ATTACK and attack.dashes)
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
	elif not armored and _hits_taken > attack.poise:
		_cancel_attack()
		_enter(State.HURT, 0.28 if heavy else 0.2)
		# Reading: a graze is the monster half evading, so it shows its dodge clip (회피) if it has one.
		var react := "dodge" if fx.get("graze", false) and sprite.has_action("dodge") else "hit"
		sprite.play_action(react, -Combat.screen(dir), 0.2, true)


## Out cold for `seconds` without a hit (Skunk Pouch's stink). Bosses shrug
## it off, as they do stuns.
func faint(seconds: float) -> void:
	if not is_hittable() or is_boss:
		return
	_cancel_attack()
	_enter(State.HURT, seconds)
	sprite.play_action("hit", sprite.facing, 0.2, true)
	Events.text_shown.emit(global_position + Vector2(0, -60), "Faint", Color(0.75, 0.9, 0.45))


func _cancel_attack() -> void:
	room.release_attack_token(self)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()


## A thief's hit: takes up to `steal_galder` of your Galder, to give back when it dies.
func _steal() -> void:
	var took := mini(data.steal_galder, Run.purse.galder)
	if took <= 0:
		return
	Run.purse.galder -= took
	stolen += took
	Events.text_shown.emit(player.global_position + Vector2(0, -90), "-%d Galder" % took, STOLEN_COLOR)
	Events.loot_found.emit("%s stole %d Galder!" % [display_name, took])
	Audio.play("etc_money.wav", -8.0)


func _die(dir: Vector2) -> void:
	if stolen > 0:
		Run.purse.galder += stolen
		Events.text_shown.emit(global_position + Vector2(0, -60), "+%d Galder" % stolen, STOLEN_COLOR)
		Events.loot_found.emit("Got back %d Galder from %s." % [stolen, display_name])
		stolen = 0
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
