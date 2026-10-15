class_name BossMole
extends Enemy
## Real Golden Mole, the Coral Beach boss. Mixes a close-range slam with a
## burrow ambush, and calls Torobbies at 66% and 33% HP. The HP-threshold
## summons mirror how BossMonsterparamEx scripts boss phases.

const SLAM_RANGE := 80.0
const BURROW_COOLDOWN := 6.5
const BURROW_TRACK := 1.0
const BURROW_LOCK := 0.45
const EMERGE_RADIUS := 64.0
const SUMMON_AT := [0.66, 0.33]
const LINES := ["Who's digging in MY beach?", "Kids! Get them!", "Still standing? Again!"]

var _burrowed := false
var _burrow_t := 0.0
var _burrow_ready_at := 0.0
var _ambush: Telegraph
var _summons_done := 0


func _ready() -> void:
	is_boss = true
	super._ready()
	_burrow_ready_at = _now() + 4.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func is_hittable() -> bool:
	return super.is_hittable() and not _burrowed


func _physics_process(delta: float) -> void:
	if _burrowed:
		_process_burrow(delta)
		return
	super._physics_process(delta)


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if _now() >= _burrow_ready_at and dist > SLAM_RANGE and arena.request_attack_token(self):
		_start_burrow()
		return
	super._state_chase()


func _start_burrow() -> void:
	_burrowed = true
	_burrow_t = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	arena.shake(3.0)
	arena.dust_burst(global_position)
	sprite.visible = false
	_ambush = Telegraph.make("circle", BURROW_TRACK + BURROW_LOCK, {"radius": EMERGE_RADIUS})
	arena.add_ground_fx(_ambush, player.global_position)


func _process_burrow(delta: float) -> void:
	_burrow_t += delta
	if _burrow_t < BURROW_TRACK and is_instance_valid(_ambush) and is_instance_valid(player):
		# The warning follows the player, then locks in place before the strike.
		_ambush.global_position = _ambush.global_position.lerp(player.global_position, minf(1.0, delta * 6.0))
	if _burrow_t >= BURROW_TRACK + BURROW_LOCK:
		_emerge()


func _emerge() -> void:
	_burrowed = false
	_burrow_ready_at = _now() + BURROW_COOLDOWN
	var spot: Vector2 = _ambush.global_position if is_instance_valid(_ambush) else global_position
	global_position = spot
	set_collision_layer_value(3, true)
	sprite.visible = true
	if is_instance_valid(_ambush):
		_ambush.trigger()
	arena.dust_burst(spot)
	arena.shake(6.0)
	if is_instance_valid(player) and Combat.in_circle(spot, player.global_position, EMERGE_RADIUS, 10.0) and not player.is_invulnerable():
		player.take_hit(damage + 6, Combat.ground(player.global_position - spot).normalized(), 320.0)
	arena.release_attack_token(self)
	_enter(State.RECOVER, 0.9)
	sprite.play_action("attack", Vector2(0, 1), 0.9, true)


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool) -> void:
	super.take_hit(amount, dir, knockback * 0.25, heavy)
	arena.update_boss_bar(self)
	while _summons_done < SUMMON_AT.size() and hp > 0 and float(hp) / max_hp <= SUMMON_AT[_summons_done]:
		_summons_done += 1
		arena.boss_speech(LINES[mini(_summons_done, LINES.size() - 1)])
		arena.summon_minions(global_position, 3)
