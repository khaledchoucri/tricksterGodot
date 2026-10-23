# Gun bursts and cover

The gameplay audit found that Shooting Spree and Berserk could hit through obstacles while
basic gunfire stopped at them. These bursts now exclude blocked enemies before shuffling and
applying the target cap, so an invisible enemy cannot consume a visible target's slot.
Visibility is checked again before each shot in case the target or caster moves behind cover.
A selected target that loses visibility is skipped; the burst does not choose a replacement.

Damage, timing, radius, target counts and the no-reload rule are unchanged. This applies the
existing basic-gun cover rule to these gun skills, without changing other spells' wall rules.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/gun_visibility.tscn`.
These checks also run at the beginning of the Sense smoke section. They execute the shared
burst targeting/firing behavior with captured hits, a wall fixture and a synchronous wait stub
that can close cover between shots. Timing and damage scaling have separate regression checks.
Generated skill data is only duplicated in memory for cap fixtures; RNG state is restored.

Validation: 17 focused checks pass; unchanged production code fails 6 of them.
All 178 scripts compile. The full smoke run retains unchanged main's 10 failed assertions and
231 script errors in this environment, where required runtime maps and fixtures are unavailable.
A full playable-run validation remains outstanding.
