# Art test — brief v0.2

Updates the v0.1 package for the current project and narrows it to one test: can we produce consistent, animated, game-ready art for one character, one monster and a small beach kit? Where this file and v0.1 disagree, this file wins.

## What changed since v0.1

| v0.1 | Now |
|---|---|
| Direct Trickster Online remake, online later | Single-player roguelite homage with its own story ("Last Login"): the world of a dead MMO whose NPCs realise you're the last player |
| Bunny first, punches and gloves | **Buffalo first**, Knight line, **longsword** |
| Faithful canonical likeness | **Inspired by the original designs, not copied**: keep the silhouette landmarks and colour blocks, redesign the details |
| "Sunlit ink-and-paint" | **Close to Hades** (bold ink lines, saturated painterly colour, strong rim light, graphic shapes) but **bright, warm and friendly**, not dark or menacing |
| Drilling, companion, Megalopolis in the first slice | Not in this test |
| 61 batches, seven agents, gates A–E | This shot list, one reviewer (us), playback in the game |

The engine contract is `docs/poc/actor-art.md` (body without weapon, a hand point per frame, weapon as a separate sprite, any set of directions with mirroring). The v0.1 camera contract still applies: 2:1 dimetric view, 512 × 512 frame canvas, feet at pixel (256, 420), about 320 px from feet to crown.

## What the generator can and can't do

Codex makes images with OpenAI's GPT Image models (gpt-image-2 or later) through its `$imagegen` skill. Findings from current documentation and developer reports:

- **Good at:** single illustrations, model sheets, props, tiles, icons, effects, portraits. It accepts up to about four reference images and can edit an image with a mask.
- **No transparent backgrounds** on gpt-image-2. Generate on a flat chroma colour (magenta `#FF00FF` for this project, green for magenta-heavy subjects) and key it out afterwards.
- **No seeds or exact repeatability.** Keep every prompt and every output.
- **Weak at consistency across many images.** Characters drift between generations; whole sprite sheets in one image come out incomplete or with repeated poses; it confuses the character's left and right; isometric angles are hard to hold. Developers who succeeded generated **one frame at a time**, each from a clear **pose reference image** plus the **character reference**, and re-ran instead of asking for fixes.

So characters need a guided route. This test compares two:

- **Route A, 2D pose transfer.** For each frame, attach (1) a pose guide for that frame and (2) the approved character sheet, and ask for the character in exactly that pose. Pose guides come from our own exported Trickster animations (we have every frame of idle, run and the sword swing in every direction) or from a plain mannequin. Only the pose and timing are borrowed, not the design.
- **Route B, 3D to sprites.** Turn the approved character sheet into a 3D model (an image-to-3D tool), rig and animate it, and render every frame from our camera in Blender with an ink-and-paint shader. Consistency across directions and frames is guaranteed, hand points come from the hand bone automatically, and this is close to how Supergiant produced Hades' character sprites. It needs extra tools (see "Tools").

Environments, props, icons and effects use direct generation (single images); that's where the model is strong.

## Style

Use these words in every prompt. Don't name another game in prompts.

> Hand-painted game art. Bold, confident dark-ink outlines of varying weight; saturated painterly colour in broad planes with selective texture; strong warm key light from the upper left and a cool rim light; graphic, readable silhouettes. Bright, sunlit, warm and friendly, a coastal adventure mood, never dark, gritty or menacing. Clean edges, no photorealism, no text.

Palette anchors from the v0.1 visual bible: sand `#F3DFBC`, coral `#E98070`, sea teal `#2AADB4`, deep ink `#233B52` (outlines), sun gold `#D5A64B`, skill cyan `#81D5E8`. Hostile red `#D94C49` is reserved for enemy threats.

## Buffalo: design brief

Inspired by the original Buffalo, not a copy. Keep:

