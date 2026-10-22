# Multi-hit skill activation settings

Base branch: `fix/boxer-dash-preparation`. Merge that preparation hook before this branch,
or review this branch against it to see only these multi-hit changes. This branch is independent
of the sibling `fix/charm-skill-preparation` branch once their common parent is present.

The audit found animation timing being consumed before behaviors finalized duration. Blazing
Strike now prepares its targets, DX-derived hit count and duration before animation. Sky-strike
spells prepare their target and strike-count duration at the same point. Fist Full of Galders
prepares its throw count/duration; actual throws, sounds and random Galder rolls stay in start().
Damage formulas, target limits, intervals, frame ranges, costs and cooldowns are unchanged.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/multi_preparation.tscn`.
The same checks run at the start of the Magic smoke section. They reuse the parent activation
fixture, cover Blazing Strike with zero/one/two targets and increased attack speed, Thunderbolt
at three levels, and Galder bursts at two lengths. Single Galder throws and One Pair are controls.
Throw delivery is captured and waits advance synchronously; these are activation/sequence checks,
not projectile flight or damage-resolution checks. Preparation is also checked for no spending,
projectile creation, roll or lingering ownership.

Validation: 32 focused checks pass; the parent branch without this fix fails 9 of them.
All 180 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where runtime maps and fixtures are unavailable.
A full playable-run validation remains outstanding.
