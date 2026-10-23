extends Node
## Regression checks for deaths removing enemies while an attack traverses its targets.
## Runs the real attack, damage and room death handlers with inert actor sprites, without maps.
## Standalone: godot --headless --path . res://tests/combat/multi_target.tscn

## Standalone scenes own a throwaway profile and quit; the smoke runner calls run() directly.
@export var standalone := false

## Skip actor loading and automatic updates; combat methods remain the production Player's.
class FixturePlayer extends Player:
	func _ready() -> void:
		pass


## Keep production damage and death behavior without loading an actor or running AI.
class FixtureEnemy extends Enemy:
	func _ready() -> void:
		pass


## A real weapon's swing/carry state without loading a weapon texture.
class FixtureWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


var _failures := 0
var _room: Room
var _player: Player
var _targets: Array[Enemy] = []
var _deaths: Dictionary[int, int] = {}
var _spawn_on_death := false
var _newcomer: Enemy


func _ready() -> void:
	if standalone:
		Profile.use_path("user://multi_target_test_profile.json", true)
		_run_and_quit.call_deferred()


func _run_and_quit() -> void:
	var failures := run()
	print("\n%s: %d multi-target failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)


## Exercises lethal hits, survivor hit limits, re-entrant boss deaths and target additions.
func run() -> int:
	_failures = 0
	var previous_class := Profile.class_id
	var next_seed := Run.next_seed
	Profile.class_id = "buffalo"
	Events.enemy_died.connect(_record_death)
	_combo_deaths()
	_combo_survivors()
	_combo_boss()
	_combo_newcomer()
	_sonic_deaths()
	_sonic_limit()
	_fissure_deaths()
	_effect_deaths()
	_effect_survivors()
	_clean_up()
	Events.enemy_died.disconnect(_record_death)
	Profile.class_id = previous_class
	Run.next_seed = next_seed
	return _failures


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _fixture(hp := 1, count := 3) -> void:
	_clean_up()
	Run.new_run(42)
	Run.mp = 0
	_room = Room.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	_room.rect = Rect2(-1000, -1000, 2000, 2000)
	_room._cleared = true  # Exercise removal/counters without scheduling another encounter.
	add_child(_room)
	_room.world = Node2D.new()
	_room.add_child(_room.world)
	_room.ground_fx = Node2D.new()
	_room.add_child(_room.ground_fx)
	_player = FixturePlayer.new()
	_player.room = _room
	_player.combo = load("res://data/combos/sword.tres")
	_child(_player, ActorSprite.new(), "Sprite")
	_child(_player, FixtureWeapon.new(), "Weapon")
	_child(_player, Silhouette.new(), "Silhouette")
	_child(_player, Camera2D.new(), "Camera")
	_child(_player, ComboAttack.new(), "ComboAttack")
	_child(_player, SkillCaster.new(), "SkillCaster")
	_room.world.add_child(_player)
	_room.player = _player
	_player._steps = _player.combo.steps.duplicate()
	_player.aim = Vector2.RIGHT
	for i in count:
		_targets.append(_enemy(Vector2(8 + 6 * i, 0), hp))


func _child(parent: Node, child: Node, child_name: String) -> void:
	child.name = child_name
	parent.add_child(child)


func _enemy(at: Vector2, hp: int) -> Enemy:
	var e := FixtureEnemy.new()
	e.data = EnemyData.new()
	e.attack = AttackPattern.new()
	e.hp = hp
	e.max_hp = hp
	e.state = Enemy.State.CHASE
	e.room = _room
	e.player = _player
	e.position = at
	_child(e, ActorSprite.new(), "Sprite")
	_child(e, CollisionShape2D.new(), "Shape")
	_room.world.add_child(e)
	e.died.connect(_room._on_enemy_died)
	_room.enemies.append(e)
	_room.alive += 1
	# Keep optional hit bursts out of these actor-free combat checks.
	e.set_meta("hit_fx_at", Events.time + 1000.0)
	return e


func _record_death(e: Enemy) -> void:
	var id := e.get_instance_id()
	_deaths[id] = _deaths.get(id, 0) + 1
	if _spawn_on_death:
		_spawn_on_death = false
		_newcomer = _enemy(Vector2(10, 0), 1)


func _all_dead_once() -> bool:
	for e in _targets:
		if e.state != Enemy.State.DEAD or _deaths.get(e.get_instance_id(), 0) != 1:
			return false
	return true


func _combo_hit() -> void:
	_player.buffer_action("attack")
	_player.try_actions()
	_player.attack.update(0.1)


func _combo_deaths() -> void:
	_fixture()
	var outside := _enemy(Vector2(0, 300), 1)
	_combo_hit()
	_check(_all_dead_once() and _room.alive == 1, "one lethal combo swing kills all three nearby enemies exactly once")
	_check(outside.hp == 1 and _room.enemies == [outside], "lethal combo preserves out-of-range enemies and live counters")
	_check(Run.mp == 3 * Run.formulas.mp_per_hit(), "lethal combo restores MP for every struck enemy")


func _combo_survivors() -> void:
	_fixture(10000)
	_combo_hit()
	var after: Array[int] = []
	var hit_all := true
	for e in _targets:
		after.append(e.hp)
		hit_all = hit_all and e.hits_taken == 1
	_player.attack.update(0.0)
	var unchanged := true
	for i in _targets.size():
		unchanged = unchanged and _targets[i].hp == after[i] and _targets[i].hits_taken == 1
	_check(hit_all and unchanged, "surviving combo targets take one hit per active window")


func _combo_boss() -> void:
	_fixture()
	_targets[0].is_boss = true
	_combo_hit()
	_check(_all_dead_once() and _room.alive == 0 and _room.enemies.is_empty(),
		"a boss dying mid-swing removes its adds without duplicate deaths or stale targets")
	_check(Run.mp == Run.formulas.mp_per_hit(), "adds killed by boss cleanup are not credited as extra combo hits")


func _combo_newcomer() -> void:
	_fixture()
	_spawn_on_death = true
	_combo_hit()
	_check(_all_dead_once() and is_instance_valid(_newcomer) and _newcomer.hp == 1 and _room.enemies == [_newcomer],
		"an enemy added by a death callback is not retroactively included in the current damage pass")


func _skill(path: String) -> Skill:
	var c: CardData = load(path)
	var skill: Skill = c.behavior.new()
	skill.card = c
	skill.player = _player
	skill.room = _room
	skill.aim = Vector2.RIGHT
	return skill


func _sonic_deaths() -> void:
	_fixture()
	var skill := _skill("res://data/skills/power/sonic_slash.tres")
	skill.start()
	_player.position = Vector2(60, 0)
	skill.update(0.08, 0.08)
	_check(_all_dead_once() and _room.alive == 0, "Sonic Slash kills every enemy crossed in one lethal update")


func _sonic_limit() -> void:
	_fixture()
	var skill := _skill("res://data/skills/power/sonic_slash.tres")
	skill.card = skill.card.duplicate()
	skill.card.table = skill.card.table.duplicate(true)
	skill.card.table["targets"] = [2.0]
	skill.start()
	_player.position = Vector2(60, 0)
	skill.update(0.08, 0.08)
	skill.update(0.09, 0.01)
	_check(_deaths.size() == 2 and _targets[2].hp == 1 and _room.alive == 1,
		"Sonic Slash keeps its target cap across lethal updates")


func _fissure_deaths() -> void:
	_fixture()
	var skill := _skill("res://data/skills/magic/cleaving_terra.tres")
	skill.start()
	skill.update(0.14, 0.14)
	_check(_all_dead_once() and _room.alive == 0, "Cleaving Terra kills every enemy along its lethal fissure")


func _damage(e: Enemy) -> void:
	_player.deal_hit(e, 100.0, 1.0, 0.0, false)


func _effect(kind: String) -> Node2D:
	var effect: Node2D
	match kind:
		"wave":
			var wave := EnergyWave.new()
			wave.room = _room
			wave.speed = 0.0
			wave.on_hit = _damage
			effect = wave
		"blade":
			var blade := ThrownBlade.new()
			blade.room = _room
			blade.thrower = _player
			blade.distance = 0.0
			blade.on_hit = _damage
			effect = blade
		_:
			var tornado := Tornado.new()
			tornado.room = _room
			tornado.speed = 0.0
			tornado.on_hit = _damage
			effect = tornado
	_room.add_child(effect)
	return effect


func _effect_deaths() -> void:
	for kind: String in ["wave", "blade", "tornado"]:
		_fixture()
		var effect := _effect(kind)
		effect.call("_physics_process", 0.01)
		_check(_all_dead_once() and _room.alive == 0, "%s hits every enemy in a lethal damage tick" % kind)


func _effect_survivors() -> void:
	for kind: String in ["wave", "blade", "tornado"]:
		_fixture(10000)
		var effect := _effect(kind)
		effect.call("_physics_process", 0.01)
		effect.call("_physics_process", 0.01)
		var once := true
		for e in _targets:
			once = once and e.hits_taken == 1
		_check(once, "%s does not re-hit survivors before its next allowed tick" % kind)
		if kind == "wave":
			continue  # The wave hits once for its whole lifetime.
		effect.call("_physics_process", 0.3)
		var twice := true
		for e in _targets:
			twice = twice and e.hits_taken == 2
		_check(twice, "%s still re-hits survivors on its next allowed tick" % kind)


func _clean_up() -> void:
	if is_instance_valid(_room):
		_room.free()
	_targets.clear()
	_deaths.clear()
	_newcomer = null
	_spawn_on_death = false
