# Charm skill activation settings

Base branch: `fix/boxer-dash-preparation`. Merge that preparation hook before this branch,
or review this branch against it to see only the Charm changes.

The audit found that Charm skills changed animation and duration after the caster had started
presentation. Charm strike and burst setup now runs in prepare(), before those settings are
read. No damage formulas, hit timing, target selection, lunge window or resource tables change.

This covers Volley Kick, Heavy Hit, 2 Hit Combo and Beast Claw timing; Siren Song and Sharp
Scream animation; and Mass Destruction animation/timing. Default variants remain controls.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/charm_preparation.tscn`.
The same checks run at the start of the Charm smoke section using the parent activation
fixture and real caster/behaviors. They verify final presentation settings, strike targets,
Beast Claw's prepared lunge, and preparation without resource spending, rolls or ground effects.
These checks isolate activation settings, not class/form eligibility or damage resolution.

Validation: 25 focused checks pass; the parent branch without this fix fails 11 of them.
All 180 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where runtime maps and fixtures are unavailable.
A full playable-run validation remains outstanding.
