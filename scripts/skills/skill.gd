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
## Skills whose effects outlive the cast (a haunting, a rift, a snare) keep
## themselves alive here until they're done.
static var _lingering: Array[Skill] = []
var _effect_hit: Array[Enemy] = []  # enemies that have had this cast's hit effect


## Damage for this cast: the card's value at its level, with skill bonuses.
## What held supplements add to this skill's `effect` (Mod.SKILL_EFFECTS), e.g.
## Faint's stun chance on Shockwave.
func skill_mod(effect: String) -> float:
	return Run.mod("%s.%s" % [card.id, effect])


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

## Plays the card's original effects for `phase` ("ap" cast, "fl" flight,
## "ht" hit, "ke" lasting, "ed" end) at `at`; see Cake.play for `opts`.
## Returns the effects started (none when the original has none).
func effect(phase: String, at: Vector2, opts := {}) -> Array[Cake]:
	var out: Array[Cake] = []
	if not is_instance_valid(room):
		return out  # the room changed while a lingering effect waited
	for name: String in card.effects.get(phase, []):
		var c := Cake.play(room, name, at, opts)
		if c:
			out.append(c)
	return out


## Whether the card has an original effect for `phase` (behaviors then skip
## their own drawn stand-ins).
func has_effect(phase: String) -> bool:
	for name: String in card.effects.get(phase, []):
		if Cake.has(name):
			return true
	return false


## Keeps this skill alive after its cast for an effect that waits (await).
func linger() -> void:
	if not self in _lingering:
		_lingering.append(self)


## Ends linger().
func release() -> void:
	_lingering.erase(self)


## True while the caster is still in a running game: a room change or the
## end of a run frees it (and the room) under a lingering skill.
func alive() -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and is_instance_valid(room)


## Waits `seconds` (one physics frame when 0) on the game's clock; false when
## the caster's game is gone by then, so a lingering skill stops instead of
## touching freed nodes. Use as `if not await wait_for(t): ...`.
func wait_for(seconds := 0.0) -> bool:
	if not alive():
		return false
	var tree := player.get_tree()
	if seconds > 0.0:
		await tree.create_timer(seconds).timeout
	else:
		await tree.physics_frame
	return alive()


## True once, the first time `t` reaches `when` (per `key`).
func once(t: float, when: float, key := "main") -> bool:
	if t < when or _done.has(key):
		return false
	_done[key] = true
	return true


## A table number of this skill at its level (see CardData.table).
func param(name: String, default := 0.0) -> float:
	return card.param(name, level, default)


func hit(e: Enemy, amount: float, knockback: float, heavy := true, fx := {}, from := Vector2.INF) -> void:
	fx = fx.duplicate()
	if card.element != "none" and not fx.has("element"):
		fx.element = card.element
	fx.magic = card.scaling == "MA"  # spells meet MD, weapon skills DP
	fx.scaling = card.scaling  # defence weighs against the stat the skill uses
	amount *= 1.0 + Run.element_boost(card.element) / 100.0
	_supplements(fx, amount)
	player.deal_hit(e, amount, 1.0, knockback, heavy, fx, player.global_position if from == Vector2.INF else from)
	card.play("ht", -8.0)
	if not e in _effect_hit:
		_effect_hit.append(e)
		effect("ht", e.global_position, {"follow": e})
	if card.element == "Dark" and Run.mod("Dark.commando_damage") > 0.0:
		_commando(e)


## The original's support passives, each bound to one spell through its scoped mods
## (Water Web's "drip_bomb.dx_down"): whatever this skill's supplements add.
func _supplements(fx: Dictionary, amount: float) -> void:
	var debuffs: Dictionary = fx.get("debuffs", {}).duplicate()
	if skill_mod("dx_down") > 0.0:  # Water Web: the target's DX goes down
		debuffs["dx"] = [skill_mod("dx_down"), skill_mod("dx_seconds")]
	if skill_mod("stun") > 0.0:  # Electroshock: immobilized for a moment
		fx.stun = skill_mod("stun")
	if skill_mod("burn%") > 0.0:  # Wicked Flame: it keeps burning
		fx.burn = amount * skill_mod("burn%") / 100.0
		fx.burn_for = skill_mod("burn_seconds")
	if skill_mod("fear_seconds") > 0.0 and Run.rng.randf() * 100.0 < skill_mod("fear_chance"):  # Fear: no attacking
		debuffs["fear"] = [1.0, skill_mod("fear_seconds")]
	if not debuffs.is_empty():
		fx.debuffs = debuffs


