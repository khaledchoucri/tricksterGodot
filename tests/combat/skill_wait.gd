extends Node
## Regression checks for delayed skill effects across pause, resume and room teardown.
## The controller keeps running during pause; the caster uses inert visuals and real Skill waits.

## Standalone scenes quit; the smoke runner awaits run() directly.
@export var standalone := false

## Skip actor loading and automatic combat updates.
class FixturePlayer extends Player:
	func _ready() -> void:
		pass


## A real weapon node without texture loading.
class FixtureWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


var _failures := 0
var _finished: Dictionary[String, bool] = {}
var _results: Dictionary[String, bool] = {}
var _room: Room
var _skill: Skill


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if standalone:
		_run_and_quit.call_deferred()


func _run_and_quit() -> void:
	var failures := await run()
	print("\n%s: %d skill wait failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)


## Waits must freeze with gameplay, resume once, and reject a freed caster's room.
func run() -> int:
	_failures = 0
	_finished.clear()
	_results.clear()
	_fixture()
	var tree := get_tree()
	tree.paused = true
	var frozen_clock := Events.time
	_observe("timed", 0.1)
	_observe("frame", 0.0)
	await tree.create_timer(0.25, true, true).timeout
	_check(not _finished.has("timed"), "timed skill effects do not finish while paused")
	_check(not _finished.has("frame"), "frame-based skill effects do not finish while paused")
	_check(Events.time == frozen_clock, "the test paused the gameplay clock")
	tree.paused = false
	await tree.physics_frame
	await tree.physics_frame
	_check(_results.get("frame", false), "frame-based effects resume on an active physics frame")
	_check(not _finished.has("timed"), "paused time does not count toward a timed effect")
	await tree.create_timer(0.15, true, true).timeout
	_check(_results.get("timed", false), "timed effects resume after the remaining gameplay delay")
	_observe("partial", 0.24)
	await tree.create_timer(0.06, true, true).timeout
	tree.paused = true
	await tree.create_timer(0.3, true, true).timeout
	_check(not _finished.has("partial"), "pausing midway freezes the remaining delay")
	tree.paused = false
	await tree.create_timer(0.06, true, true).timeout
	_check(not _finished.has("partial"), "resuming preserves the remaining delay")
	await tree.create_timer(0.24, true, true).timeout
	_check(_results.get("partial", false), "a midway-paused effect eventually completes")
	_observe("gone", 0.05)
	_room.free()
	await tree.create_timer(0.1, true, true).timeout
	_check(_finished.has("gone") and not _results.get("gone", true),
		"a delayed effect returns false after room teardown")
	_check(not await _skill.wait_for(), "an already-freed caster rejects a new wait")
	_skill = null
	return _failures


func _observe(key: String, seconds: float) -> void:
	_results[key] = await _skill.wait_for(seconds)
	_finished[key] = true


func _fixture() -> void:
	_room = Room.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	var player := FixturePlayer.new()
	player.room = _room
	_child(player, ActorSprite.new(), "Sprite")
	_child(player, FixtureWeapon.new(), "Weapon")
	_child(player, Silhouette.new(), "Silhouette")
	_child(player, Camera2D.new(), "Camera")
	_child(player, ComboAttack.new(), "ComboAttack")
	_child(player, SkillCaster.new(), "SkillCaster")
	_room.add_child(player)
	_skill = Skill.new()
	_skill.player = player
	_skill.room = _room


func _child(parent: Node, node: Node, child_name: String) -> void:
	node.name = child_name
	parent.add_child(node)


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1
