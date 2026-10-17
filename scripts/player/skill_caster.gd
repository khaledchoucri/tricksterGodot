class_name SkillCaster
extends Node
## Casts the active skills in the player's three slots (Run.loadout): checks
## cooldowns and MP, creates the Skill from its card, and runs it while the
## player is in the SKILL state.

## Input actions for skill slots 1-3.
## Slot 4 holds the sky-blue rune's borrowed skill (Run.rune).
const SLOT_ACTIONS: Array[String] = ["skill", "skill_2", "skill_3", "skill_4"]

var slot_ready_at: Array[float] = [0.0, 0.0, 0.0, 0.0]

var _skill: Skill  # the cast in progress
var _t := 0.0

@onready var player: Player = get_parent()


## Casts the skill in `slot` if one is equipped, off cooldown and affordable.
func try_cast(slot: int) -> bool:
	var id: StringName = Run.loadout[slot] if slot < Run.loadout.size() else (Run.rune.id if Run.rune else &"")
	if id == &"" or player.now() < slot_ready_at[slot]:
		return false
	var card := Run.card(id)
	if not Run.spend_mp(card.mp_cost):
		Events.mp_short.emit()
		return false
	var skill: Skill = card.behavior.new()
	skill.card = card
	skill.level = Run.card_level(id)
	skill.player = player
	skill.room = player.room
	skill.aim = player.aim
	skill.target = player.cursor_point()
	slot_ready_at[slot] = player.now() + card.cooldown_at(skill.level) * Run.skill_cooldown_mult()
	player.enter(Player.State.SKILL)
	_skill = skill
	_t = 0.0
	if skill.invulnerable:
		player.invulnerable_until = maxf(player.invulnerable_until, player.now() + skill.duration)
		player.set_phasing(true)
	player.sprite.play_action(skill.anim, Combat.screen(skill.aim), skill.duration, true, skill.anim_frames)
	skill.start()
	Events.skill_cast.emit(slot)
	return true


## Runs one physics frame of the cast.
func update(delta: float) -> void:
	_t += delta
	player.velocity = _skill.movement(_t) + player.knock * 0.3
	_skill.update(_t, delta)
	if _t >= _skill.dash_cancel_at and player.take_buffer("dash") and player.can_dash():
		player.start_dash()
		return
	if _t >= _skill.duration:
		player.enter(Player.State.MOVE)


## Ends the cast early or on time; the player calls this when leaving SKILL.
func stop() -> void:
	if _skill:
		var ending := _skill
		_skill = null
		ending.finish()