## Dark Commando: the dark being follows a dark spell up on the same enemy.
func _commando(e: Enemy) -> void:
	linger()
	if await wait_for(0.25) and is_instance_valid(e) and e.is_hittable():
		# Dark Commando strikes as a spell of its own (MA, as every Dark spell).
		player.deal_hit(e, Run.mod("Dark.commando_damage") * Run.skill_mult(card), 1.0, 40.0, false, {"element": "Dark", "magic": true}, e.global_position)
		Sparks.burst(room, e.global_position + Vector2(0, -24), Color(0.5, 0.3, 0.7), 10, 120.0)
	release()


## Pick radius around the cursor for targeted spells.
const TARGET_SNAP := 110.0


## Where a spell aimed at the cursor lands. In Trickster these spells are
## cast on a monster you click, so it's the monster nearest the cursor (in
## range) if one is close, else the cursor, no further than the range.
func target_spot(default_range := 200.0) -> Vector2:
	var reach := param("range", default_range)
	var best: Enemy = null
	for e in room.enemies:
		if not e.is_hittable() or not Combat.in_circle(player.global_position, e.global_position, reach + 20.0):
			continue
		var d := Combat.ground(e.global_position - target).length()
		if d <= TARGET_SNAP and (best == null or d < Combat.ground(best.global_position - target).length()):
			best = e
	if best:
		return best.global_position
	var to := target - player.global_position
	var spot := player.global_position + to.limit_length(reach)
	return spot if room.is_walkable(spot) else room.nearest_reachable(spot)


## A spell's colour, by element.
const ELEMENT_COLORS := {"Fire": Color(1.0, 0.5, 0.2), "Water": Color(0.4, 0.7, 1.0), "Elec": Color(1.0, 0.95, 0.45),
	"Earth": Color(0.8, 0.62, 0.38), "Wind": Color(0.6, 1.0, 0.75), "Light": Color(1.0, 0.95, 0.75),
	"Dark": Color(0.6, 0.35, 0.85), "none": Color(0.6, 0.8, 1.0)}


func color() -> Color:
	return ELEMENT_COLORS.get(card.element, ELEMENT_COLORS.none)


## The enemy nearest `at` within `radius`, or null.
func nearest_to(at: Vector2, radius: float) -> Enemy:
	var pool := closest_in_circle(at, radius, 1)
	return pool[0] if pool.size() > 0 else null


## The enemy in the wedge closest to the caster, or null.
func nearest_in_wedge(dir: Vector2, radius: float, arc: float) -> Enemy:
	var best: Enemy = null
	for e in enemies_in_wedge(player.global_position, dir, radius, arc):
		if best == null or e.global_position.distance_squared_to(player.global_position) < best.global_position.distance_squared_to(player.global_position):
			best = e
	return best


## Up to `n` enemies in the circle, closest to `center` first.
func closest_in_circle(center: Vector2, radius: float, n: int) -> Array[Enemy]:
	var pool := enemies_in_circle(center, radius)
	pool.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	var out: Array[Enemy] = []
	out.assign(pool.slice(0, maxi(n, 1)))
	return out


## Throws an enemy's sprite into the air and lets it fall (it is stunned
## meanwhile through the hit's "stun").
func launch(e: Enemy, height := 34.0, time := 0.5) -> void:
	if not is_instance_valid(e) or e.is_boss:
		return
	var tw := e.create_tween()
	tw.tween_property(e.sprite, "position:y", -height, time * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(e.sprite, "position:y", 0.0, time * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


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
