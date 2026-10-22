extends SmokeSection
## Boss telegraphs, shots, summons and heals must wait for unpaused gameplay time.
## Calls the real boss routines with inert actors and captures their combat side effects.

## Count summons without requiring monster exports or encounter navigation.
class CaptureRoom extends Room:
	var summon_count := 0

	func summon(_at: Vector2, _id: StringName, count: int) -> void:
		summon_count += count


## Boss ready logic can use real sprite methods without loading an actor.
class InertSprite extends ActorSprite:
	func setup(_actor: String, _folder := Assets.ACTORS) -> bool:
		return true


## Only position, vulnerability and hit delivery are needed; never enters the tree.
class CapturePlayer extends Player:
	var hits := 0

	func is_invulnerable() -> bool:
		return false

	func take_hit(_amount: int, _dir: Vector2, _knockback: float, _magic := false,
			_accuracy := 50, _attacker: Enemy = null) -> void:
		hits += 1


## Keep the actual delayed attacks without automatic actor setup.
class FixtureTutankhamen extends BossTutankhamen:
	func _ready() -> void:
		pass


## Keep the actual delayed attacks without automatic actor setup.
class FixtureTombeth extends BossTombeth:
	func _ready() -> void:
		pass


## Keep Mong's real ready/summon timer; make the storm's hit deterministic.
class FixtureMong extends BossMong:
	func _lands(_apply: float) -> bool:
		return true


## Ours: enough paused time to exceed every delay exercised by the fixture.
const PAUSED_TIME := 1.8

var _room: CaptureRoom
var _player: CapturePlayer
var _tut: FixtureTutankhamen
var _tomb: FixtureTombeth
var _mong: FixtureMong


## All seven timer paths freeze, then resume; a midway pause preserves remaining windup.
func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_fixture()
	_start_attacks()
	var clock := Events.time
	var hp := _mong.hp
	await _wait(PAUSED_TIME)
	check(Events.time == clock, "boss timing test freezes the gameplay clock")
	check(_player.hits == 0, "paused coffins, Power Blow, Final Blow and Mana Storm deal no hits")
	check(_room.world.get_child_count() == 0, "paused curse windup emits no projectiles")
	check(_mong.hp == hp, "paused Cure restores no HP")
	check(_room.summon_count == 0, "Mong's opening summon does not happen while paused")
	check(_warnings(false) == 5, "all five telegraphs remain untriggered while paused")
	check(_room.attackers.size() == 3, "delayed attacks keep their tokens during pause")
	get_tree().paused = false
	await _wait(0.2)
	check(_player.hits == 0 and _room.world.get_child_count() == 0 and _mong.hp == hp
		and _room.summon_count == 0, "resuming does not spend the paused time on pending effects")
	await _wait(PAUSED_TIME)
	check(_player.hits == 4, "coffin, Power Blow, Final Blow and Mana Storm each deliver one resumed hit")
	check(_room.world.get_child_count() == BossTutankhamen.CURSE_BOLTS,
		"the resumed curse emits exactly its configured bolt count")
	check(_mong.hp == mini(_mong.max_hp, hp + roundi(_mong.max_hp * BossMong.HEAL_SHARE)),
		"the resumed Cure restores exactly its normal HP share")
	check(_room.summon_count == _mong.summon_start, "the resumed opening summon happens once")
	check(_warnings(true) == 5 and _room.attackers.is_empty(),
		"resumed attacks trigger their telegraphs and release their tokens")
	await _midway_pause()
	_room.free()
	_player.free()


func _midway_pause() -> void:
	_player.hits = 0
	_room.request_attack_token(_tomb)
	_tomb._final_blow()
	await _wait(0.25)
	get_tree().paused = true
	await _wait(PAUSED_TIME)
	check(_player.hits == 0, "pausing partway through Final Blow stops its pending hit")
	get_tree().paused = false
	await _wait(0.2)
	check(_player.hits == 0, "Final Blow retains its remaining windup after a midway pause")
	await _wait(BossTombeth.FINAL_WINDUP)
	check(_player.hits == 1, "a midway-paused Final Blow resumes exactly once")


func _start_attacks() -> void:
	_room.request_attack_token(_tut)
	_room.request_attack_token(_tomb)
	_room.request_attack_token(_mong)
	_tut._curse()
	_tut._coffin(_player.position, 0.7)
	_tomb._power_blow()
	_tomb._final_blow()
	_mong._mana_storm()
	_mong._cure()


func _fixture() -> void:
	_room = CaptureRoom.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_room.world = Node2D.new()
	_room.add_child(_room.world)
	_room.ground_fx = Node2D.new()
	_room.add_child(_room.ground_fx)
	_player = CapturePlayer.new()
	_player.position = Vector2(20.0, 0.0)
	_tut = FixtureTutankhamen.new()
	_tomb = FixtureTombeth.new()
	_mong = FixtureMong.new()
	_add_boss(_tut)
	_add_boss(_tomb)
	_add_boss(_mong)


func _add_boss(boss: Enemy) -> void:
	boss.room = _room
	boss.player = _player
	boss.data = EnemyData.new()
	boss.attack = AttackPattern.new()
	boss.is_boss = true
	boss.max_hp = 100
	boss.hp = 25
	var sprite := InertSprite.new()
	sprite.name = "Sprite"
	boss.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	shape.shape = CircleShape2D.new()
	boss.add_child(shape)
	_room.add_child(boss)


func _warnings(triggered: bool) -> int:
	var count := 0
	for child: Node in _room.ground_fx.get_children():
		if child is Telegraph and ((child as Telegraph)._flash >= 0.0) == triggered:
			count += 1
	return count


func _wait(seconds: float) -> void:
	# The test controller deliberately runs through pause to observe frozen gameplay.
	await get_tree().create_timer(seconds, true, true).timeout
