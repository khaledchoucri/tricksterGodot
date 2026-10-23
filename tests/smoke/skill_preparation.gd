extends SmokeSection
## Skill settings must be final before animation/protection; rejected casts must never prepare.
## Real SkillCaster entry points and Boxer Dash run with captured animation and inert actors.

## Record action timing without actor loading.
class CaptureSprite extends ActorSprite:
	var played := ""
	var played_for := 0.0

	func play_action(action_name: String, _direction := Vector2.ZERO, seconds := 0.0,
			_restart := false, _frames: Array = []) -> void:
		played = action_name
		played_for = seconds


## Real caster/state methods, without loading the character.
class InertPlayer extends Player:
	func _ready() -> void:
		pass


## Real carry state, without loading a weapon texture.
class InertWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


## Boxer Dash's target and recovery need no map in these checks.
class OpenRoom extends Room:
	func line_clear(_from: Vector2, _to: Vector2) -> bool:
		return true

	func is_walkable(_point: Vector2) -> bool:
		return true


## Records the public lifecycle contract through the real caster.
class ProbeSkill extends Skill:
	var preparations := 0
	var starts := 0
	var correct_order := false

	func _init() -> void:
		duration = 0.1

	func prepare() -> void:
		preparations += 1
		duration = 0.9
		anim = "attack2"
		invulnerable = true

	func start() -> void:
		starts += 1
		var sprite := player.sprite as CaptureSprite
		correct_order = preparations == 1 and sprite.played == anim 			and is_equal_approx(sprite.played_for, duration) and player._phasing 			and player.invulnerable_until >= player.now() + duration


var _room: OpenRoom
var _player: InertPlayer
var _sprite: CaptureSprite
var _target: Enemy


## Covers short/long dash timing, activation ordering, cast delay, rejection and cancellation.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["jobs", "deck", "ref_stats", "_stats", "type_points", "_baseline", "form", "mp", "instinct", "hidden"]:
		saved[key] = Run.get(key)
	var registry := Run.deck.registry.duplicate()
	Run.jobs = []
	Run.deck = RunDeck.new()
	Run.deck.registry = registry
	Run.ref_stats = {"AP": 10, "DX": 10, "HP": 1000, "MP": 1000}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	Run._baseline = true
	Run.form = &""
	Run.instinct = false
	_fixture()
	_dash(40.0, false)
	_dash(480.0, true)
	_probe_lifecycle()
	_player.skills.stop()
	_room.free()
	_target.free()
	for key: String in saved:
		Run.set(key, saved[key])


func _dash(distance: float, long_travel: bool) -> void:
	_reset()
	_target.position = Vector2(distance, 0.0)
	Run.deck.cards[&"boxer_dash"] = 1
	Run.deck.loadout[0] = &"boxer_dash"
	var mp := Run.mp
	var card := Run.deck.card(&"boxer_dash")
	check(_player.skills.try_cast(0), "Boxer Dash casts toward a target %d pixels away" % distance)
	var skill := _player.skills._skill
	check(skill.duration > 0.3 if long_travel else skill.duration < 0.3,
		"Boxer Dash computes its %s travel duration" % ("long" if long_travel else "short"))
	check(is_equal_approx(_sprite.played_for, skill.duration), "dash animation uses finalized travel duration")
	check(is_equal_approx(_player.invulnerable_until - _player.now(), skill.duration),
		"dash protection covers exactly its finalized duration")
	check(is_equal_approx(skill.dash_cancel_at, skill.duration), "dash cancel timing matches finalized travel")
	check(Run.mp == mp - card.mp_at(1) and _player.skills.slot_ready_at[0] > _player.now(),
		"preparation does not change dash payment or cooldown")


func _probe_lifecycle() -> void:
	_reset()
	var card := CardData.new()
	card.id = &"preparation_probe"
	card.kind = CardData.Kind.SKILL
	card.behavior = ProbeSkill
	card.table = {"mp": [10.0], "cooldown": [1.0], "cast": [0.2]}
	Run.deck.registry[card.id] = card
	Run.deck.cards[card.id] = 1
	Run.deck.loadout[0] = card.id
	check(_player.skills.try_cast(0), "probe begins its paid cast time")
	var skill := _player.skills._skill as ProbeSkill
	check(skill.preparations == 0 and skill.starts == 0, "cast time runs before preparation and effects")
	_player.skills.update(card.cast_at(1) + 0.01)
	check(skill.correct_order and skill.preparations == 1 and skill.starts == 1,
		"prepare runs once before animation, protection and activation")
	_reset()
	check(_player.skills.try_cast(0), "a second probe can begin casting")
	skill = _player.skills._skill as ProbeSkill
	_player.skills.cancel()
	check(skill.preparations == 0 and skill.starts == 0, "cancelling cast time never prepares or activates")
	check(Run.mp == Run.max_mp and _player.skills.slot_ready_at[0] == 0.0,
		"cancelled cast time still refunds MP and clears cooldown")
	Run.mp = 0
	check(not _player.skills.try_cast(0) and _player.skills._skill == null,
		"an unaffordable cast cannot create or prepare a skill")


func _reset() -> void:
	_player.skills.stop()
	_player.enter(Player.State.MOVE)
	_player.invulnerable_until = 0.0
	_player.set_phasing(false)
	_player.skills.slot_ready_at[0] = 0.0
	Run.mp = Run.max_mp


func _fixture() -> void:
	_room = OpenRoom.new()
	_room.rect = Rect2(-1000, -1000, 2000, 2000)
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_room.ground_fx = Node2D.new()
	_room.add_child(_room.ground_fx)
	_player = InertPlayer.new()
	_player.room = _room
	_player.aim = Vector2.RIGHT
	_sprite = CaptureSprite.new()
	_child(_sprite, "Sprite")
	_child(InertWeapon.new(), "Weapon")
	_child(Silhouette.new(), "Silhouette")
	_child(Camera2D.new(), "Camera")
	_child(ComboAttack.new(), "ComboAttack")
	_child(SkillCaster.new(), "SkillCaster")
	_room.add_child(_player)
	_target = Enemy.new()
	_target.state = Enemy.State.CHASE
	_room.enemies.append(_target)


func _child(node: Node, child_name: String) -> void:
	node.name = child_name
	_player.add_child(node)
