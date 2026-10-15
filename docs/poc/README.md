# Combat-room proof of concept

One Coral Beach arena: Buffalo against three waves of Torobbie, Tottochi and Bustshell, then the Real Golden Mole. It tests whether Hades-speed combat works with Trickster's monsters and sprites.

The original Trickster sprites and data are placeholders for this prototype. They are copyrighted, so they live in the git-ignored `original_assets/` folder and are generated from your own client install.

## Setup

1. Install Python 3.10+ and Godot 4.7.
2. Generate the assets from a Trickster client:

   ```
   python -I tools/setup_assets.py "<path to the client's Trickster folder>"
   ```

   This exports Buffalo and the four monsters as sprite sheets (`tools/export_actor.py`) and converts `libconfig_eng.xml` to JSON (`tools/export_data.py`).
3. Open the project in Godot and press F5.

## Controls

| Input | Action |
|---|---|
| WASD or arrow keys | Move |
| Mouse | Aim |
| Left click or J | Punch combo (two hits; the second is a heavy kick) |
| Right click or K | Shockwave (area knockback, 5 s cooldown) |
| Space or Shift | Dash (invulnerable, passes through enemies, cancels attacks) |
| R | Restart after death or victory |

## What's in it

- **Player** (`scripts/player.gd`): state machine with input buffering, dash-cancelable attacks, a short lunge on each hit, hit-stop and invulnerability frames.
- **Enemies** (`scripts/enemy.gd`): HP, damage and speed derived from each monster's original `MonsterParamEx2` row. Each has a ground telegraph before attacking: Torobbie swipes a wedge, Tottochi lunges down a lane, and Bustshell slams a circle and can't be staggered.
- **Boss** (`scripts/boss_mole.gd`): slam, a burrow ambush whose warning tracks you before locking, and Torobbie summons at 66% and 33% HP.
- **Arena** (`scripts/arena.gd`): waves, spawn warnings, a cap of two enemies attacking at once, screen shake, damage numbers, and the "rollback" screen on death.

Tuning values are at the top of each script. `timing-reference.md` lists the Hades II values they started from.

## Tests

```
godot --headless --path . -s res://tests/smoke_test.gd
```

The test checks spawning, hits, invulnerability, enemy telegraphs, the attacker cap, wave progression and boss summons.
