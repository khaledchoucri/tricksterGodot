# Combo hit windows across physics steps

The gameplay audit found that melee windows could be skipped when a frame landed after a
window's end. Combo updates now resolve every active window intersected by the frame's swing-
time interval. Each window keeps its own target set, including when windows overlap.
Starting another swing clears those sets.

Swing time accumulates each frame's attack-speed-adjusted delta. Changing speed mid-swing
therefore advances the existing swing rather than rescaling its entire elapsed history and
potentially rewinding completed hits. Existing damage, reach, aim locking, cancel/chain times
and combo resources are unchanged. Contact still uses the current positions of actors.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/combo_windows.tscn`.
The same checks run in the Power smoke section. They exercise the real combo handler with
captured contacts: Bunny's second swing, large steps, high speed, changing speed, range entry,
overlapping windows and a restarted swing. Fixture run state is restored before game boot.

Validation: 13 focused checks pass; unchanged production code fails 5 of them.
All 178 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where required runtime maps and fixtures are
unavailable. A full playable-run validation remains outstanding.
