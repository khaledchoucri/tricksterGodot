# Gun skill damage bonuses

The gameplay audit found that GUN scaling returned before the shared skill-damage modifier.
Gun skills now use stat-only gun scaling, followed by the existing shared skill and general
damage modifiers. General damage is applied exactly once. Basic gun shots retain their
separate multiplier and do not gain skill-only bonuses.

Shield Breaker had a second bypass in its special damage calculation. It now uses the same
skill multiplier while retaining its base shot plus breach ratio, breach strength and duration.
No skill tables, stat formulas, percentages or progression requirements were changed.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/gun_bonuses.tscn`.
The same checks run in the Sense smoke section. They cover modifier composition and capture
pre-defense hits from the real Power Shot and Shield Breaker firing and targeting paths.
Fixture modules and stats are restored before the normal smoke game starts.

Validation: 14 focused checks pass; unchanged production code fails 6 of them.
The full smoke suite compiles all 178 scripts. Its 10 failed assertions and 231 script errors
match the unchanged main baseline in this environment, where required runtime maps and
fixtures are unavailable. A full playable-run validation remains outstanding.
