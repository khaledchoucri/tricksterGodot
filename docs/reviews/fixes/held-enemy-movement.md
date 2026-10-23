# Held enemy movement

The gameplay audit identified ranged enemies retreating before checking immobilization.
Hold and Frozen now take priority over retreat and lost-target wandering in CHASE, and over
wandering in IDLE. Existing knockback/pulls, windup interruption, attack-token release and
boss immunity remain intact. Movement resumes when the existing status deadline expires.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/enemy_control.tscn`.
The same checks run in the Core smoke section using the real status and AI state handlers,
with inert sprites and a fixture room whose navigation surface is open.

Validation: 17 focused checks pass; the unchanged production code fails 10 of those checks.
The full smoke suite compiles all 178 scripts. It still reports the same 10 assertions and
231 script errors as the unchanged main baseline in this environment, where required runtime
maps and fixtures are unavailable. This does not establish a full playable-run pass.
