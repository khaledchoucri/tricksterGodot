class_name BossTutankhamen
extends Enemy
## Tutankhamen, the Desert Beach boss at the Pyramid Steps
## (scenes/boss_tutankhamen.tscn). Slams up close, fans curse bolts at a
## distance, drops three sand coffins around the player, and calls Basic
## Mummies at 66% and 33% HP, as his BossMonsterparamEx row summons.

const CURSE_COOLDOWN := 5.0
const CURSE_BOLTS := 5
const CURSE_SPREAD := 0.9  # radians across the fan
const CURSE_SPEED := 190.0
const COFFIN_COOLDOWN := 8.5
const COFFIN_RADIUS := 52.0
const COFFIN_DELAY := 1.0
const COFFIN_STAGGER := 0.35
const SUMMON_AT: Array[float] = [0.66, 0.33]
const LINES: Array[String] = [
	"Who walks upon my sands after the end of days?",
	"Rise, my servants. The intruder still breathes.",
	"The server forgets. The Pharaoh does not!",
]

var _curse_ready_at := 0.0
var _coffin_ready_at := 0.0
var _summons_done := 0


func _ready() -> void:
	super._ready()
	_curse_ready_at = now() + 3.0
	_coffin_ready_at = now() + 6.0
	Events.boss_spoke.emit(LINES[0])


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if now() >= _coffin_ready_at and room.request_attack_token(self):
		_sand_coffins()
		return
	if now() >= _curse_ready_at and dist > 110.0 and room.line_clear(global_position, player.global_position) \
			and room.request_attack_token(self):
		_curse()
		return
	super._state_chase()


## Fans bolts toward the player after a short wind-up.
func _curse() -> void:
	_curse_ready_at = now() + CURSE_COOLDOWN
	_attack_dir = Combat.ground(player.global_position - global_position).normalized()
	_enter(State.RECOVER, 0.9)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(_attack_dir), 0.9, true)
	var warn := Telegraph.make("wedge", 0.45, {"dir": _attack_dir, "radius": 120.0, "arc": CURSE_SPREAD + 0.3})
	room.add_ground_fx(warn, global_position)
	await get_tree().create_timer(0.45).timeout
	if state == State.DEAD or not is_inside_tree() or not is_instance_valid(room) or not is_instance_valid(player):
		return
	if is_instance_valid(warn):
		warn.trigger()
	Audio.play("samon021.wav", -4.0)
	for i in CURSE_BOLTS:
		var a := lerpf(-CURSE_SPREAD / 2.0, CURSE_SPREAD / 2.0, float(i) / (CURSE_BOLTS - 1))
		var p := PROJECTILE_SCENE.instantiate() as Projectile
		if p == null:
			return
		p.direction = Combat.screen(_attack_dir.rotated(a)).normalized()
		p.speed = CURSE_SPEED
		p.damage = damage
		p.accuracy = accuracy()
		p.room = room
		p.player = player
		p.position = global_position + Vector2(0, -30)
		room.world.add_child(p)
	room.release_attack_token(self)


## Three coffins snap shut one after another around the player.
func _sand_coffins() -> void:
	_coffin_ready_at = now() + COFFIN_COOLDOWN
	_enter(State.RECOVER, 0.8)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(Combat.ground(player.global_position - global_position)), 0.8, true)
	var spots: Array[Vector2] = [player.global_position]
	for i in 2:
		var off := Vector2.from_angle(randf() * TAU) * Vector2(90.0, 45.0)
		var p := player.global_position + off
		spots.append(p if room.is_walkable(p) else room.nearest_reachable(p))
	room.release_attack_token(self)
	for i in spots.size():
		_coffin(spots[i], COFFIN_DELAY + COFFIN_STAGGER * i)


func _coffin(at: Vector2, delay: float) -> void:
	var warn := Telegraph.make("circle", delay, {"radius": COFFIN_RADIUS})
	room.add_ground_fx(warn, at)
	await get_tree().create_timer(delay).timeout
	if state == State.DEAD or not is_inside_tree():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Ring.spawn(room.ground_fx, at, COFFIN_RADIUS, 0.4, Color("d8b56a"))
	Events.shake_requested.emit(4.0)
	Audio.play("dmg_normal_c.wav", -4.0)
	if is_instance_valid(player) and not player.is_invulnerable() \
			and Combat.in_circle(at, player.global_position, COFFIN_RADIUS, 10.0):
		player.take_hit(damage + 4, Combat.ground(player.global_position - at).normalized(), 260.0, true, accuracy())


func take_hit(amount: int, dir: Vector2, knockback: float, heavy: bool, fx := {}) -> void:
	super.take_hit(amount, dir, knockback * 0.2, heavy, fx)
	while _summons_done < SUMMON_AT.size() and hp > 0 and float(hp) / max_hp <= SUMMON_AT[_summons_done]:
		_summons_done += 1
		Events.boss_spoke.emit(LINES[mini(_summons_done, LINES.size() - 1)])
		room.summon(global_position, &"basic_mummy", 2 + _summons_done)
