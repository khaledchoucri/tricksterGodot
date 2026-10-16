class_name Skill
extends RefCounted
## One cast of an active skill. The player creates it from the card's
## `behavior` script, fills in the fields below, calls start(), then
## update() every physics frame for `duration` seconds and finish() at the
## end (or when the cast is interrupted). Effects that outlive the cast
## (waves, thrown blades, tornadoes) are nodes added to the room.

var card: CardData
var level := 1
var player: Player
var room: Room
## Ground-plane aim, fixed when the cast starts.
var aim := Vector2.RIGHT
## World point under the cursor when the cast started.
var target := Vector2.ZERO

## How long the caster is busy, which animation plays, and when a dash may
## cancel the rest of it.
var duration := 0.4
var anim := "cast"
var anim_frames: Array = []
var dash_cancel_at := 0.2
var invulnerable := false

var _done: Dictionary = {}


## Damage for this cast: the card's value at its level, with skill bonuses.
func damage(scale := 1.0) -> float:
	return card.value_at(level) * scale * Run.skill_mult(card)


func start() -> void:
	pass


func update(_t: float, _delta: float) -> void:
	pass


## The caster's velocity during the cast.
func movement(_t: float) -> Vector2:
	return Vector2.ZERO


func finish() -> void:
	pass


# ---------------------------------------------------------------- helpers

## True once, the first time `t` reaches `when` (per `key`).
func once(t: float, when: float, key := "main") -> bool:
	if t < when or _done.has(key):
		return false
	_done[key] = true
	return true


func hit(e: Enemy, amount: float, knockback: float, heavy := true, fx := {}) -> void:
	player.deal_hit(e, amount, 1.0, knockback, heavy, fx, player.global_position)


func enemies_in_circle(center: Vector2, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in room.enemies:
		if e.is_hittable() and Combat.in_circle(center, e.global_position, radius, e.body_radius):
			out.append(e)
	return out


func enemies_in_wedge(origin: Vector2, dir: Vector2, radius: float, arc: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in room.enemies:
		if e.is_hittable() and Combat.in_wedge(origin, e.global_position, dir, radius, arc, e.body_radius):
			out.append(e)
	return out


func feedback(hitstop: float, shake: float) -> void:
	if hitstop > 0.0:
		Events.hitstop_requested.emit(hitstop)
	if shake > 0.0:
		Events.shake_requested.emit(shake)
