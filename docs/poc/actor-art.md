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

Frames without a socket hide the weapon. For the Trickster art the sockets come from the character's pivot file (`.pvt`, see `tools/pivots.py`). For new art, mark the grip with a single pure magenta (`#FF00FF`) pixel on a separate layer, plus a second layer or a flag for front or behind, so the exporter can read it.

## Weapons

One image per weapon, drawn pointing right, plus a JSON file:

```json
{"grip": [2, 5], "angle": 0.50, "length": 43}
```

- `grip`: the pixel held in the hand.
- `angle`: the blade's direction in the image, in radians.
- `length`: the blade's reach, in pixels.

The game rotates the weapon around the grip. While carried it points the way the actor faces; during a swing it sweeps the attack's arc, so swings match the hitbox and trail in every direction. Weapons can be swapped without redrawing the body.