- A wrapped cream headwrap with an ornamental red-and-gold band (the original's strongest landmark); short dark hair with a few strands showing.
- A red sleeveless top with light trim, bare strong arms, wrapped wrists.
- Loose khaki trousers gathered at the shin, sturdy grey boots.
- A young, cheerful, sturdy fighter, roughly 5 heads tall.

Change and add (our own design):

- A small buffalo-horn motif worked into the headwrap band, and a single leather pauldron on the sword arm (right shoulder).
- A belt with a scabbard on the left hip (empty in animations: the sword is a separate sprite).
- Simplify costume details so they read at about 150 px tall.
- Keep the design **left/right symmetric enough to mirror**, except the pauldron and scabbard; mirrored directions are allowed if those two read acceptably mirrored. If not, we draw all 8 directions.

The **longsword** is its own image: a plain, sturdy steel longsword with a gold crossguard and a red-wrapped grip, about 1.2× the length of Buffalo's leg.

## Shot list

Each item lists what to deliver; generate on magenta `#FF00FF` unless it's a scene.

1. **Style options:** Buffalo, same heroic standing pose, full body, three treatments:
   - A: softer painterly.
   - B: the style above (recommended).
   - C: flatter, graphic cel shading.

   Plus one small Coral Beach clearing in each treatment from the game camera (2:1 view, looking down about 30°), with Buffalo at game size. **Pick one before going on.**
2. **Model sheet:** the chosen style, front, back, left, right and three-quarter views, arms relaxed, hands empty. Close-ups of the face (neutral, determined, happy) and the hands.
3. **Sword:** pointing right, horizontal, flat lighting, magenta background. Mark the grip pixel.
4. **Game-camera turnaround:** idle pose in 5 directions (s, se, e, ne, n) seen from the game camera, each on its own 512 × 512 canvas, feet at (256, 420), body about 320 px. Then w, sw, nw (to test mirroring against drawn sides).
5. **Animation trial:** idle (4 frames), run (8 frames) and sword slash (6 frames), in se and nw first.
   - Route A: one generation per frame with the pose guide and model sheet attached.
   - Route B: rendered from the rig.
6. **Monster:** a small round, fluffy beach creature inspired by Torobbie (cute first, a little mischievous). Model sheet, then idle (4) and attack (5) in se.
7. **Beach kit:**
   - 4 seamless sand ground tiles.
   - 1 sand-to-grass edge.
   - A palm with trunk and canopy as separate images.
   - A coral cluster, a rock and a beach parasol.
   - Each prop shows where its base touches the ground.
8. **Effects:** a sword slash arc, a hit spark and a dust puff, on black (for additive blending).

## Prompt templates

Character frame, Route A (attach pose guide as image 1, model sheet as image 2):

> Draw the character from image 2 in exactly the pose of image 1. Copy the pose, camera angle and limb positions from image 1 precisely, without mirroring; left and right refer to the character's own body. Keep every costume detail, colour and proportion from image 2. Hands empty. Full body, centred, feet at the same height as image 1. [Style paragraph.] Flat solid magenta (#FF00FF) background, no shadow, no ground, no text.

Model sheet:

> Character model sheet for a game: [Buffalo design brief]. Front, back, left side, right side and three-quarter views in a row, same scale, neutral standing pose, arms relaxed, hands empty. [Style paragraph.] Flat solid magenta (#FF00FF) background, no text or labels.

Prop:

> A single [prop] for a 2D isometric game, seen from above at about 30 degrees (2:1 dimetric). [Style paragraph.] Centred, whole object visible, flat solid magenta (#FF00FF) background, no shadow, no text.

Re-run with the same prompt rather than asking for corrections; save every output with its prompt.

## How we judge it

Everything is judged in the game, not as stills. A small preview scene shows the new frames at game size next to the current sprites. A frame set passes when:

- Buffalo is recognisably the same character in every frame and direction.
- The feet stay planted where they should (no sliding against movement), and the anchor doesn't jitter.
- The slash reads (wind-up, strike, follow-through) and the separate sword fits the hand in every frame.
- Mirrored directions look right, or we know we need all 8.
- It all reads at game size against the beach.

**Track the cost too:** how many generations per accepted frame, and how long it took. That decides whether a full character (about 300–400 frames) is affordable by this route.

## Delivery

- Put everything under `art/test/<shot number>-<name>/` (for example `art/test/01-style/`), one PNG per image with a `.txt` beside it holding the exact prompt and the reference images used. Name images `<subject>_<variant>_<nn>.png`.
- Keep rejected outputs in a `rejected/` subfolder with a one-line reason; they show what the generator struggles with.
- Add a short `NOTES.md` per shot: what was tried, how many generations it took, what failed.
- Never commit anything from `original_assets/` (it's the original game's art and is git-ignored). Pose guides cut from it stay local; only the newly generated images are committed.
- Don't change game code; importing the art into the game is a separate step.
- **Stop after shot 1** so the style can be chosen, and again after shot 5 for the route comparison.

## Tools

- **Route A:** Codex `$imagegen` only, plus our import script (chroma key, alignment to the canvas and foot anchor, sheets and manifest for the game).
- **Route B, also needs:**
  - **Image to 3D:** an image-to-3D model generator. Either a web service (for example Meshy or Tripo, some include rigging) or an open model run locally (for example Hunyuan3D). This PC's RTX 3070 can likely run the smaller open models.
  - **Rigging:** an auto-rigger (for example Mixamo, free with an Adobe account).
  - **Rendering:** Blender (free), scripted to render 8 directions with an ink-and-paint shader and write hand points from the hand bone.
