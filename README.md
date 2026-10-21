# Last Login

A single-player roguelite homage to Trickster Online, in Godot 4.7 with typed GDScript. The servers have shut
down and you are the last player: every run packs a whole Trickster career, from a level-1 character to a 3rd
job, into two regions of rooms, and the city of Megalopolis comes back to life between runs.

The game is built from the original client's data. Skills, jobs, monsters, items and formulas come from the
client's tables and code, and the server's formulas come from `GameServer.exe`, read with the tools in
`tools/re/`. Where the game departs from the original, the code says so (see `CLAUDE.md`).

## What's in it

- **Eight characters**, each with its own 1st, 2nd and 3rd jobs (36 jobs in all):
  - the Power line, Buffalo and Bunny
  - the Magic line, Sheep and Dragon
  - the Sense line, Fox and Lion (guns, with the client's own reload cycle)
  - the Charm line, Cat and Raccoon (Galder skills, and the Evolution and Metamorphosis beast forms)
  - a custom Trickster that combines two trees, once Buffalo and Bunny have each cleared a 3rd job
- **229 skill and talent cards** from the original skill tables (their deviations are marked in the generators).
- **A run** crosses Coral Beach and Desert Beach: seven rooms each, elite rooms at the 3rd and 6th, then a boss
  (the Real Golden Mole, Tutankhamen). Each region brings a job change once the Job Hall is restored.
- **16 monsters**, two bosses, and three Echoes of other classes that lend their skills as runes.
- **Twelve stats in four types**, with traits at their thresholds. There are six run-gear slots with refining
  and compounding, monster dens and shops.
- **Between runs:** a warehouse with heirlooms (level-synced, saved at Portable Ports), a death that rolls back
  what you didn't save, and wardrobe pieces from monster card sets. You also get drilling, card mastery, and
  Heat (Server Settings).
- **Megalopolis:** eleven people and twelve restorations, each switching a system on inside your runs, and a
  short story told through their conversations.

## Setup

The original sprites, maps, sounds and tables are placeholders for prototyping. They're copyrighted, so they
live in the git-ignored `original_assets/` folder, generated from your own client install:

1. Install Python 3.10+ and Godot 4.7.
2. `python -I tools/setup_assets.py "<client's Trickster folder>" ["<a client with the full effects>"]`
   (a 2019 client has the complete effect data; give it as the second path).
3. Open the project in Godot and press F5.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Move |
| Mouse | Aim |
| Left click / J | Basic attack (a combo, or the class's basic skill) |
| Right click / K, Q / L, E / ; | Skill slots 1-3 |
| F | Skill slot 4 (a borrowed rune) |
| Space / Shift | Dash (invulnerable; vaults obstacles with room to land) |
| F / Enter | Talk, read, advance dialogue (Megalopolis) |
| C / Tab | Character sheet |
| R | Back to Megalopolis after a run |

## For developers

- `CLAUDE.md`: how the code is written here (cards and monsters are data, sources cited, typed code, tests).
- `tests/run_smoke.sh [section|character ...]`: the smoke test, under a minute, seeded so results repeat.
- `tests/baseline.sh record|compare`: smoke results, the progression probe and seeded bots for every
  character, to show a change kept behaviour.
- `tests/check_generated.sh`: generated data matches its generators.
- `docs/design/systems-plan.md`: what each system is for; `docs/design/refactor-plan.md`: the code's structure.
- `docs/poc/`: map format, actor art, timing references and the QA backlog.
