# Shot 9 — skill icon content

Based on `docs/art-direction/art-round-2.md` at `b14a70b`, with the inherited style paragraph from `art-test-v0.2.md`. Branch: `art/skill-icons`.

This is a bounded contribution alongside the other agent's Megalopolis work: **only `art/icons/skills/` is changed**. No hub, gameplay, UI, importer, content resource, or project configuration edits. No new skills or mechanics were invented.

Open [review.html](review.html) for all seven at 48/96/256px. All 512px deliveries are opaque, square and full-bleed. Review approval remains pending; small-size review is a standalone visual check, not an integrated gameplay pass.

| Skill | Delivery | Element | Generations including rejects | Approx. summed tool time |
|---|---|---|---:|---:|
| Lacerator | `lacerator.png` | none | 1 | 32.8 s |
| Piercing Wave | `piercing_wave.png` | earth | 2 | 103.9 s |
| Inferno Blade | `inferno_blade.png` | fire | 1 | 59.3 s |
| Lightning Strike | `lightning_strike.png` | lightning | 1 | 91.3 s |
| Upper Smash | `upper_smash.png` | none | 1 | 46.8 s |
| Shockwave | `shockwave.png` | none | 1 | 87.6 s |
| Tornado Bomb | `tornado_bomb.png` | wind | 1 | 121.0 s |

Total: **8 generations, 7 candidates, 1 reject**. Times are approximate wall times per call, summed even where calls ran concurrently; they are not billing or total elapsed task time. No model identifier or seed was exposed by the image tool. Every generation was independent text generation, with no image references and no names of other games in its prompt.

## Direction and mechanic coverage

- Lacerator: opposing crescents for front/back spinning cuts; steel blue.
- Piercing Wave: one directional crescent through three target marks; ochre.
- Inferno Blade: steel sword/gold guard/red grip in a curved flame trail; orange-red.
- Lightning Strike: bolt meeting a distinct ground burst; violet.
- Upper Smash: airborne fighter with a visible gap above a cracked landing impact; gold.
- Shockwave: planted fist and concentric rings, distinct from the airborne skill; sand.
- Tornado Bomb: teal funnel with surrounding shapes drawn inward.

The heavier tapered ink, angular planes, colored shadows and cyan-white rim accents follow the B2 rendering brief. Backgrounds stay quieter than the central symbols. Painted texture remains visible at large sizes; the48px preview is the relevant readability check.

## Sources and technical export

The image tool returned 1254×1254 PNGs despite the requested512×512 size. Untouched originals are in `sources/` with a sibling exact `.txt` prompt. Delivered `<id>.png` files are 512×512 RGB exports. Technical export uses only Godot Lanczos resizing and RGB conversion; no cropping, repainting, background replacement or compositional edits. Reproduce with:

```sh
godot --headless --path . --script res://art/icons/skills/export_sizes.gd
```

Godot 4.6.3 was used for this image-only export; no claim about the project's requested 4.7 gameplay compatibility follows. `generation-log.json` records source/export hashes, dimensions, existing skill row IDs and elements.

## Reject

`rejected/piercing_wave_01.png` became a detailed battle illustration with scenery and mannequin targets. It was rejected for the simple-background/48px-symbol requirement. Its prompt and reason are preserved. The rerun uses plain dark rectangular target marks and a featureless tinted background.

## Integration handoff for the runtime owner

The existing `scripts/ui/skill_slot.gd` resolves `original_assets/icons/<skill_id>.png`. These new icons deliberately use the skill string IDs prescribed by Shot 9: `res://art/icons/skills/<card.id>.png`. The runtime owner can add that lookup first and retain the old numeric-ID asset as fallback. This content branch does not edit that shared runtime file.

No skill/card statistics or behavior changed. Import the PNGs through Godot normally, review them in the actual skill slots and cooldown states, and then decide whether any need simplification. Character style/proportion selection, VFX and the 2b animation trial remain separate work.

## Checks performed

All seven exported files were checked as 512×512 RGB PNGs. Source/export hashes and per-image prompts were verified; source prompts contain the required style paragraph and no names of other games. The HTML review loaded all images. The full set was visually inspected at native 48 px in a browser: double arcs, the piercing crescent, burning sword, bolt impact, airborne figure, planted fist/rings, and funnel remain distinct. Actual HUD/cooldown-overlay review and user approval are still pending.
