# Stable fan and falling-rock observations (tests only)

Against main `0f641ab`; no production scripts change. One Pair's assertion sorted
world angles, so a left-facing fan crossing -PI/PI measured most of a circle.
Measure each projectile relative to the original throw direction before sorting.

Tombeth's check waited a fixed second before counting a visual that lives 0.9 s.
Sample every physics frame until rocks appear, with a bounded 90-frame wait at
the suite's fixed 60 fps. Require an actual warning at each observed landing
position, rather than counting unrelated Telegraphs. This replaces the existing
last boss observation; no new async fixture runs between smoke sections.

```
godot --headless --fixed-fps 60 --path . res://tests/combat/transient_checks.tscn
```

8 focused checks pass under available Godot 4.6.3 (target 4.7.2). The standalone
fixture calls the real test helpers and creates real FallingRock/Telegraph nodes.
It checks four aim directions, missing/misplaced marks, observation during flight
and disappearance after the former fixed delay. Restoring world-angle measurement
and a fixed one-second observation in those helpers yields 4 failed assertions
(three left-facing fans and the airborne observation), exit 1, no SCRIPT ERROR.
The fixed run also has no SCRIPT ERROR. This tests the observation logic, not
whether Tombeth actually emits a slam; that requires the missing runtime assets.

The only added async fixture is standalone and never integrated into the full
runner, so its frames cannot perturb another section. No Run/Profile state is
modified; FallingRock's cosmetic RNG is independent of Run.rng. Existing engine
shutdown ObjectDB/resource warnings remain. Full smoke and visual/boss integration
were not run because original runtime assets are absent; Godot 4.7.2 is unverified.
