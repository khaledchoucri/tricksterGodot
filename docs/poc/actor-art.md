# Actor art contract

What the game needs from an actor's sprites and weapons. The Trickster sprites are converted to this by `tools/export_actor.py` and `tools/export_weapon.py`; new AI-generated art should be delivered the same way, and then no code changes are needed.

## Body sheets

- One sheet per action (`idle`, `run`, `walk`, `hit`, `dodge`, `cast`, `throw`, `weapon_crit`, ...), one row per direction, one column per frame.
- Every cell in every sheet is the same size and has the feet at the same pixel (the anchor).
- Directions: any subset of the 8 (`e se s sw w nw n ne`). The game picks the closest one the art has, and draws a missing side by mirroring the other, so 5 directions (`s se e ne n`) are enough. More directions make turning smoother: 8 for movement, at least the 4 diagonals for attacks.
- The body is drawn **without** the weapon.

## Hand socket

Each frame that holds a weapon has a hand socket in the manifest (`<actor>.json`):

```json
{"col": 3, "row": 1, "ms": 80, "hand": [-12, -30], "front": true}
```

- `hand`: the grip point, in pixels from the feet.
- `front`: true when the weapon draws over the body, false when it's behind it (for example, the far hand in a back view).

Frames without a socket hide the weapon. For the Trickster art the sockets come from the character's pivot file (`.pvt`, see `tools/pivots.py`). Generated frames drawn over a pose guide take the guide frame's socket (the importer reads it from `original_assets/pose_guides/`), so they need nothing extra as long as the hands follow the guide.

## Importing generated art

1. Put frames in `art/actors/<name>/<action>/<dir>/` on flat magenta. A file is one frame, or a strip of N frames side by side when its name ends in `_xN`.
2. Run `godot --headless --path . res://scenes/tools/art_import.tscn -- <name>`. It keys the background, aligns the feet, scales the actor consistently, crops to a padded cell and writes `art_build/<name>/` (sheets, manifest, SpriteFrames, palette).
3. Let Godot import the new sheets (open the editor, or `godot --headless --path . --import`), then run `scenes/tools/art_lab.tscn` to see the result moving at game size next to the current sprite.

Imported actors use `shaders/actor_style.gdshader`: an engine-drawn ink outline and an optional palette lock that snaps colours to the character's palette.

## Weapons

One image per weapon, drawn pointing right, plus a JSON file:

```json
{"grip": [2, 5], "angle": 0.50, "length": 43}
```

- `grip`: the pixel held in the hand.
- `angle`: the blade's direction in the image, in radians.
- `length`: the blade's reach, in pixels.

The game rotates the weapon around the grip. While carried it points the way the actor faces; during a swing it sweeps the attack's arc, so swings match the hitbox and trail in every direction. Weapons can be swapped without redrawing the body.
