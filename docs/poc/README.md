# Coral Beach run prototype

A playable roguelite run built on the original Trickster maps: Buffalo (Knight line, with a sword from the original equipment sprites) fights through seven rooms cut from the Coral Beach fields, choosing skill cards and stats along the way, then faces the Real Golden Mole in the Dark Cave.

The original Trickster sprites, maps, sounds and data are placeholders for prototyping. They are copyrighted, so they live in the git-ignored `original_assets/` folder and are generated from your own client install.

## Setup

1. Install Python 3.10+ and Godot 4.7.
2. Generate the assets from a Trickster client (about a minute):

   ```
   python -I tools/setup_assets.py "<path to the client's Trickster folder>"
   ```

   This exports the actors, five Coral Beach maps, the monster stats, and the sounds and music used by the game.
3. Open the project in Godot and press F5.

## Controls

| Input | Action |
|---|---|
| WASD or arrow keys | Move |
| Mouse | Aim |
| Left click or J | Sword combo |
| Right click or K | Skill slot 1 |
| Q or L | Skill slot 2 |
| E or ; | Skill slot 3 |
| Space or Shift | Dash (invulnerable, passes through enemies, vaults obstacles when there's room to land, cancels attacks) |
| 1 / 2 / 3 or click | Choose a card or stat |
| R | Log in again after the run ends |

## A run

- Seven combat rooms from the Blue Wave, Passionate Sun, Sunny Beach and Hidden Shore maps, then the boss. Rooms 4 and 7 add elite monsters.
- Clearing a room grants the reward shown on the door you came through: a skill card, a card upgrade, healing, Galder or a Harkon Shard.
- Cards come in two kinds, each up to level 5:
  - **Skills** go in the three skill slots and cost MP: Lacerator (the starter), Piercing Wave, Inferno Blade, Lightning Strike, Upper Smash, Shockwave and Tornado Bomb. Taking a new skill with full slots replaces one.
  - **Talents** are passive: Armor Breaker, Flaming Fist, Uppercut, Berserker, Counter Punch, Guard, Adrenaline and Hyper Beat.
- MP refills from sword hits and on entering a room.
- Scenery that hides Buffalo or an enemy fades, and Buffalo shows as an outline while hidden.
- Kills give EXP; each level lets you raise one of AP, DX, MA, LK, HP or DP after the fight.
- Death is a "rollback": the results screen shows what the run earned.

## Project layout

| Path | Contents |
|---|---|
| `scenes/` | Game, player, enemy, boss, door and projectile scenes |
| `scripts/autoload/` | `Run` (run state), `Audio`, and `Events` (signal bus) |
| `scripts/data/` | Resource classes: `RegionData`, `RoomData`, `EnemyData`, `CardData` |
| `data/coral_beach/` | The Coral Beach region: rooms, enemies and cards as `.tres` files |
| `scripts/player/` | The player: core states and dash, `ComboAttack` (basic attack chain), `SkillCaster` (skill slots) |
| `scripts/skills/` | One script per active skill, extending `Skill` |
| `scenes/hud.tscn`, `scenes/ui/`, `ui/hud_theme.tres` | The HUD, its skill slot and pick option scenes, and its theme |
| `data/combos/` | Basic attack chains as `ComboData` (sword for Buffalo, punch for Bunny later) |
| `scripts/fx/` | Effects: slashes, waves, bolts, the thrown blade, tornado, sparks, health bars, silhouette |
| `scripts/` | Room building, combat, AI, HUD, held weapon and props |
| `tools/` | Converters for Trickster sprites, maps, data and audio |

Actors announce effects (hit-stop, shake, damage numbers, deaths) on `Events`; the game and HUD present them. Rooms own their enemies and pass them their references.

To add a skill, write a script extending `Skill` in `scripts/skills/`, create a `CardData` with `kind` Skill, its MP cost, cooldown and that script as `behavior`, and add it to `region.tres`.

To add a room, create a `RoomData` resource with a map name and a rectangle (`tools/find_rooms.py` suggests open areas) and add it to `region.tres`. To tune a monster, edit its `EnemyData`; the base numbers for each attack pattern are in `Enemy.KINDS`.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

The test plays through room loading, combat, pathfinding, card and level-up picks, doors, Clione's projectiles, the boss and its summons, and death.

## Reference

- `timing-reference.md`: Hades II timing values the combat started from.
- `map-format.md`: the Trickster map file format.
- `actor-art.md`: what actor sprites and weapons need to provide (for the AI art).
- `qa-backlog.md`: known issues to fix.
