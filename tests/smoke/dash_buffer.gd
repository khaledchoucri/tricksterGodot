extends SmokeSection
## Cooldown-blocked dash presses survive until readiness or the existing input-buffer expiry.
## Runs real input events, movement/combo/caster methods and dash activation on a controlled clock.

## Keep the real input/state/dash methods with deterministic movement input and clock.
class ClockPlayer extends Player:
	var clock := 10.0
	var dashes := 0

	func _ready() -> void:
		pass

	func now() -> float:
		return clock

	func move_input() -> Vector2:
		return Vector2.ZERO

	func start_dash() -> void:
		dashes += 1
		super.start_dash()


## No map is needed: dash normally without vaulting.
class OpenRoom extends Room:
	func vault_distance(_from: Vector2, _dir: Vector2, _dist: float, _extra: float) -> float:
		return 0.0


## Bind the real carry/swing methods without loading a texture.
class InertWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


## An inert active skill lets the checks distinguish casting from activation.
class ProbeSkill extends Skill:
	var starts := 0

	func _init() -> void:
		duration = 1.0
		dash_cancel_at = 0.02

	func start() -> void:
		starts += 1


var _room: OpenRoom
var _player: ClockPlayer
var _card: CardData


## Checks move, melee and skill paths, expiry, cancellation windows and replacement input.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["cls", "jobs", "deck", "ref_stats", "_stats", "type_points", "_baseline", "form", "mp", "instinct", "hidden"]:
		saved[key] = Run.get(key)
	Run.cls = load("res://data/classes/buffalo.tres")
	Run.jobs = []
	Run.deck = RunDeck.new()
	Run.ref_stats = {"AP": 10, "DX": 10, "HP": 1000, "MP": 1000}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	Run._baseline = true
	Run.form = &""
	Run.instinct = false
	_fixture()
	_move()
	_combo()
	_active_skill()
	_casting()
	_expired()
	_cancel_windows()
	_cast_completes()
	_replaced_input()
	_player.skills.stop()
	_room.free()
	for key: String in saved:
		Run.set(key, saved[key])


func _move() -> void:
	_reset()
	_press("dash")
	_player.clock += 0.03
	check(not _player.try_actions() and _player.state == Player.State.MOVE,
		"a dash on cooldown does not start early from MOVE")
	check(_player._buffered == "dash", "MOVE preserves the cooldown-blocked dash press")
	_player.clock += 0.1
	check(_player.try_actions() and _player.state == Player.State.DASH,
		"MOVE executes the still-fresh dash as cooldown finishes")
	check(_player.dashes == 1 and _player._buffered == "" and _player.dash_ready_at > _player.now(),
		"a queued dash executes once, consumes its input and starts normal cooldown")


func _combo() -> void:
	_reset()
	_player.attack.start(0)
	_press("dash")
	_player.clock += 0.09
	_player.attack.update(0.09)
	check(_player.state == Player.State.ATTACK and _player._buffered == "dash",
		"an open melee cancel window retains dash while its cooldown blocks it")
	_player.clock += 0.04
	_player.attack.update(0.04)
	check(_player.state == Player.State.DASH and _player.dashes == 1,
		"melee dash-cancels when cooldown finishes within the input buffer")


func _active_skill() -> void:
	_reset()
	check(_player.skills.try_cast(0), "the active-skill fixture casts")
	_press("dash")
	_player.clock += 0.03
	_player.skills.update(0.03)
	check(_player.state == Player.State.SKILL and _player._buffered == "dash",
		"an active skill retains dash while cooldown blocks its open cancel window")
	_player.clock += 0.1
	_player.skills.update(0.1)
	check(_player.state == Player.State.DASH and Run.mp == Run.max_mp - 30,
		"active-skill dash cancellation preserves its paid MP cost")


