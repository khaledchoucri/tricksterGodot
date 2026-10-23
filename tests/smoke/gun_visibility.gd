extends SmokeSection
## Gun bursts obey cover before random target selection and again at each shot.
## A synchronous wait stub lets the test close cover between shots without advancing the game.

## Ours: a vertical wall at x=40 and optional complete occlusion form the test surface.
class WallRoom extends Room:
	var block_all := false

	func line_clear(from: Vector2, to: Vector2) -> bool:
		return not block_all and (from.x - 40.0) * (to.x - 40.0) >= 0.0


## Only the real player's tree membership and position are needed by the skill.
class InertPlayer extends Player:
	func _ready() -> void:
		pass


## Avoid texture loading while binding the real Player's child references.
class InertWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


## Run real burst targeting and firing, capture hits, and advance waits synchronously.
class CaptureSpray extends "res://scripts/skills/gun_spray.gd":
	var hits: Array[Enemy] = []
	var gun_flags_valid := true
	var close_cover := false

	func damage(scale := 1.0) -> float:
		return 100.0 * scale  # Damage scaling has separate regression coverage.

	func hit(enemy: Enemy, _amount: float, _knockback: float, _heavy := true,
			fx := {}, _from := Vector2.INF) -> void:
		hits.append(enemy)
		gun_flags_valid = gun_flags_valid and fx.get("gun", false)

	func wait_for(_seconds := 0.0) -> bool:
		if close_cover:
			(room as WallRoom).block_all = true
		return alive()


var _room: WallRoom
var _player: InertPlayer
var _targets: Array[Enemy] = []


## Both shared-behavior cards respect cover without changing caps, range or gun-hit flags.
func run() -> void:
	var rng_seed := Run.rng.seed
	var rng_state := Run.rng.state
	var lingering := Skill._lingering.size()
	for id: StringName in [&"shooting_spree", &"berserk"]:
		Run.rng.seed = 42
		_blocked(id)
		_cap(id)
		_mid_burst(id)
		_open_targets(id)
	_clean_up()
	check(Skill._lingering.size() == lingering, "visibility checks leave no lingering burst ownership")
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state


func _blocked(id: StringName) -> void:
	_fixture()
	_enemy(Vector2(80.0, 0.0))
	var skill := _cast(id, 2)
	check(skill.hits.is_empty(), "%s does not hit a target through the wall" % id)
	check(not skill in Skill._lingering, "%s with no visible targets finishes without lingering" % id)


func _cap(id: StringName) -> void:
	_fixture()
	var visible := _enemy(Vector2(20.0, 0.0))
	for i in 5:
		_enemy(Vector2(70.0 + i * 3.0, 0.0))
	var skill := _cast(id, 1)
	check(skill.hits.size() == 1 and skill.hits[0] == visible,
		"%s excludes occluded enemies before choosing its capped target" % id)


func _mid_burst(id: StringName) -> void:
	_fixture()
	_enemy(Vector2(20.0, 0.0))
	_enemy(Vector2(25.0, 0.0))
	var skill := _cast(id, 2, true)
	check(skill.hits.size() == 1, "%s rechecks cover before its second shot" % id)
	check(not skill in Skill._lingering, "%s releases ownership after a shot loses visibility" % id)


func _open_targets(id: StringName) -> void:
	_fixture()
	for i in 3:
		_enemy(Vector2(15.0 + i * 5.0, 0.0))
	var distant := _enemy(Vector2(0.0, 1000.0))
	var dead := _enemy(Vector2(10.0, 0.0))
	dead.state = Enemy.State.DEAD
	var skill := _cast(id, 2)
	check(skill.hits.size() == 2 and skill.hits[0] != skill.hits[1],
		"%s retains its target cap and one shot per chosen enemy" % id)
	check(not distant in skill.hits and not dead in skill.hits,
		"%s still excludes distant and dead enemies" % id)
	check(skill.gun_flags_valid, "%s retains gun damage flags on accepted shots" % id)


func _cast(id: StringName, limit: int, close_cover := false) -> CaptureSpray:
	var skill := CaptureSpray.new()
	skill.card = (load("res://data/skills/sense/%s.tres" % id) as CardData).duplicate()
	skill.card.table = skill.card.table.duplicate(true)
	skill.card.table["targets"] = [float(limit)]  # In-memory cap fixture; generated data is untouched.
	skill.player = _player
	skill.room = _room
	skill.close_cover = close_cover
	skill.start()
	return skill


func _fixture() -> void:
	_clean_up()
	_room = WallRoom.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_player = InertPlayer.new()
	_player.room = _room
	_child(ActorSprite.new(), "Sprite")
	_child(InertWeapon.new(), "Weapon")
	_child(Silhouette.new(), "Silhouette")
	_child(Camera2D.new(), "Camera")
	_child(ComboAttack.new(), "ComboAttack")
	_child(SkillCaster.new(), "SkillCaster")
	_room.add_child(_player)


func _child(node: Node, child_name: String) -> void:
	node.name = child_name
	_player.add_child(node)


func _enemy(at: Vector2) -> Enemy:
	var enemy := Enemy.new()  # Target geometry only; never enters the tree.
	enemy.state = Enemy.State.CHASE
	enemy.position = at
	_targets.append(enemy)
	_room.enemies.append(enemy)
	return enemy


func _clean_up() -> void:
	if is_instance_valid(_room):
		_room.free()
	for enemy: Enemy in _targets:
		enemy.free()
	_targets.clear()
