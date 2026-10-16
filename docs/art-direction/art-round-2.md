# Art round 2

Follows `art-test-v0.2.md` and the shot 1 review. Two parts: **2a** settles style and proportions and starts the assets that don't need animation; **2b** is the animation test. Do 2a, stop for the choice, then 2b.

**Run Codex locally in this checkout** (`C:\Users\Khaled\source\repos\tricksterGodot`). 2b needs the pose guides in `original_assets/pose_guides/`, which are git-ignored and exist only on this machine. Never commit anything from `original_assets/`.

Logging stays as in v0.2: a `.txt` prompt beside every image, rejects in `rejected/` with a reason, a `NOTES.md` per shot with generation counts and time.

## Shot 1 review

Design B (`art/test/01-style/buffalo_b_01.png`) is the base: the costume landmarks work and read well at game size. The beach direction (`coral_beach_b_01.png`) is approved. What needs another pass:

- A, B and C were restyles of one image and look almost identical at game size, so no real style choice was possible.
- The rendering is soft and generic; it lacks heavy tapered ink, angular graphic shapes, rim light and coloured shadows.
- Realistic adult proportions (about 5.5 heads) lose the original's charm, and the face disappears at game size.
- The scabbard reads as a pipe or quiver. **Remove it**; the sword is always in hand in the game.
- He's drawn from eye level; game sprites are seen from above (about 30 degrees down), showing the top of the headwrap and shoulders.

## 2a — style, proportions, icons, effects

### Shot 1b: style and proportions

Save to `art/test/01b-style/`. Generate each option **independently** from the brief text plus `buffalo_b_01.png` as a costume reference only. Don't restyle one option from another; they must differ visibly at 150 px tall. For all three: no scabbard, seen from above at about 30 degrees, same costume landmarks, empty hands, magenta background.

1. **B2 "Hades push":** heavier tapered dark-ink outlines, more angular graphic shapes, strong cyan-white rim light, saturated warm shadows (coral and violet rather than grey). Still bright and friendly.
2. **B3 "chunky charm":** B2's rendering with chibi-leaning proportions, about 4 heads tall, bigger head, eyes and hands, a little younger and more cheerful.
3. **B4 "middle":** about 4.5 heads, between B2 and B3.

Then place B2, B3 and B4 into the `coral_beach_b_01` scene at game size (about 150 px tall at 1152 px wide).

### Shot 9: skill icons

Save to `art/icons/skills/<id>.png`, one per skill, square, 512 × 512, full-bleed (no magenta, no transparency needed). Same style as B2. A clear central symbol on a simple tinted background, readable at 48 px, no text. The tint carries the element:

| id | Skill | Element / tint | Symbol idea |
|---|---|---|---|
| `lacerator` | Lacerator | none / steel blue | two crescent sword arcs, front and back |
| `piercing_wave` | Piercing Wave | earth / ochre | a crescent wave shooting forward through a line |
| `inferno_blade` | Inferno Blade | fire / orange-red | a spinning sword with a flame trail |
| `lightning_strike` | Lightning Strike | lightning / violet | a bolt striking the ground with a burst |
| `upper_smash` | Upper Smash | none / gold | a figure leaping and a ground crack below |
| `shockwave` | Shockwave | none / sand | concentric rings bursting from a fist on the ground |
| `tornado_bomb` | Tornado Bomb | wind / teal | a whirlwind pulling small shapes inward |

### Shot 8: effects

Save to `art/vfx/`, on pure black (`#000000`) for additive blending, 1024 × 1024 unless noted:

- `slash_arc.png`: a single bright crescent sword trail, thick at the leading edge and tapering, seen from above at 30 degrees.
- `hit_spark.png`: a sharp star-shaped impact flash with a few streaks.
- `dust_puff.png`: a small soft dust cloud (this one on magenta instead of black; it isn't additive).
- `lightning_bolt.png`, 512 × 1536: a vertical jagged bolt with a glow.
- `energy_crescent.png`: a glowing cyan crescent wave front.

**Stop after 2a** for the style and proportion choice.

## 2b — animation test (after the choice)

The question: which method gives frames consistent enough to play smoothly, at what cost? Use the chosen 1b option's character image as the model reference in every generation. Test Buffalo's **run facing south-east**, plus one idle frame in each method (the importer uses it to set the scale).

The pose guides are in `original_assets/pose_guides/buffalo/`: grey mannequins on magenta, on a 512 × 512 canvas with the feet at (256, 420). Each direction folder has `frame_NN.png`, `strip_00-03.png` and `strip_04-07.png` (four guide frames side by side), `contact.png` and `guide.json`.

In every prompt: copy the guide's pose, limb positions, lean and foot placement exactly, without mirroring; left and right are the character's own. **Copy the pose, not the proportions:** the character keeps the chosen proportions. Hands empty. One character per frame, centred like the guide, feet on the same line. Flat magenta background, no shadow, no ground.

| Method | Folder | What to make |
|---|---|---|
| M1 one frame at a time | `art/actors/buffalo_m1/` | `idle/se/frame_00.png` from `idle/se/frame_00.png`; `run/se/frame_00.png` … `frame_07.png`, one generation per guide frame |
| M2 four-frame strips | `art/actors/buffalo_m2/` | `idle/se/frame_00.png`; `run/se/run_a_x4.png` from `strip_00-03.png` and `run/se/run_b_x4.png` from `strip_04-07.png`: each one image with four frames side by side, evenly spaced, same size as the guide strip |
| M3 key poses | `art/actors/buffalo_m3/` | `idle/se/frame_00.png`; `run/se/frame_00.png`, `frame_01.png`, `frame_02.png`, `frame_03.png` from guide frames 00, 02, 04 and 06 only; add `actor.json` containing `{"frame_ms": {"run": 160}}` |

For each method, record generations per accepted frame and the time taken.

Then check the results in the game (this needs the Godot console executable; ask the user for its path if it isn't on PATH):

1. `godot --headless --path . res://scenes/tools/art_import.tscn -- buffalo_m1` (repeat for m2 and m3)
2. `godot --headless --path . --import`
3. `godot --path . res://scenes/tools/art_lab.tscn -- --shot art/test/05-animation/lab.png` for a still of all three next to the current Buffalo

Write `art/test/05-animation/NOTES.md` comparing the methods: identity drift between frames, foot placement, flicker, left/right mistakes, cost. Commit `art/` only (never `art_build/` or `original_assets/`) and stop.
