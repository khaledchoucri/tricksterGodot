# Settle each run exactly once

Against main `0f641ab`. Death had no terminal guard; victory rejected only another
victory. Delayed damage could therefore bank a rollback after a clear, or a clear
could arrive after death. Both paths could grant currency and start presentation.

RunCity.finish now latches settlement before any profile writes. Run.new_run
resets that latch. Both Game callbacks reject either terminal phase and an already
settled city. Victory checks HP before granting its two shards. Presentation is
split into private helpers after synchronous settlement, making direct callback
checks independent of maps, audio, HUD and timer timing.

Reading: HP already zero when victory is checked means death, even if the victory
callback arrives before the death callback. Once victory settles with positive HP,
later damage cannot replace it. Thus a double KO with HP already zero resolves to
death in either callback order; a later lingering projectile cannot undo a clear.
This is an interpretation of our run flow, not an asserted original-game rule.

Does not stop lingering actors, make profile writes crash-atomic, or redesign
revives, death item loss, rewards, or the visual result sequence.

```
godot --headless --fixed-fps 60 --path . res://tests/combat/run_outcome.tscn
```

15 checks pass on available Godot 4.6.3 (target 4.7.2), without SCRIPT ERROR.
Removing the new terminal/HP guards and idempotency guard, retaining the
presentation split and API, makes 13 assertions fail and exits 1: both double-KO
orders, once-only counters/currency/presentation, direct finish idempotency and
the following run's bank count. The reset latch and a fresh run are exercised
through real Run.new_run(42). A QuietGame overrides only presentation; actual
Game callbacks, RunCity death/banking, Profile writes and purse rewards execute.

This synchronous SmokeSection runs in core.rewards. It snapshots all Profile
fields and all writable Run fields, isolates mutable containers/modules before
new_run, restores seed/state, and blocks/restores signals during the fixture.
No timer or frame is awaited. Existing shutdown ObjectDB/resource warnings remain.
Full smoke and visual checks were not run: original runtime assets are absent.
Godot 4.7.2 and actual boss/projectile/HUD integration remain unverified.
