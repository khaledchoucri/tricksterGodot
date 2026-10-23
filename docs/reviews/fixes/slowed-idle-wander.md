# Slows also affect idle wandering

Against main `0f641ab`. Enemy._state_idle multiplied its direction by raw
walk_speed, ignoring the same slow/DX factor used in chase (and the retreat
branch). Multiply only voluntary walking by the existing speed_factor(). External
knockback stays additive. The existing 20% minimum, additive slow/DX combination,
duration, hold behavior and state transitions are unchanged; no new rule choice.

```
godot --headless --fixed-fps 60 --path . res://tests/combat/idle_slow.tscn
```

8 checks pass on available Godot 4.6.3 (target 4.7.2); replacing only Enemy with
main yields 6 failed assertions and exit 1: slow, DX, combined, minimum clamp,
knockback composition and another direction. No-slow and expired-slow controls
pass on both. Neither run has SCRIPT ERROR. The synchronous core SmokeSection
uses private actors and a controlled now(), replacing no autoload state and
advancing no frame, timer or RNG. Existing shutdown ObjectDB/resource warnings
remain. Full smoke and visual checks were not run because original runtime
assets are absent. Real monster movement and Godot 4.7.2 remain unverified.
