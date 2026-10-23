class_name SkillCaster
extends Node
## Casts the active skills in the player's three slots (Run.deck.loadout): checks
## cooldowns and MP, creates the Skill from its card, and runs it while the
## player is in the SKILL state. Mages also cast their basic spell (Run.cls
## basic_skill) here, from the attack button, at no MP.
##
## Spells with a cast time (the Magic line's, half the original's activation
## time) first hold the cast pose: movement is locked and other presses are
## dropped; only a dash gets out, which cancels the spell and refunds its MP.

## Input actions for skill slots 1-3.
## Slot 4 holds the sky-blue rune's borrowed skill (Run.deck.rune).
const SLOT_ACTIONS: Array[String] = ["skill", "skill_2", "skill_3", "skill_4"]
## Slot index used for the basic spell.
const BASIC := 4

var slot_ready_at: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

var _skill: Skill  # the cast in progress
var _t := 0.0
var _slot := -1
var _paid := 0
var _cast_left := 0.0  # seconds of cast time still to go; the effect starts at 0
var _marker: Ring

@onready var player: Player = get_parent()


func card_in(slot: int) -> CardData:
	var id: StringName = &""
	if slot == BASIC:
		return Run.cls.basic_skill if Run.cls else null
	if slot < Run.deck.loadout.size():
		id = Run.deck.loadout[slot]
	elif Run.deck.rune:
		id = Run.deck.rune.id
	return Run.deck.card(id) if id != &"" else null


## MP a cast of `card` at `level` costs (Bolster Ballad saves some).
func cost_of(card: CardData, level: int) -> int:
	var m := Run.mod_factor("mp_cost_cut%", true)
	return roundi(card.mp_at(level) * m)


## Only the basic shot needs a load; the gun skills fire without one and
## leave the reload as it is.




## Why `card` can't be cast right now ("" when it can): the Charm line's
## conditions, as the original states them.
func charm_block(card: CardData, level: int, slot: int) -> String:
	if Run.instinct and slot != BASIC:
		return "No skills in Beast's Instinct"
	if slot != BASIC and Run.form_block(card.id) != "":
		return Run.form_block(card.id)
	var own: String = card.behavior.cast_block(card, level, player) if card.behavior else ""
	if own != "":
		return own
	if galder_cost(card, level) > 0 and Run.purse.galder < galder_cost(card, level):
		return "Not enough Galder"
	return ""


## Galder a cast of `card` costs: its table's "galder" per throw (Fist Full of Galders
## throws its Count); 0 for a skill that isn't paid in Galder.
func galder_cost(card: CardData, level: int) -> int:
	return int(card.param("galder", level, 0.0)) * int(card.param("count", level, 1.0))


