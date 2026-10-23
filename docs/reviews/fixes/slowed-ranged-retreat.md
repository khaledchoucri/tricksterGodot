# Slow and DX during ranged retreat

The audit's status/movement review exposed an inconsistent movement path: pursuit multiplied
speed by Enemy.speed_factor(), but ranged retreat used full walk speed. Retreat now uses that
same existing factor before adding knockback. Slow and DX reductions therefore apply to both
movement paths, including their existing combined reduction and 20% minimum speed.

No debuff values, durations, stacking rules, attack timings or keep-away distances change.
Forced knockback remains unscaled. This complements the separate held-enemy movement branch;
it does not replace that branch's immobilization fix.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/retreat_slow.tscn`.
The same checks run at the beginning of the Core smoke section using real debuffs and AI
handlers, an inert actor and a navigation fixture. They cover unmodified speed, Slow/DX,
clamping, expiry, combined reductions, knockback, blocked retreat, melee and ranged pursuit.

Validation: 12 focused checks pass; unchanged production code fails 6 of them.
All 178 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where required runtime maps and fixtures are
unavailable. A full playable-run validation remains outstanding.
