# Persistent warehouse identity

Against main `0f641ab`. A live GearItem.stored retained a shelf index after
Profile.discard_item compacted the warehouse. Port/victory writes then silently
missed the item or overwrote a neighbour; death could remove the wrong shelf.

GearItem.stored now holds a persistent `uid`, serialized with the gear. Profile
allocates monotonically increasing IDs, persists the allocator, and resolves a
live identity to its current shelf before updating or removing it. Port retries
update an existing identity instead of duplicating it. Lost bags carry IDs;
recovered items keep them. Missing identities fail banking and are returned as
unresolved victory overflow rather than silently overwriting another item.

Schema 3 saves loadouts and pending legacy heirlooms by ID. Version 1/2 saves
receive IDs for every warehouse and lost-bag entry, including identical pieces
and unknown item definitions. UI-facing loadout values and existing warehouse
APIs still use current shelf indices; no hub UI change is needed. The next save
writes schema 3. Downgrading an upgraded save to older code is unsupported.

This deliberately leaves capacity, loss/recovery rules, swap atomicity, HP
handling, and item balance unchanged. It does not make multi-write transactions
or filesystem saves crash-atomic. Corrupt-save recovery beyond assigning missing
or duplicate item IDs is outside this fix.

## Focused validation

```
godot --headless --fixed-fps 60 --path . res://tests/combat/warehouse_identity.tscn
```

21 checks pass under available Godot 4.6.3 (project target: 4.7.2). The synchronous
SmokeSection also runs at the start of systems. It restores every Profile script
field, replaced Run fields, and Run.rng.seed/state; it neither awaits frames nor
boots the game. Save files use a throwaway path removed before state restoration.

Counterfactual: with only RunCity restored to `origin/main` (retaining the new
schema/API so the test compiles), 8 assertions fail: worn lookup after compaction,
Port write/reload, victory progress, duplicate Port retry, death removal, bag
identity recovery, stale banking rejection and unresolved overflow retention.
The counterfactual exits 1 without SCRIPT ERROR. Migration checks separately
verify distinct IDs, loadout resolution, pending heirloom compaction/removal,
JSON reload and non-reuse of discarded IDs. Fixed run has no SCRIPT ERROR.
Existing engine shutdown diagnostics report ObjectDB/resource leaks.

Full smoke and visual checks were not run: original runtime assets are absent.
Godot 4.7.2 and real hub/rest-stop/save integration remain unverified.
