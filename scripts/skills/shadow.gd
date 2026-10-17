extends Skill
## Shadow (1501, Gladiator): shadows of you (the level's count) appear around
## the enemy nearest the cursor and strike it from every side at once.

const RANGE := 260.0
const RING := 46.0
const GAP := 0.08
const COLOR := Color(0.55, 0.45, 0.9)

var _target: Enemy
var _shadows: Array[ActorSprite] = []


func _init() -> void:
	duration = 0.5
	anim = "cast"
	dash_cancel_at = 0.3


func start() -> void:
	var pool := closest_in_circle(target, RANGE, 1)
	_target = pool[0] if pool.size() > 0 and pool[0].global_position.distance_to(player.global_position) <= RANGE * 1.4 else null
	Audio.play("snd_skl_common_ki.wav", -8.0)


func update(t: float, _delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_hittable():
		return
	var n := int(param("count", 1))
	for i in n:
		if once(t, 0.1 + GAP * i, "shadow%d" % i):
			var side := Vector2.from_angle(TAU * i / n + 0.4)
			var at := _target.global_position + Combat.screen(side) * RING
			_spawn_shadow(at, _target.global_position - at)
			Slash.spawn(room, _target.global_position + Vector2(0, -18), {"radius": 40.0, "arc": deg_to_rad(150.0),
				"dir": Combat.ground(-side), "clockwise": i % 2 == 0, "sweep_time": 0.05, "life": 0.2, "width": 12.0,
				"color": COLOR})
			player.deal_hit(_target, damage(), 1.0, 60.0, i == n - 1, {}, at)
			Audio.play(ComboAttack.HIT_SOUNDS[i % ComboAttack.HIT_SOUNDS.size()], -6.0)
			feedback(0.03, 2.0)


## A see-through copy of the character striking toward `facing`, fading out.
func _spawn_shadow(at: Vector2, facing: Vector2) -> void:
	var s := ActorSprite.new()
	room.world.add_child(s)
	s.setup(Run.actor())
	s.global_position = at
	s.modulate = Color(COLOR, 0.7)
	s.play_action("attack", facing, 0.3, true)
	var tw := s.create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)
