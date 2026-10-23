extends SmokeSection
## Combo hit windows must survive large physics steps, speed changes and overlapping windows.
## Captures contact from the real combo handler with inert visuals and isolated run modifiers.

## Record accepted contacts while keeping the real input/state and combo code.
class CapturePlayer extends Player:
	var hits := 0

	func _ready() -> void:
		pass

	func deal_hit(_enemy: Enemy, _base: float, _mult: float, _knock: float,
			_heavy: bool, _fx := {}, _from := Vector2.INF) -> bool:
		hits += 1
		return false


## Avoid texture loading while preserving swing and carry methods.
class InertWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


var _room: Room
var _player: CapturePlayer
var _target: Enemy
var _speed: JobData


## Exercises Bunny's real second swing and a deliberately overlapping fixture swing.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["jobs", "deck", "ref_stats", "_stats", "type_points", "_baseline", "form", "mp"]:
		saved[key] = Run.get(key)
	_speed = JobData.new()
	Run.jobs = [_speed]
	Run.deck = RunDeck.new()
	Run.ref_stats = {"AP": 10, "DX": 10, "MP": 100}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 0, "charm": 0}
	Run._baseline = true
	Run.form = &""
	_fixture()
	_crossed_windows()
	_continuous_windows()
	_speed_changes()
	_overlap_and_restart()
	_room.free()
	_target.free()
	for key: String in saved:
		Run.set(key, saved[key])


func _crossed_windows() -> void:
	_player.attack.start(1)
	_player.attack.update(0.21)
	check(_player.hits == 2, "one large frame still resolves both of Bunny's second-swing windows")
	var hits := _player.hits
	_player.attack.update(0.01)
	check(_player.hits == hits, "a completed window is not replayed on the following frame")
	_player.hits = 0
	_speed.passive_mods = {"attack_speed%": 300.0}
	_player.attack.start(1)
	_player.attack.update(0.06)
	check(_player.hits == 2, "high attack speed cannot skip both narrow windows")
	_speed.passive_mods = {}


func _continuous_windows() -> void:
	_player.hits = 0
	_player.attack.start(1)
	_player.attack.update(0.04)
	check(_player.hits == 0, "a swing does not hit before its first active window")
	_player.attack.update(0.03)
	_player.attack.update(0.02)
	check(_player.hits == 1, "several frames within one window still hit a target once")
	_player.attack.update(0.08)
	_player.attack.update(0.02)
	check(_player.hits == 2, "the second active window can hit the same target once again")
	_player.hits = 0
	_target.position = Vector2(5000.0, 0.0)
	_player.attack.start(1)
	_player.attack.update(0.11)
	_target.position = Vector2(20.0, 0.0)
	_player.attack.update(0.01)
	check(_player.hits == 0, "entering range after a window ends does not revive that window")
	_player.attack.update(0.05)
	check(_player.hits == 1, "a newly nearby target can be struck by the next window")


func _speed_changes() -> void:
	_player.hits = 0
	_player.attack.start(1)
	_player.attack.update(0.07)
	_speed.passive_mods = {"attack_speed%": 300.0}
	_player.attack.update(0.03)
	check(_player.hits == 2, "a mid-swing speed increase preserves the crossed second hit")
	_player.hits = 0
	_player.attack.start(1)
	_player.attack.update(0.045)
	var hits := _player.hits
	_speed.passive_mods = {}
	_player.attack.update(0.025)
	check(_player.hits == hits, "a speed decrease does not rewind completed hit windows")


func _overlap_and_restart() -> void:
	var step := ComboStep.new()
	step.windows = [Vector2(0.05, 0.2), Vector2(0.1, 0.25)]
	step.duration = 0.4
	step.free_at = 0.35
	_player._steps = [step]
	_player.hits = 0
	_player.attack.start(0)
	_player.attack.update(0.12)
	check(_player.hits == 2, "overlapping windows each own their target hit set")
	_player.attack.update(0.01)
	check(_player.hits == 2, "overlapping windows do not reset each other's hit sets every frame")
	var hits := _player.hits
	_player.attack.start(0)
	_player.attack.update(0.12)
	check(_player.hits == hits + 2, "a new swing clears every prior window's hit set")


func _fixture() -> void:
	_room = Room.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_player = CapturePlayer.new()
	_player.room = _room
	var combo: ComboData = load("res://data/combos/punch.tres")
	_player.combo = combo
	_player._steps = combo.steps.duplicate()
	_child(ActorSprite.new(), "Sprite")
	_child(InertWeapon.new(), "Weapon")
	_child(Silhouette.new(), "Silhouette")
	_child(Camera2D.new(), "Camera")
	_child(ComboAttack.new(), "ComboAttack")
	_child(SkillCaster.new(), "SkillCaster")
	_room.add_child(_player)
	_player.aim = Vector2.RIGHT
	_target = Enemy.new()
	_target.state = Enemy.State.CHASE
	_target.position = Vector2(20.0, 0.0)
	_target.set_meta("hit_fx_at", Events.time + 1000.0)
	_room.enemies.append(_target)


func _child(node: Node, child_name: String) -> void:
	node.name = child_name
	_player.add_child(node)
