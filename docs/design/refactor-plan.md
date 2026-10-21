# Refactor plan (confirmed 2026-10-21)

The goal is to pay down the "Known debt" in `CLAUDE.md` without changing gameplay. Any difference in the
baseline is a bug in the refactor, not a tuning change.

## Design

1. **Modifiers.** Cards, job passives, traits, wardrobe quirks and legend gear declare `mods` in their data,
   for example `{"DP%": "value"}`, `{"damage_taken%": ...}`, `{"skill:power_blow%": "value"}` or
   `{"hit:silence": "value"}`.
   - `Run.mod(key)` sums every held source. It is cached and refreshed on `stats_changed()`.
   - Keys come from a fixed list in a `Mod` class, so a typo fails at load.
   - The generators write `mods` from each card's SPEC entry.
2. **Tags.**
   - `CardData.tags` covers `galder`, `gun`, `needs_load`, `thrown` and `grows_basic`.
   - `CardData.form` (evolution, metamorphosis or any) replaces `FORM_NEEDED`.
   - These replace the id lists in code: `GALDER_SKILLS`, `GUN_NEEDED`, `GUN_LOADED`, `GUN_GROWERS`, `THROWN`,
     `BREAKERS`, `SHIELDS` and `BLESSINGS`.
3. **Talent hooks.** A talent can have a `Talent` script (`scripts/talents/`) with `modify_hit(ctx)`,
   `on_hurt(ctx)`, `tick(delta)` and `on_cast(ctx)`. The player and Run call these hooks on every held
   talent. Guard, Shield of Heaven, Oath of Light, Berserker, Desperate Rally, Mana Reflector, Dark Barrier,
   Revival, Blood Testament and the reload talents move out of `player.gd`, `combo_attack.gd`,
   `skill_caster.gd` and `gun_cycle.gd`.
4. **Run modules.** `Run` keeps the character: class, job, level, HP, MP and form. The rest moves into owned
   objects, and callers are updated by a script that checks every replacement (no forwarding functions):
   - `Run.deck`: cards, slots, offers and the rune
   - `Run.gear`: equipment, refining, compounding and weight
   - `Run.purse`: Galder, ore, materials and shards
   - `Run.route`: regions, the room plan and depth
   - `Run.formulas`: stats, damage, defence, guns and crits
5. **Seeded randomness.** Gameplay uses `Run.rng`, seeded by `new_run(seed)`. Effects that are only visual
   keep the global RNG, so they can't change a fight.
6. **Asset lookup.** An `Assets` class (`actor()`, `icon()`, `sound()`, `map()`, `table()`) replaces the
   literal `res://original_assets/` paths, ready for an art manifest.
7. **Enemy attacks as data.** `Enemy.KINDS` becomes `AttackPattern` resources, listed in `EnemyData.attacks`.

## Phases

Each phase must pass its check before the next starts.

**Status (2026-10-21):** phases 0 and 1 done. A seed replays a run exactly; 33 cards, the wardrobe, the numeric
traits and job passives declare `mods`; the lint allows 122 card id literals in shared code. Next: phase 2.

| # | Phase | Check |
|---|---|---|
| 0 | `Run.rng`; `seed=` in the bots and probe; `tests/baseline.sh` records the smoke results, the probe, and 8 characters × 3 seeds of bots | the same seed twice gives identical results (otherwise compare averages over more seeds) |
| 1 | `mods`, `Mod` keys, generators, `Run.mod()`; move the plain stat hooks, job passives, traits, quirks and legends onto it | probe numbers identical; smoke tests pass |
| 2 | tags and `form` replace the id lists; `skill:` mods replace the cross-skill hooks | identical baseline |
| 3 | `Talent` hooks; conditional talents leave the player scripts | identical baseline, plus a smoke check for each talent hook |
| 4 | split `Run` into modules; callers updated by script | identical baseline; `run_state.gd` under about 400 lines |
| 5 | `AttackPattern` resources replace `Enemy.KINDS` | identical baseline |
| 6 | the `Assets` lookup | smoke, UI audit and look gallery screenshots unchanged |
| 7 | untyped-declaration warnings become errors, and the code is fixed; lint checks for card-id literals and for generated data matching its generator | no warnings; lint passes |
| 8 | README and systems-plan status rewritten from the code; the debt list in `CLAUDE.md` cleared | — |

**Lint checks from phase 1 on:** a smoke-test check counts the card-id literals in shared code. The count may
never rise, and each phase lowers the allowed number until it reaches zero.

**Not changing:** `game.gd`'s reward flow, the hub menus, the story, and skill behaviour scripts that handle
their own cards with `match card.id`.
