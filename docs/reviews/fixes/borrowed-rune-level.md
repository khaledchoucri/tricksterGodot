# Borrowed runes cannot downgrade learned skills

Against main `0f641ab`. RunDeck.card_level returned the rune's level whenever its
ID matched, even when the permanent learned copy was stronger. Damage/value and
prerequisite queries could therefore regress after picking up a rune.

Reading: the effective level is the maximum of owned and borrowed levels.
Ownership is unchanged, a stronger rune remains temporary, and held_cards still
counts the skill once. Rune slots, region scaling, mastery and learning are not
redesigned. This is our rune-system interpretation, not an original-game claim.

```
godot --headless --fixed-fps 60 --path . res://tests/combat/rune_level.tscn
```

15 checks pass with no SCRIPT ERROR under available Godot 4.6.3 (target 4.7.2).
Restoring only RunDeck to main produces 5 failed assertions and exits 1 without
SCRIPT ERROR: owned/rune levels 3/1, 5/1, 5/3, actual take_rune retaining level 5,
and value/known-level queries. Controls cover borrowed-only, equal, stronger rune,
removing each source, unknown skills and deduplication.

The synchronous systems SmokeSection uses a private deck and a synthetic card
outside every Echo; no Profile/Run gameplay field is replaced. Both RNG values
are restored. Existing shutdown ObjectDB/resource warnings remain. Full smoke
and visuals were not run because original runtime assets are absent. Skill-cast
integration, HUD display and target Godot 4.7.2 remain unverified.