func _casting() -> void:
	_reset(0.8)
	check(_player.skills.try_cast(0), "the cast-time fixture casts")
	var skill := _player.skills._skill as ProbeSkill
	_press("dash")
	_player.clock += 0.03
	_player.skills.update(0.03)
	check(_player.skills.casting_left() > 0.0 and _player._buffered == "dash",
		"cast time preserves a cooldown-blocked dash through input dropping")
	_player.clock += 0.1
	_player.skills.update(0.1)
	check(_player.state == Player.State.DASH and skill.starts == 0,
		"a fresh dash cancels cast time before the skill activates")
	check(Run.mp == Run.max_mp and _player.skills.slot_ready_at[0] == 0.0,
		"dash cancellation during cast time retains its MP refund and cooldown reset")


func _expired() -> void:
	_reset()
	_press("dash")
	_player.try_actions()
	_player.clock += 0.23
	check(not _player.try_actions() and _player.dashes == 0,
		"a MOVE dash press still expires after the existing input-buffer limit")
	_reset(0.8)
	_player.skills.try_cast(0)
	_press("dash")
	_player.clock += 0.03
	_player.skills.update(0.03)
	_player.clock += 0.2
	_player.skills.update(0.2)
	check(_player.dashes == 0 and _player.skills.casting_left() > 0.0 and Run.mp == Run.max_mp - 30,
		"an expired dash does not cancel or refund a pending cast")


func _cancel_windows() -> void:
	_reset()
	_player.dash_ready_at = _player.now()
	_player.attack.start(0)
	_press("dash")
	_player.clock += 0.04
	_player.attack.update(0.04)
	check(_player.state == Player.State.ATTACK and _player._buffered == "dash",
		"dash readiness does not bypass a closed melee cancel window")
	_player.clock += 0.05
	_player.attack.update(0.05)
	check(_player.state == Player.State.DASH, "a buffered dash can execute when melee cancellation opens")


func _cast_completes() -> void:
	_reset(0.1)
	_player.skills.try_cast(0)
	var skill := _player.skills._skill as ProbeSkill
	_press("dash")
	_player.clock += 0.06
	_player.skills.update(0.06)
	_player.clock += 0.05
	_player.skills.update(0.05)
	check(skill.starts == 1 and _player.state == Player.State.SKILL,
		"a cast can finish normally while the queued dash is still on cooldown")
	_player.clock += 0.03
	_player.skills.update(0.03)
	check(_player.state == Player.State.DASH and Run.mp == Run.max_mp - 30,
		"dashing after cast completion does not retroactively refund the activated skill")


func _replaced_input() -> void:
	_reset()
	_press("dash")
	_player.try_actions()
	_press("attack")
	check(_player.try_actions() and _player.state == Player.State.ATTACK,
		"a newer attack still replaces a pending dash in the single-command buffer")
	_player.clock += 0.13
	_player.attack.update(0.13)
	check(_player.dashes == 0, "a replaced dash press does not execute later")


func _reset(cast_time := 0.0) -> void:
	_player.skills.stop()
	_player.enter(Player.State.MOVE)
	_player.clock = 10.0
	_player.dashes = 0
	_player.dash_ready_at = _player.now() + 0.12
	_player._buffered = ""
	_player.set_phasing(false)
	_player.skills.slot_ready_at[0] = 0.0
	_card.table = {"mp": [30.0], "cooldown": [1.0], "cast": [cast_time]}
	Run.mp = Run.max_mp


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_player._unhandled_input(event)


func _fixture() -> void:
	_card = CardData.new()
	_card.id = &"dash_buffer_probe"
	_card.kind = CardData.Kind.SKILL
	_card.behavior = ProbeSkill
	Run.deck.registry[_card.id] = _card
	Run.deck.cards[_card.id] = 1
	Run.deck.loadout[0] = _card.id
	_room = OpenRoom.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_room.ground_fx = Node2D.new()
	_room.add_child(_room.ground_fx)
	_player = ClockPlayer.new()
	_player.room = _room
	_player.combo = load("res://data/combos/punch.tres")
	_player._steps = _player.combo.steps.duplicate()
	_player.aim = Vector2.RIGHT
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
