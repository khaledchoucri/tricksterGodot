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


def _inside(p, w, h, margin=0.25):
    """True if p lies well inside the w x h image, away from every edge."""
    return margin * w < p[0] < (1 - margin) * w and margin * h < p[1] < (1 - margin) * h


def _mass(pixels, p, r=5):
    """Opaque pixels within r of p: a hammer head is heavier than its handle."""
    return sum(1 for q in pixels if abs(q[0] - p[0]) <= r and abs(q[1] - p[1]) <= r)


def export(nri_path, out_png):
    """Writes out_png and its .json; returns False if no right-pointing frame exists."""
    item = nori.read(nri_path)
    best = None
    for fr in item.anims[0].frames:
        p = fr.planes[0]
        bm = item.bitmaps[p.bmp]
        img = bytearray(bm.w * bm.h * 4)
        blit(img, bm.w, bm.h, bm, 0, 0, p.flip & 1, p.flip & 2)
        grip = (-p.x, -p.y)
        pixels = [(x, y) for y in range(bm.h) for x in range(bm.w) if img[(y * bm.w + x) * 4 + 3]]
        if not pixels:
            continue
        # Blade direction: from the grip toward the farthest opaque pixel.
        tip = max(pixels, key=lambda q: math.hypot(q[0] - grip[0], q[1] - grip[1]))
        if _inside(grip, bm.w, bm.h):
            # Some sprites (hammers, sticks) are centred on the art, not the
            # hand: hold them by the end of the long axis with less mass.
            a = tip
            b = max(pixels, key=lambda q: math.hypot(q[0] - a[0], q[1] - a[1]))
            grip, tip = (a, b) if _mass(pixels, a) < _mass(pixels, b) else (b, a)
        far = math.hypot(tip[0] - grip[0], tip[1] - grip[1])
        if tip[0] > grip[0] and (best is None or far > best[3]):
            best = (bm, img, grip, far, tip)
    if not best:
        return False
    bm, img, grip, length, tip = best
    write_png(out_png, bm.w, bm.h, bytes(img))
    info = {'grip': list(grip), 'angle': math.atan2(tip[1] - grip[1], tip[0] - grip[0]), 'length': length}
    with open(os.path.splitext(out_png)[0] + '.json', 'w') as f:
        json.dump(info, f)
    print(f'{os.path.basename(out_png)}: {bm.w}x{bm.h}, grip {grip}, length {length:.0f}')
    return True


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    if not export(sys.argv[1], sys.argv[2]):
        sys.exit('no right-pointing frame found')


if __name__ == '__main__':
    main()
