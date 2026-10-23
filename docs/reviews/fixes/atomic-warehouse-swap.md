# Reserve and commit the whole warehouse swap

Against main `0f641ab`. A gun displaces both the weapon and shield, but the
capacity guard considered only the weapon. With one free shelf, the weapon was
banked, the shield was removed, its banking failure was ignored, and success
was returned.

Preflight now counts every outgoing found item. Stored outgoing items need no
new shelf. Insufficient capacity returns before equipment, HP or storage changes.
All bank results are checked. An unexpected later rejection rolls back equipment,
displaced gear, outgoing storage markers, HP/MP, warehouse entries and flags,
and persists the rollback. Synchronous inventory mutations suppress Events
signals, restoring their prior block state and emitting one final HP refresh.

No capacity, eligibility, HP policy, price or original gear rule changes.
This is logical transaction rollback, not filesystem crash atomicity; profile
write failures remain a separate persistence issue. With the identity branch,
allocator gaps after rollback are harmless and deliberately never reused.

```
godot --headless --fixed-fps 60 --path . res://tests/combat/warehouse_swap.tscn
```

13 checks pass under available Godot 4.6.3 (target 4.7.2), no SCRIPT ERROR. They
exercise the real gun swap with one/two/zero free shelves, found/stored outgoing
pieces, reload, repeat rejection, and an injected rejection of the second bank.
Restoring only RunCity to main gives 10 failed assertions and exits 1 without
SCRIPT ERROR: capacity rejection/state/markers, subsequent complete bank and
reload, and injected-failure return/rollback/markers/persistence (some successful
swap assertions necessarily follow the initial rejection case).

The synchronous fixture runs in rest before map-dependent checks, restores every
Profile field and replaced Run field plus both RNG values and signal blocking.
Existing engine shutdown ObjectDB/resource warnings remain. Full smoke and
visual checks were not run because original runtime assets are absent. Target
Godot 4.7.2, actual rest UI and save interruption recovery remain unverified.

Persistence comparisons normalize both sides through JSON, so identity migration
casting uid values back to int does not create a false failure against JSON floats.
