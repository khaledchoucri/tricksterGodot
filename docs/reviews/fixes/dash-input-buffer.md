# Dash input near cooldown completion

The gameplay audit found dash input consumed before cooldown eligibility was checked.
Movement, melee cancellation, active-skill cancellation and cast-time cancellation now check
readiness before consuming the press. A blocked dash retains its original input-buffer deadline,
so a press shortly before cooldown completion can execute when ready. Expired input still fails.

The existing single-command buffer, replacement behavior, cancel windows, cooldown and dash
movement are unchanged. Cancelling cast time refunds MP and resets the skill cooldown; cancelling
an already-activated skill does not. A cast can complete while dash remains queued.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/dash_buffer.tscn`.
These checks also run in the Core reward/movement checks. They send real InputEventAction
objects through the player's input handler, use a controlled gameplay clock, and execute the
real dash, combo and caster methods on inert actors. The room fixture disables vaulting; these
are input/cancellation checks, not collision or vault-trajectory checks. Run state is restored.

Validation: 21 focused checks pass; unchanged production code fails 11 of them.
All 178 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where required runtime maps and fixtures are
unavailable. A full playable-run validation remains outstanding.
