extends Skill
## Galder Barrage (4102, Entertainer; borrowed through a rune): spend Galder to
## rain coins on the cursor. Hits harder the more Galder you carry, and
## scales with DP, like Charm skills.

const RADIUS := 90.0
const COST := 30
const HITS := 4
const GAP := 0.1
const COLOR := Color(1.0, 0.85, 0.35)

var _spot := Vector2.ZERO
var _bonus := 1.0


func _init() -> void:
	duration = 0.6
	anim = "throw"
	dash_cancel_at = 0.3


func start() -> void:
	_spot = target if room.is_walkable(target) else room.nearest_reachable(target)
	var paid := mini(COST, Run.galder)
	Run.galder -= paid
	_bonus = (0.5 + 0.5 * paid / float(COST)) * (1.0 + minf(Run.galder, 3000) / 3000.0)
	Audio.play("etc_money.wav", -2.0)


func update(t: float, _delta: float) -> void:
	for i in HITS:
		if once(t, 0.12 + GAP * i, "coin%d" % i):
			var at := _spot + Vector2(randf_range(-30, 30), randf_range(-15, 15))
			Sparks.burst(room, at + Vector2(0, -30), COLOR, 10, 160.0)
			Ring.spawn(room.ground_fx, at, RADIUS * 0.6, 0.25, Color(COLOR, 0.8))
			for e in enemies_in_circle(_spot, RADIUS):
				hit(e, damage(_bonus), 60.0, false)
			Audio.play("etc_money.wav", -10.0)
			feedback(0.02, 1.5)