## Casts the skill in `slot` if one is equipped, off cooldown and affordable.
func try_cast(slot: int) -> bool:
	var card := card_in(slot)
	if card == null or player.now() < slot_ready_at[slot]:
		return false
	# Gun skills need a gun, and the shots a loaded one (the client's checks:
	# "Bullet_NeededReload", "Alert_NoGun").
	if card.has_tag(&"needs_load") and not player.gun.loaded():
		return false
	if card.has_tag(&"gun") and not player.gun.has_gun():
		Events.text_shown.emit(player.global_position + Vector2(0, -70), "No gun", Color(1.0, 0.7, 0.5))
		return false
	if slot == BASIC and Run.in_bunker(player.now()):
		return false
	var level := maxi(Run.deck.card_level(card.id), 1)
	var blocked := charm_block(card, level, slot)
	if blocked != "":
		Events.text_shown.emit(player.global_position + Vector2(0, -70), blocked, Color(1.0, 0.7, 0.5))
		return false
	var cost := 0 if slot == BASIC else cost_of(card, level)
	# Any other skill pulls you out of hiding (its strikes end it themselves).
	if not card.has_tag(&"stealth"):
		Run.hidden = false
	if not Run.spend_mp(cost):
		Events.mp_short.emit()
		return false
	Run.purse.spend_galder(galder_cost(card, level))
	for t in Run.deck.talents():
		t.on_cast(card, level, slot)  # Blood Testament: spells cost health too
	var skill: Skill = card.behavior.new()
	skill.card = card
	skill.level = level
	skill.player = player
	skill.room = player.room
	skill.aim = player.aim
	skill.target = player.cursor_point()
	# The left-click spell keeps its level-1 rhythm: the original's cooldown
	# grows with level (Mana Arrow 1 -> 2 s), which on a free basic attack
	# would make every level-up a loss in damage over time.
	var cd_level := 1 if slot == BASIC else level
	var cooldown := card.cooldown_at(cd_level)
	if slot == BASIC and Run.cls.basic_cooldown > 0.0:
		cooldown = Run.cls.basic_cooldown
	slot_ready_at[slot] = player.now() + cooldown * Run.formulas.skill_cooldown_mult()
	player.enter(Player.State.SKILL)
	player.set_meta("casts", int(player.get_meta("casts", 0)) + 1)  # Ghostly Whisper ends on a new cast
	_skill = skill
	_slot = slot
	_paid = cost
	_t = 0.0
	_cast_left = card.cast_at(level)
	if _cast_left > 0.0:
		player.sprite.play_action("cast", Combat.screen(skill.aim), _cast_left, true)
		_marker = Ring.spawn(player.room.ground_fx, skill.target, 26.0, _cast_left + 0.1, Color(0.75, 0.85, 1.0, 0.7))
		Audio.play("eff_magicstart.wav", -10.0)
	else:
		_begin()
	Events.skill_cast.emit(slot)
	return true


## Seconds of cast time left (0 when not casting or past it).
func casting_left() -> float:
	return _cast_left if _skill else 0.0


## Share of the cast done, for the cast bar (1 when not casting).
func cast_progress() -> float:
	if not _skill or _cast_left <= 0.0:
		return 1.0
	var total := _skill.card.cast_at(_skill.level)
	return clampf(1.0 - _cast_left / maxf(total, 0.01), 0.0, 1.0)


## The slot being cast, or -1.
func casting_slot() -> int:
	return _slot if _skill else -1


func _begin() -> void:
	_skill.prepare()
	if _skill.invulnerable:
		player.invulnerable_until = maxf(player.invulnerable_until, player.now() + _skill.duration)
		player.set_phasing(true)
	player.sprite.play_action(_skill.anim, Combat.screen(_skill.aim), _skill.duration, true, _skill.anim_frames)
	_skill.card.play("ap", -6.0)
	_skill.effect("ap", player.global_position, {"follow": player, "hold": maxf(_skill.duration, 0.6)})
	_skill.start()


## Runs one physics frame of the cast.
func update(delta: float) -> void:
	if _cast_left > 0.0:
		player.velocity = Vector2.ZERO  # locked in place while casting
		if player.can_dash() and player.take_buffer("dash"):
			cancel()
			player.start_dash()
			return
		player.drop_buffer()  # nothing but a dash interrupts a cast
		_cast_left -= delta
		if _cast_left <= 0.0:
			_cast_left = 0.0
			if is_instance_valid(_marker):
				_marker.queue_free()
			_begin()
		return
	_t += delta
	player.velocity = _skill.movement(_t) + player.knock * 0.3
	_skill.update(_t, delta)
	if _t >= _skill.dash_cancel_at and player.can_dash() and player.take_buffer("dash"):
		player.start_dash()
		return
	if _t >= _skill.duration:
		player.enter(Player.State.MOVE)


## Dashing out of a cast: the spell never happens, so its MP comes back and
## its cooldown is lifted.
func cancel() -> void:
	if not _skill or _cast_left <= 0.0:
		return
	Run.gain_mp(_paid)
	slot_ready_at[_slot] = 0.0
	_cast_left = 0.0
	if is_instance_valid(_marker):
		_marker.queue_free()
	_skill = null


## Ends the cast early or on time; the player calls this when leaving SKILL.
func stop() -> void:
	if _skill and _cast_left > 0.0:
		cancel()
		return
	if _skill:
		var ending := _skill
		_skill = null
		ending.finish()
