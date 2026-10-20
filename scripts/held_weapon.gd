class_name HeldWeapon
extends Sprite2D
## A weapon held in an actor's hand. It follows the hand socket of the frame
## on screen (ActorSprite.hand_socket) and is rotated by code, so it works in
## every direction and with any weapon sprite exported by
## tools/export_weapon.py. Carried, it points where the actor faces, tilted
## toward the ground; during a swing it sweeps the attack's arc on the ground
## plane, matching the hitbox and the Slash trail.

@export var weapon_name := "long_sword"
## Hand position used when a frame has no socket but a swing is running.
@export var fallback_hand := Vector2(0, -28)

var body: ActorSprite

var _blade_angle := 0.0   # angle of the blade inside the texture
var _grip := Vector2.ZERO
var _angle := 0.0         # current screen angle of the blade
var _swinging := false
var _swing_t := 0.0
var _swing := {}          # dir (ground), arc, clockwise, start, end
var _front := true
var _hand := Vector2.ZERO
var _lent := false


func _ready() -> void:
	body = get_parent().get_node("Sprite")
	use(weapon_name)


## Switches to another exported weapon sprite (original_assets/weapons/<name>).
func use(p_name: String) -> void:
	weapon_name = p_name
	var base := "res://original_assets/weapons/%s" % weapon_name
	if not FileAccess.file_exists(base + ".json"):
		push_warning("Missing weapon %s; run tools/setup_assets.py" % weapon_name)
		visible = false
		set_process(false)
		return
	set_process(true)
	texture = load(base + ".png")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	_grip = Vector2(info.grip[0], info.grip[1])
	_blade_angle = info.angle
	centered = false


## Sweeps across `arc` (radians, ground plane) centred on `ground_dir`,
## moving between `start` and `end` seconds from now and holding before and after.
func swing(ground_dir: Vector2, arc: float, clockwise: bool, start: float, end: float) -> void:
	_swinging = true
	_swing_t = 0.0
	_swing = {"dir": ground_dir.normalized(), "arc": arc, "cw": clockwise, "start": start,
		"end": maxf(end, start + 0.01), "from": _angle}


## Back to carrying the weapon.
func carry() -> void:
	_swinging = false


## Hides the weapon while it's away (thrown by Inferno Blade).
func lend() -> void:
	_lent = true


func give_back() -> void:
	_lent = false


## A worn slot that takes over from the hand: a gun is held in the hand while
## walking or hit, and drawn through its pivots in the gun poses (and idle).
var yield_to_worn := ""
## How steeply a carried weapon points at the ground: a blade hangs, a gun is
## held level, barrel forward.
var carry_tilt := 0.8


func _process(delta: float) -> void:
	var socket := body.hand_socket()
	if _lent or (socket.is_empty() and not _swinging) or (yield_to_worn != "" and body.worn_shown(yield_to_worn)):
		visible = false
		return
	var target: Vector2 = socket.get("hand", fallback_hand)
	# Ease the hand between poses so a change of facing doesn't pop the blade.
	_hand = target if not visible else _hand.lerp(target, minf(1.0, delta * 30.0))
	visible = true
	var hand := _hand
	if _swinging:
		_swing_t += delta
		if _swing_t < _swing.start:
			# Wind-up: ease from wherever the blade was into the start of the arc.
			var w: float = _swing_t / _swing.start
			_angle = lerp_angle(_swing.from, _swing_angle(0.0), w * (2.0 - w))
		else:
			_angle = _swing_angle(clampf((_swing_t - _swing.start) / (_swing.end - _swing.start), 0.0, 1.0))
		# Pointing away from the camera, the blade goes behind the body.
		_set_front(Vector2.from_angle(_angle).y > -0.3)
	else:
		_angle = lerp_angle(_angle, _carry_angle(hand), minf(1.0, delta * 18.0))
		_set_front(socket.get("front", true))
	_place(body.position + hand)


func _swing_angle(progress: float) -> float:
	var p := progress * progress * (3.0 - 2.0 * progress)  # ease in and out
	var half: float = _swing.arc / 2.0
	var a: float = _swing.dir.angle() + (lerpf(-half, half, p) if _swing.cw else lerpf(half, -half, p))
	return Combat.screen(Vector2.from_angle(a)).angle()


## Forward along the facing, tilted toward the ground and out to the hand's side.
func _carry_angle(hand: Vector2) -> float:
	var f := body.facing.normalized()
	var side := signf(hand.x) * 0.35 if absf(f.x) < 0.5 else 0.0
	return (f * 0.6 + Vector2(side, carry_tilt)).angle()


func _place(at: Vector2) -> void:
	# Mirror the texture when pointing left so the art stays the right way up.
	var left := cos(_angle) < 0.0
	flip_v = left
	var grip := Vector2(_grip.x, texture.get_height() - _grip.y) if left else _grip
	var art_angle := -_blade_angle if left else _blade_angle
	offset = -grip
	rotation = _angle - art_angle
	position = at


func _set_front(front: bool) -> void:
	if front == _front:
		return
	_front = front
	# Children draw in order: last is over the body, first is under it.
	get_parent().move_child(self, -1 if front else 0)
