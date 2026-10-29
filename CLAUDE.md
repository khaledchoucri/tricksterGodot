# Last Login: how we write code here

Last Login is a single-player roguelite homage to Trickster Online, in Godot 4.7.2 with typed GDScript.
These rules apply to every change, whether it's a feature, a fix or a test. Code that breaks them gets
fixed in the same change or tracked in "Known debt" below.

## 1. Where things live

| Layer | Owns | Never |
|---|---|---|
| `data/**/*.tres` (Resources) | numbers, names, prerequisites, tags, effects | logic |
| `tools/*.py` generators | turning the original tables into `data/` | hand-tuned one-offs; put an override in the generator's SPEC |
| `scripts/autoload/run_state.gd` (`Run`) | the character: class, job, level, HP/MP, form, stats, traits, mods | anything a module owns |
| `scripts/autoload/run_*.gd` (`Run.route`, `.deck`, `.gear`, `.purse`, `.formulas`, `.city`, `.veteran`) | the rest of the run, one concern each | forwarding functions on `Run`: callers name the module |
| `scripts/autoload/profile.gd` | what persists between runs | run-only state |
| `scripts/autoload/events.gd` | the signal bus and game clock | state |
| `scripts/skills/*.gd` | what one skill *does* when cast | stat bonuses or another card's rules |
| `scripts/talents/*.gd` | what one talent does beyond its numbers (`Talent` hooks: tick, guard, absorb, retaliate, revive, adjust, on_cast) | numbers a `mod` can carry |
| `game.gd`, `hud.gd`, `hub.gd` | flow and presentation | combat maths |

- **Signals up, calls down.** Gameplay emits `Events.*`, and the game and HUD decide how to show it. Gameplay
  code never calls the HUD.
- **Generated data is never hand-edited.** Change the generator, regenerate, and check the diff shows only what
  you meant to change (`git diff data/`).

## 2. Cards and monsters are data, code asks questions

A card says what it does through its fields: `mods` (numbers, summed by `Run.mod()`; see
`scripts/data/mod.gd` for every key), `tags`, `form`, `inflicts`. Code asks about effects, not about
specific cards:

```gdscript
# no
s.DP *= 1.0 + (card_value(&"shield_all") + card_value(&"sturdy_shield")) / 100.0
if card.id in GALDER_SKILLS: ...
# yes
s.DP *= 1.0 + Run.mod("DP%") / 100.0      # sums every held source's mods
if card.has_tag(&"galder"): ...
```

- **No card or monster id literals** outside the generators, `data/`, and the behaviour script of that same card.
  An id list in code (`GUN_GROWERS`, `FORM_NEEDED`, `BREAKERS`...) means a field or tag is missing.
- **Truly unique behaviour** (Mana Arrow's flight, Bunker) lives in the card's own `behavior` script; a
  talent's (Guard's block, Revival) in its `talent` script. A talent that changes one skill (Faint on
  Shockwave) declares a scoped mod (`"shockwave.stun_chance"`) that the skill reads with `skill_mod()`.
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

- **Static types everywhere:** variables, parameters, returns, `for` variables, and typed arrays and
  dictionaries where Godot allows. Use `:=` only when the type is obvious. An untyped declaration is a compile
  error (`project.godot`: `untyped_declaration=2`); write `Variant` where a value really is dynamic (parsed
  JSON).
- **`##` doc comments** on every script, public function and constant: what it is for, and the source. Inline
  comments only explain why.
- **Size.** A function is about 50 lines at most, a file about 600. Past that, split by responsibility.
- **No magic numbers.** Use a named `const` with its source or `Ours:` tag.
- **Time** is the game clock (`Events.time` / `player.now()`), never wall time. **Randomness** goes through
  the run's seeded RNG (`Run.rng`, `Run.shuffle()`, `Run.pick()`), so a seed reproduces a run. Only effects
  that are purely visual or audible (particles, pitch, shake) use the global `randf()`/`randi()`.
- **Paths to original assets** go through `Assets` (`scripts/assets.gd`), never a literal
  `res://original_assets/...` string (the lint checks), so new art can replace them through a manifest.
- **Naming.** `snake_case` files and functions, `PascalCase` classes, `SCREAMING_CASE` constants. Private
  members start with `_`.

## 5. Tests

- **Every behaviour change has a check** in the smoke test section for its class or system, its own file in
  `tests/smoke/` (a `SmokeSection`; a new system gets a new section). Run just that section while working (`tests/run_smoke.sh charm`, `tests/run_smoke.sh lion ui`; sections: core, power,
  magic, sense, elements, charm, talents, balance, ui, rest, art, boss, systems, chunks, lint). Each section passes on its own. Changes to
  shared code, and every commit, run the full suite (`tests/run_smoke.sh`). It runs at a fixed 60 fps and a
  fixed seed (`-- seed=N` to change it), so the full suite takes under a minute and a result repeats exactly.
- **Test like a player.** Use input actions and real button presses, the real window size and the game clock.
  Measure combat feel (hits to kill, time to kill) with `tests/progression_probe.tscn` and the bots
  (`tests/playtest.tscn`).
- **Refactors keep behaviour.** `tests/baseline.sh record before`, make the change, `tests/baseline.sh record
  after`, then `tests/baseline.sh compare before after`: smoke results, the probe and seeded bots for all
  eight characters must match.
- **A flaky check is a bug.** Fix it, or skip it with a comment naming why and a debt entry.
- **Lint checks** (the smoke test's `lint` section) enforce sections 2 and 4: every script compiles; no card id
  literals in shared code, and skill scripts name only their own cards; every `Run.<member>` a script names
  exists; no literal original-asset path; every monster has an attack pattern its tune fits.
  `tests/check_generated.sh` checks that generated data matches its generator (run it before committing a
  generator or `data/` change).

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

- `scripts/game.gd` is 989 lines (the lint allows 700): split its reward flow, the room flow and the pick
  menus into their own scripts, then take it off the lint's `LONG_ALLOWED`.
