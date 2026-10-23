extends SmokeSection
## Rejected contacts must not generate hit rewards, consume hit windows or roll supplements.
## Uses real player, enemy, combo and skill damage with isolated run modules and inert actors.

## Skip actor setup while retaining the real damage and combo state handlers.
class InertPlayer extends Player:
	func _ready() -> void:
		pass


## Keep real damage acceptance without actor loading or automatic AI.
class InertEnemy extends Enemy:
	func _ready() -> void:
		pass


## Real weapon state without texture loading.
class InertWeapon extends HeldWeapon:
	func _ready() -> void:
		pass


var _room: Room
var _player: InertPlayer
var _enemy: InertEnemy


## Covers frozen/dead/spawning contacts, accepted reward controls, thawing and supplements.
func run() -> void:
	var saved: Dictionary = {}
	for key: String in ["jobs", "deck", "gear", "purse", "ref_stats", "_stats", "type_points", "_baseline", "form", "mp", "instinct"]:
		saved[key] = Run.get(key)
	var rng_seed := Run.rng.seed
	var rng_state := Run.rng.state
	var signals_blocked := Events.is_blocking_signals()
	Events.set_block_signals(true)  # These synchronous checks isolate combat from live presentation listeners.
	_install_run()
	_fixture()
	_rejected("frozen", Enemy.State.CHASE, true)
	_rejected("dead", Enemy.State.DEAD, false)
	_rejected("spawning", Enemy.State.SPAWN, false)
	_accepted()
	_combo_thaw()
	_skill_thaw()
	_room.free()
	for key: String in saved:
		Run.set(key, saved[key])
	Run.rng.seed = rng_seed
	Run.rng.state = rng_state
	Events.set_block_signals(signals_blocked)


func _rejected(label: String, state: Enemy.State, frozen: bool) -> void:
	_reset(state, frozen)
	var hp := _enemy.hp
	var rng_state := Run.rng.state
	var all_rejected := true
	for i in 64:
		all_rejected = not _player.deal_hit(_enemy, 10.0, 1.0, 0.0, false, {"force_crit": true}) and all_rejected
	check(_enemy.hp == hp and _enemy.hits_taken == 0, "%s contacts do not apply damage or hit accounting" % label)
	check(all_rejected, "%s contacts do not report a critical hit" % label)
	check(Run.purse.galder == 0 and Run.purse.ore == 0, "%s contacts generate no legendary Galder or critical ore" % label)
	check(Run.rng.state == rng_state, "%s contacts do not spend hit-resolution random rolls" % label)


func _accepted() -> void:
	_reset(Enemy.State.CHASE, false)
	_enemy.apply_debuff("hold", 1.0, 2.0)
	var hp := _enemy.hp
	for i in 64:
		_player.deal_hit(_enemy, 10.0, 1.0, 0.0, false, {"force_crit": true})
	check(_enemy.hp < hp and _enemy.hits_taken == 64, "held enemies still accept ordinary damage")
	check(Run.purse.galder > 0 and Run.purse.ore > 0, "accepted critical hits retain both seeded reward paths")
	_reset(Enemy.State.CHASE, true)
	hp = _enemy.hp
	_enemy.take_hit(20, Vector2.RIGHT, 0.0, false)
	check(_enemy.hp == hp, "direct incoming hits still honor frozen immunity")
	_enemy.debuffs["frozen"] = [1.0, _enemy.now() - 0.1]
	check(_player.deal_hit(_enemy, 10.0, 1.0, 0.0, false, {"force_crit": true}) and _enemy.hp < hp,
		"expired freezing restores normal critical damage")


func _combo_thaw() -> void:
	_reset(Enemy.State.CHASE, true)
	Run.mp = 0
	var hp := _enemy.hp
	var rng_state := Run.rng.state
	_player.attack.start(0)
	_player.attack.update(0.1)
	check(Run.mp == 0 and _enemy.hp == hp, "a combo against frozen immunity generates no MP")
	check(_player.attack._hit_this_window.is_empty(), "a frozen contact does not consume the combo's hit allowance")
	check(Run.rng.state == rng_state, "a blocked combo does not roll hit rewards")
	_enemy.debuffs["frozen"] = [1.0, _enemy.now() - 0.1]
	_player.attack.update(0.01)
	check(_enemy.hp < hp and Run.mp == Run.formulas.mp_per_hit(),
		"thawing within an active window allows one real hit and its MP reward")


