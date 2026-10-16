# QA backlog

Known issues in the prototype, roughly in priority order. Move these to GitHub issues when convenient.

## Tune skill numbers from playtests

Skill damage, MP costs and cooldowns (`data/coral_beach/cards/*.tres`) are first guesses, checked only on paper:

| Skill | Damage Lv1 (+ per level) | MP | Cooldown |
|---|---|---|---|
| Lacerator | 30 (+8), front and back | 18 | 3.5 s |
| Piercing Wave | 34 (+9), line | 22 | 4.5 s |
| Inferno Blade | 12 (+3) per tick, plus burn | 26 | 6 s |
| Lightning Strike | 40 (+10) on 3+ enemies, stun | 32 | 7 s |
| Upper Smash | 46 (+11), area, stun | 28 | 6 s |
| Shockwave | 38 (+9), area, knockback | 20 | 4.5 s |
| Tornado Bomb | 10 (+3) per 0.28 s, pull | 28 | 8 s |

MP: 100 max, +5 per enemy hit by the combo, +40 on entering a room. The basic combo does 22 / 24 / 40 over about 1.1 s.

Target: skills about 35–40% of damage dealt, with no single skill clearly best. Questions for playtests: is MP too plentiful, and do skills make elites trivial?

## Attack poses exist in only 4 diagonal directions

The original Buffalo sprite has attack, cast and throw poses only for se, sw, nw and ne; movement has all 8. The body picks the closest diagonal while the sword and trail follow the exact aim, so aiming straight along an axis still shows a diagonal pose. The new art should provide attack poses in at least 5 directions (s, se, e, ne, n); `ActorSprite` mirrors the other side. See `actor-art.md`.

## Silhouette tints the whole body when only part is hidden

`Silhouette` draws the outline over the whole sprite even where nothing covers Buffalo, so the visible parts look washed out next to the faded prop. Show it only where a prop actually covers him: test each pixel against the covering props in the shader, or draw the silhouette under the props and the real sprite on top.

## Check skill sounds and the missing Lightning Strike icon

Skill sounds (`SKILL_SOUNDS` in `tools/setup_assets.py`) were assigned from file names without listening; reassign any that don't fit. Lightning Strike's icon (SkillParam2 1211) isn't in the client, so its slot shows an empty tile.

## Golden Mole uses placeholder dialogue

`scripts/boss_mole.gd` speaks placeholder lines. Export the boss's original lines from the client tables (into `original_assets/`) or write new ones for the story.

## Faint stripes around some grass areas in decoded maps

A few faint lines remain around some grass patches in `ground.png`, likely a decal or tile-flag case `tools/trickster_map.py` doesn't handle yet. Low priority: the original maps are placeholders.
