# Engine hardening review handoff — 2026-10-23

All eight branches start from main `0f641ab`; only fix branches were pushed.
No main/poc pushes, force pushes, boss production edits, hub UI edits or generated
data edits. Each branch includes its focused scene and a fix note explaining
counterfactual failures and unverified integration. No PRs were created here.

| Branch | Production files / concern | Focused scene under tests/combat/ | Pass / counterfactual failures |
| --- | --- | --- | --- |
| fix/warehouse-identity | profile.gd, run_city.gd, gear_item.gd: stable IDs and save migration | warehouse_identity.tscn | 21 / 8 |
| fix/equip-hp-conservation | run_gear.gd: swapping gear supplies no HP | equip_hp.tscn | 13 / 10 |
| fix/exclusive-run-outcome | run_city.gd, run_state.gd, game.gd: once-only settlement and double KO | run_outcome.tscn | 15 / 13 |
| fix/atomic-warehouse-swap | run_city.gd: whole-swap capacity and rollback | warehouse_swap.tscn | 13 / 10 |
| fix/borrowed-rune-level | run_deck.gd: effective level is max(owned, borrowed) | rune_level.tscn | 15 / 5 |
| fix/slowed-idle-wander | enemy.gd: existing slow/DX factor while wandering | idle_slow.tscn | 8 / 6 |
| fix/stable-combat-smoke-checks | tests only: charm.gd and boss.gd observations | transient_checks.tscn | 8 / 4 |
| fix/paused-room-gameplay | room.gd and game.gd: five gameplay timers freeze during pause | room_pause.tscn | 14 / 8 |

Counterfactuals preserve fixture APIs/helper extraction where required to isolate
the faulty production behavior, rather than counting missing-method errors as
regression evidence. The test-only branch restores faulty observation logic.
See each docs/reviews/fixes note for exact assertions and scope.

## Combined verification

A temporary detached worktree combined all eight branches; it was not pushed.
Production code merged cleanly. The three systems.gd test-hook insertions
(warehouse identity, equipment HP, rune level) conflict at the same insertion
point: retain every hook when preparing PR merges. No stacked dependency is
required; the branches are otherwise independent against the stated main.

In one Godot process, all 107 focused assertions passed together. Another 40
assertions checked after each fixture that every Profile field, every writable
Run field, original module contents, both seeded RNG values and signal blocking
were restored: 147 total passing assertions, zero SCRIPT ERROR. This caught a
test-only JSON numeric normalization assumption in warehouse_swap, fixed in its
follow-up commit. The integration runner was temporary verification code, not
committed gameplay or a new shipped test suite.

All validation used available Godot 4.6.3, not the target 4.7.2. Existing engine
shutdown ObjectDB/resource diagnostics remain. Full smoke, visual validation,
asset-dependent hub/combat/boss integration, and full smoke-runner teardown were
not run because the original runtime assets are absent. This report makes no
claim about a full-suite failure baseline. Review the runner's final async stage
on a fully provisioned machine before merging the pause branch.

## Rules clarified

- Reading: equipment keeps current HP capped to the new maximum; adding capacity
  does not heal. Level-up healing remains.
- Reading: if HP is already zero when victory is checked, death wins in either
  callback order. A victory settled while alive cannot be replaced by later damage.
- Reading: a borrowed rune cannot lower the effective level of a learned skill.

These choices are documented interpretations, not claims about original-server
mechanics. The timer note inventories every non-boss/non-skill create_timer site
and explains why each of the eight presentation/modal timers remains unchanged.