func _skill_thaw() -> void:
	_reset(Enemy.State.CHASE, true)
	var source := JobData.new()
	source.passive_mods = {"contact_probe.fear_chance": 100.0, "contact_probe.fear_seconds": 3.0}
	Run.jobs = [source]
	var skill := Skill.new()
	skill.card = CardData.new()
	skill.card.id = &"contact_probe"
	skill.player = _player
	skill.room = _room
	var hp := _enemy.hp
	var rng_state := Run.rng.state
	skill.hit(_enemy, 10.0, 0.0, false)
	check(_enemy.hp == hp and Run.rng.state == rng_state,
		"a blocked skill does not roll supplements or damage rewards")
	check(skill._effect_hit.is_empty(), "a blocked skill does not consume its accepted-hit effect allowance")
	_enemy.debuffs["frozen"] = [1.0, _enemy.now() - 0.1]
	skill.hit(_enemy, 10.0, 0.0, false)
	check(_enemy.hp < hp and _enemy.debuff("fear") > 0.0 and _enemy in skill._effect_hit,
		"a thawed enemy accepts damage, its guaranteed supplement and hit effect allowance")


func _reset(state: Enemy.State, frozen: bool) -> void:
	Run.rng.seed = 42
	Run.purse = RunPurse.new()
	Run.jobs = []
	_enemy.debuffs.clear()
	_enemy.state = state
	_enemy.hp = 1000000
	_enemy.hits_taken = 0
	_enemy.first_hit_at = -1.0
	if frozen:
		_enemy.apply_debuff("frozen", 1.0, 2.0)


func _install_run() -> void:
	Run.jobs = []
	Run.deck = RunDeck.new()
	Run.gear = RunGear.new()
	Run.gear.equipment["weapon"] = GearItem.make(load("res://data/items/golden_sword.tres"))
	Run.purse = RunPurse.new()
	Run.ref_stats = {"AP": 100, "MA": 100, "DA": 100, "DX": 10, "LK": 10, "HP": 1000, "MP": 1000, "WT": 100000}
	Run._stats = Run.ref_stats.duplicate()
	Run.type_points = {"power": 0, "magic": 0, "sense": 10, "charm": 0}
	Run._baseline = true
	Run.form = &""
	Run.instinct = false


func _fixture() -> void:
	_room = Room.new()
	_room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_room)
	_player = InertPlayer.new()
	_player.room = _room
	_player.combo = load("res://data/combos/punch.tres")
	_player._steps = _player.combo.steps.duplicate()
	_player.aim = Vector2.RIGHT
	_child(_player, ActorSprite.new(), "Sprite")
	_child(_player, InertWeapon.new(), "Weapon")
	_child(_player, Silhouette.new(), "Silhouette")
	_child(_player, Camera2D.new(), "Camera")
	_child(_player, ComboAttack.new(), "ComboAttack")
	_child(_player, SkillCaster.new(), "SkillCaster")
	_room.add_child(_player)
	_enemy = InertEnemy.new()
	_enemy.room = _room
	_enemy.player = _player
	_enemy.state = Enemy.State.CHASE
	_enemy.position = Vector2(20.0, 0.0)
	_enemy.attack = AttackPattern.new()
	_enemy.attack.poise = -1
	_enemy.set_meta("hit_fx_at", Events.time + 1000.0)
	_child(_enemy, ActorSprite.new(), "Sprite")
	_child(_enemy, CollisionShape2D.new(), "Shape")
	_room.add_child(_enemy)
	_room.enemies.append(_enemy)


func _child(parent: Node, node: Node, child_name: String) -> void:
	node.name = child_name
	parent.add_child(node)
