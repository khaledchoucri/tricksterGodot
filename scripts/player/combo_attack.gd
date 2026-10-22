class_name ComboAttack
extends Node
## The player's basic attack chain (a ComboData): plays each swing, applies
## its hit windows, spawns the sword trail, and hands control back to the
## player for chaining, dash-cancels and moving off.

const HIT_SOUNDS: Array[String] = ["dmg_normal_a.wav", "dmg_normal_b.wav", "dmg_normal_c.wav", "dmg_normal_d.wav"]
## The client's melee hit (MeleeAttack, 0x43f560 in Trickster.bin): each
## monster struck shows one of these, picked 50/50, with a dmg_normal sound.
const HIT_EFFECTS: Array[String] = ["hit", "hit star ting"]
## Our combo hits several times a second, far faster than the original's
## basic attack; overlapping bursts (additive, up to 230 px) wash out to white,
## so a monster shows at most one every this many seconds (my reading).
const HIT_EFFECT_GAP := 0.3

var step := 0
## Aim locked in for the current swing.
var swing_aim := Vector2.RIGHT

var _t := 0.0
var _window := -1
var _hit_this_window: Array[Enemy] = []

@onready var player: Player = get_parent()


func _steps() -> Array[ComboStep]:
	return player.combo_steps()


func start(index: int) -> void:
	step = index
	_t = 0.0
	_window = -1
	var s := _steps()[index]
	player.enter(Player.State.ATTACK)
	swing_aim = player.aim  # each swing commits to the aim it started with
	var speed := Run.formulas.attack_speed_mult()
	player.sprite.play_action(s.anim, Combat.screen(swing_aim), s.duration / speed, true, s.frame_range())
	if s.slash:
		var w := s.windows[0]
		player.weapon.swing(swing_aim, s.arc(), _clockwise(s), w.x / speed, w.y / speed)
	Audio.play(s.sound, -6.0)


## Runs one physics frame of the current swing.
func update(delta: float) -> void:
	_t += delta
	var s := _steps()[step]
	var speed := Run.formulas.attack_speed_mult()
	var t := _t * speed  # swing time at normal speed
	var lunge := s.lunge if t < s.windows[s.windows.size() - 1].y else 0.0
	player.velocity = Combat.screen(swing_aim) * lunge + player.knock
	for i in s.windows.size():
		var w := s.windows[i]
		if t >= w.x and t <= w.y:
			if _window != i:
				_window = i
				_hit_this_window.clear()
				if s.slash:
					_spawn_slash(s, (w.y - w.x) / speed)
			_apply(s)
	if t >= s.dash_cancel and player.can_dash() and player.take_buffer("dash"):
		player.start_dash()
		return
	if t >= s.chain_at and step + 1 < _steps().size() and player.take_buffer("attack"):
		start(step + 1)
		return
	if t >= s.free_at:
		if player.move_input() != Vector2.ZERO or t >= s.duration:
			player.enter(Player.State.MOVE)
		else:
			player.try_actions()


func _apply(s: ComboStep) -> void:
	var landed := false
	var crit_any := false
	for e in player.room.enemies:
		if e in _hit_this_window or not e.is_hittable():
			continue
		if Combat.in_wedge(player.global_position, e.global_position, swing_aim, _reach(s), s.arc(), e.body_radius):
			_hit_this_window.append(e)
			crit_any = player.deal_hit(e, s.damage, _mult(s), s.knockback, s.finisher, _talent_fx(s)) or crit_any
			if player.now() >= float(e.get_meta("hit_fx_at", -1.0)) + HIT_EFFECT_GAP:
				e.set_meta("hit_fx_at", player.now())
				Cake.play(player.room, HIT_EFFECTS[randi() % 2], e.global_position, {"follow": e})
			Run.gain_mp(Run.formulas.mp_per_hit())
			landed = true
	if landed:
		Audio.play(HIT_SOUNDS[randi() % HIT_SOUNDS.size()], -4.0)
		Events.hitstop_requested.emit(s.hitstop * (1.6 if crit_any else 1.0))
		Events.shake_requested.emit(4.5 if s.finisher else 2.5)


func _mult(s: ComboStep) -> float:
	var m := Run.formulas.attack_mult() * (1.0 + Run.mod("combo_damage%") / 100.0)
	if s.finisher:
		m = Run.mod_factor("finisher_damage%", false, m)
	return m


## Reach of a swing; Chi Sword makes the blade bigger.
func _reach(s: ComboStep) -> float:
	return s.reach * (1.0 + Run.mod("combo_reach%") / 100.0)


## Talent and trait effects carried by basic attacks.
func _talent_fx(s: ComboStep) -> Dictionary:
	var fx := {}
	if s.finisher:
		if Run.has_trait(&"staggering_finish"):
			fx.stun = maxf(fx.get("stun", 0.0), 0.35)
		if Run.has_trait(&"armor_crush"):
			fx.break = 25.0
	return fx


## The sword art strikes clockwise facing right and counter-clockwise facing
## left; blade and trail follow it.
func _clockwise(s: ComboStep) -> bool:
	return s.clockwise if swing_aim.x >= 0.0 else not s.clockwise


func _spawn_slash(s: ComboStep, sweep: float) -> void:
	Slash.spawn(player.room, player.global_position + Vector2(0, -16), {"radius": _reach(s), "arc": s.arc(),
		"dir": swing_aim, "clockwise": _clockwise(s), "sweep_time": maxf(sweep, 0.05), "life": sweep + 0.16,
		"width": 18.0 if s.finisher else 13.0})
