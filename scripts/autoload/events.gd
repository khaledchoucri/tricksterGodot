extends Node
## Game-wide signal bus (autoloaded as `Events`). Actors announce what
## happened; the game, HUD and camera decide how to present it.

## Freeze the action briefly to sell an impact.
signal hitstop_requested(duration: float)
## Shake the camera; amount is in pixels.
signal shake_requested(amount: float)
## Show a floating damage number at a world position.
signal damage_shown(world_pos: Vector2, amount: int, color: Color, big: bool)
## Show a floating word (Evade, Graze, Perfect dodge) at a world position.
signal text_shown(world_pos: Vector2, text: String, color: Color)
## Something was picked up mid-fight (Bronze Fragments from Lucky Strikes).
signal loot_found(text: String)

signal enemy_spawned(enemy: Enemy)
signal enemy_died(enemy: Enemy)
signal boss_health_changed(enemy: Enemy)
signal boss_spoke(text: String)
signal player_hp_changed
signal player_died
## The player cast the skill in a slot (0-2).
signal skill_cast(slot: int)
## The player tried a skill without enough MP.
signal mp_short
## The Rollback Cache saved the player from a fatal blow.
signal revived
