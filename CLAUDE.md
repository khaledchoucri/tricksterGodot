# Last Login: how we write code here

Last Login is a single-player roguelite homage to Trickster Online, in Godot 4.7.2 with typed GDScript.
These rules apply to every change, whether it's a feature, a fix or a test. Code that breaks them gets
fixed in the same change or tracked in "Known debt" below.

## 1. Where things live

| Layer | Owns | Never |
|---|---|---|
| `data/**/*.tres` (Resources) | numbers, names, prerequisites, tags, effects | logic |
| `tools/*.py` generators | turning the original tables into `data/` | hand-tuned one-offs; put an override in the generator's SPEC |
| `scripts/autoload/run_state.gd` (`Run`) | the run's state, behind a small public interface | new feature logic (that goes in a module, see 2) |
| `scripts/autoload/profile.gd` | what persists between runs | run-only state |
| `scripts/autoload/events.gd` | the signal bus and game clock | state |
| `scripts/skills/*.gd` | what one skill *does* when cast | stat bonuses or another card's rules |
| `game.gd`, `hud.gd`, `hub.gd` | flow and presentation | combat maths |

- **Signals up, calls down.** Gameplay emits `Events.*`, and the game and HUD decide how to show it. Gameplay
  code never calls the HUD.
- **Generated data is never hand-edited.** Change the generator, regenerate, and check the diff shows only what
  you meant to change (`git diff data/`).

## 2. Cards and monsters are data, code asks questions

A card says what it does through its fields. Code asks about effects, not about specific cards:

```gdscript
# no
s.DP *= 1.0 + (card_value(&"shield_all") + card_value(&"sturdy_shield")) / 100.0
if card.id in GALDER_SKILLS: ...
# yes
s.DP *= 1.0 + Run.mod("DP%") / 100.0      # sums every held card's stat_mods
if card.has_tag(&"galder"): ...
```

- **No card or monster id literals** outside the generators, `data/`, and the behaviour script of that same card.
  An id list in code (`GUN_GROWERS`, `FORM_NEEDED`, `BREAKERS`...) means a field or tag is missing.
- **Truly unique behaviour** (Mana Arrow's flight, Bunker) lives in the card's own `behavior` script.
- **Monsters follow the same rule.** Attack patterns, skills and tactics live in `EnemyData` and come from the
  original tables, not from consts in `enemy.gd`.

## 3. Faithful to the source, and saying so

- **Source first.** Before designing a system, look at the client tables (`original_assets/data/tables`) and
  the binaries (formulas are server-side: `GameServer.exe`, read through `tools/re`, see `tools/re/README.md`).
- **Every formula and table-derived constant says where it came from** in its `##` comment: the function
  address, the table and column, or the client function.
- **Deviations are tagged so they can be found with grep:**
  - `Deviation (user, YYYY-MM-DD):` for a choice the user made
  - `Reading:` for our interpretation where the source is silent
  - `Ours:` for numbers we invented
- **The power fantasy:** damage comes from linear stats, and monsters are never scaled to the player.

## 4. GDScript style

- **Static types everywhere:** variables, parameters, returns, and typed arrays and dictionaries where Godot
  allows. Use `:=` only when the type is obvious.
- **`##` doc comments** on every script, public function and constant: what it is for, and the source. Inline
  comments only explain why.
- **Size.** A function is about 50 lines at most, a file about 600. Past that, split by responsibility.
- **No magic numbers.** Use a named `const` with its source or `Ours:` tag.
- **Time** is the game clock (`Events.time` / `player.now()`), never wall time. **Randomness** goes through
  the run's seeded RNG (`Run.rng`), so a seed reproduces a run.
- **Paths to original assets** go through one asset lookup, never a literal `res://original_assets/...`
  string, so new art can replace them through a manifest.
- **Naming.** `snake_case` files and functions, `PascalCase` classes, `SCREAMING_CASE` constants. Private
  members start with `_`.

## 5. Tests

- **Every behaviour change has a check** in the smoke test section for its class or system. Changes to shared
  code run the full suite.
- **Test like a player.** Use input actions and real button presses, the real window size and the game clock.
  Measure combat feel (hits to kill, time to kill) with `tests/progression_probe.tscn` and the bots
  (`tests/playtest.tscn`).
- **Refactors keep behaviour.** Record the same smoke results and seeded bot and probe numbers before and
  after.
- **A flaky check is a bug.** Fix it, or skip it with a comment naming why and a debt entry.
- **Lint checks** (in the smoke test) enforce sections 2 and 4: no card id literals in shared code, and
  generated data matches its generator.

## 6. Changes and commits

- **One concern per commit**, with a message that says what changed for the player.
- **Explicit `git add <paths>`.** Never stage `original_assets/` or `ui/hud_theme.tres`.
- **Docs are updated in the same commit as the change** (README, `docs/design/systems-plan.md` status, a
  file's header comment).
- **Push** `poc/combat-room`, then `poc/combat-room:main`; the two stay identical.
- **Edit files with an editor or a small script that asserts its match**, never with blind `sed` over
  multi-line code.

## Known debt (as of 2026-10-21)

Pay these down when you're working near them, and remove each line when it's fixed.

- `run_state.gd` is about 1,700 lines and does too much: stats, cards and offers, the economy, gear, the room
  plan and formulas. Split it into modules behind `Run`.
- 46 `card_value/card_level/has_passive(&"id")` calls in `run_state.gd`, and more in `player.gd`,
  `combo_attack.gd`, `skill_caster.gd`, `enemy.gd` and `game.gd`. Replace them with card `stat_mods`, effects
  and tags.
- Id lists in code: `FORM_NEEDED`, `GALDER_SKILLS`, `GUN_NEEDED`, `GUN_LOADED`, `GUN_GROWERS`, `THROWN`,
  `BREAKERS`, `SHIELDS`, `BLESSINGS`.
- Enemy attack patterns are five consts in `Enemy.KINDS`.
- 87 unseeded `randi`/`randf`/`shuffle` calls in `scripts/`.
- 35 literal `res://original_assets/` paths in 23 scripts.
- `README.md` describes an older pitch ("Sunlit Impact"), and the systems plan's status stops at Buffalo and
  Bunny.
- The `poison_assault` smoke check is flaky.
