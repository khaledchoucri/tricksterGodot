"""Export a held weapon sprite for the game's HeldWeapon node.

Trickster item sprites (data/equip/weapon*.nri) hold one animation with two
frames: the weapon pointing left and pointing right, each offset so that the
origin is the grip. This writes the right-pointing image, the grip pixel, and
the blade's angle and length, so the game can rotate the weapon freely
around the hand.

usage: python -I export_weapon.py <item.nri> <out.png>   (writes <out>.json too)
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402
from export_actor import blit, write_png  # noqa: E402


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    item = nori.read(sys.argv[1])
    best = None
    for fr in item.anims[0].frames:
        p = fr.planes[0]
        bm = item.bitmaps[p.bmp]
        img = bytearray(bm.w * bm.h * 4)
        blit(img, bm.w, bm.h, bm, 0, 0, p.flip & 1, p.flip & 2)
        grip = (-p.x, -p.y)
        # Blade direction: from the grip toward the farthest opaque pixel.
        far, tip = -1.0, (0, 0)
        for y in range(bm.h):
            for x in range(bm.w):
                if img[(y * bm.w + x) * 4 + 3]:
                    d = math.hypot(x - grip[0], y - grip[1])
                    if d > far:
                        far, tip = d, (x, y)
        if tip[0] > grip[0] and (best is None or far > best[3]):
            best = (bm, img, grip, far, tip)
    if not best:
        sys.exit('no right-pointing frame found')
    bm, img, grip, length, tip = best
    write_png(sys.argv[2], bm.w, bm.h, bytes(img))
    info = {'grip': list(grip), 'angle': math.atan2(tip[1] - grip[1], tip[0] - grip[0]), 'length': length}
    with open(os.path.splitext(sys.argv[2])[0] + '.json', 'w') as f:
        json.dump(info, f)
    print(f'{os.path.basename(sys.argv[2])}: {bm.w}x{bm.h}, grip {grip}, length {length:.0f}')


if __name__ == '__main__':
    main()
