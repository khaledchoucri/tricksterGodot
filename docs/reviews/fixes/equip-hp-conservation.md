# Equipment swaps do not heal

Against main `0f641ab`. RunGear.equip healed every increase in maximum HP, while
unequipping only clamped current HP. Removing and replacing an HP piece therefore
healed repeatedly at a rest stop, including reviving HP from zero.

Reading: gear changes preserve the current HP count, capped to the resulting
maximum. Increasing capacity supplies no HP; removing capacity can discard HP
above the new cap. This uses the existing take_off/stats_changed rule consistently
and avoids fractional rounding accumulating HP through repeated swaps. It also
means putting on a larger HP piece while healthy does not fill its extra capacity.
The implementation removes only the equipment-specific heal call. Level-up and
type-point healing, MP handling, equipment eligibility and displacement are unchanged.

```
godot --headless --fixed-fps 60 --path . res://tests/combat/equip_hp.tscn
```

13 checks pass on available Godot 4.6.3; target is 4.7.2. Restoring only RunGear
to main makes 10 assertions fail: capacity-increase healing and repeated cycles
at 1/50/100%, unequip HP at 1/50%, re-equip after clamping, and zero-HP revival.
Both runs have no SCRIPT ERROR; the unfixed run exits 1. The synchronous
SmokeSection runs in systems, isolates every replaced Run field, blocks/restores
Events and Run signal delivery while using synthetic gear, and restores both
Run.rng.seed and state. Existing engine shutdown reports ObjectDB/resource leaks.

Full smoke and visuals were not run because original runtime assets are absent.
Real rest-stop/HUD integration and Godot 4.7.2 remain unverified.
