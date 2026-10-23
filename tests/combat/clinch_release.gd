extends Node
## Regression checks for stagger escapes: a rejected cast must leave the hit intact.
## Uses the real Player input buffer, SkillCaster and Clinch Release behavior, without maps.

## Standalone scenes use a throwaway profile; the smoke runner calls run() directly.
@export var standalone := false

## Inert visuals leave the production combat state machine available to the checks.
class FixturePlayer extends Player:
	func _ready() -> void:
		pass


## Avoid texture loading while preserving the real weapon state methods.
class FixtureWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


var _failures := 0
var _room: Room
var _player: Player


func _ready() -> void:
	if standalone:
		Profile.use_path("user://clinch_release_test_profile.json", true)
		_run_and_quit.call_deferred()


func _run_and_quit() -> void:
	var failures := run()
	print("\n%s: %d stagger escape failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)


## Covers insufficient MP, cooldown, and a paid successful cast from HURT.
func run() -> int:
	_failures = 0
	var previous_class := Profile.class_id
	var next_seed := Run.next_seed
	Profile.class_id = "buffalo"
	_fixture()
	Run.mp = 0
	_rejected("insufficient MP")
	Run.mp = Run.max_mp
	_player.skills.slot_ready_at[0] = _player.now() + 10.0
	_rejected("cooldown")
	_player.skills.slot_ready_at[0] = 0.0
	var mp := Run.mp
	var cost := _player.skills.cost_of(_player.skills.card_in(0), 1)
	_player.buffer_action("skill")
	_check(_player._clinch_release(), "an affordable ready cast succeeds while staggered")
	_check(_player.state == Player.State.SKILL and _player.knock == Vector2.ZERO,
		"successful Clinch Release enters SKILL and removes knockback")
	_check(Run.mp == mp - cost and _player.skills.slot_ready_at[0] > _player.now(),
		"successful escape pays MP and starts cooldown")
	_check(_player.invulnerable_until > _player.now() and _player._phasing,
		"successful escape grants its normal protection")
	_room.free()
	Profile.class_id = previous_class
	Run.new_run(42)  # Leave the normal starter loadout for the following smoke sections.
	Run.next_seed = next_seed
	return _failures


func _rejected(reason: String) -> void:
	_player.enter(Player.State.HURT)
	_player.knock = Vector2(-300.0, 0.0)
	_player._t = 0.06
	var mp := Run.mp
	var ready := _player.skills.slot_ready_at[0]
	var protection := _player.invulnerable_until
	_player.buffer_action("skill")
	_check(not _player._clinch_release(), "%s rejects the escape" % reason)
	_check(_player.state == Player.State.HURT and _player._t == 0.06,
		"%s preserves stagger and its elapsed recovery time" % reason)
	_check(_player.knock == Vector2(-300.0, 0.0), "%s preserves knockback" % reason)
	_check(Run.mp == mp and _player.skills.slot_ready_at[0] == ready
		and _player.invulnerable_until == protection and not _player._phasing,
		"%s leaves payment, cooldown and protection unchanged" % reason)


func _fixture() -> void:
	Run.new_run(42)
	Run.deck.cards[&"clinch_release"] = 1
	Run.deck.loadout[0] = &"clinch_release"
	_room = Room.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_room.ground_fx = Node2D.new()
	_room.add_child(_room.ground_fx)
	_player = FixturePlayer.new()
	_player.room = _room
	_child(ActorSprite.new(), "Sprite")
	_child(FixtureWeapon.new(), "Weapon")
	_child(Silhouette.new(), "Silhouette")
	_child(Camera2D.new(), "Camera")
	_child(ComboAttack.new(), "ComboAttack")
	_child(SkillCaster.new(), "SkillCaster")
	_room.add_child(_player)
	_room.player = _player


func _child(node: Node, child_name: String) -> void:
	node.name = child_name
	_player.add_child(node)


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1
