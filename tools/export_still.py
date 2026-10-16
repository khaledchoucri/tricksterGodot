"""Export the first frame of a NORI sprite as a PNG (NPC portraits, item art).

usage: python -I export_still.py <file.nri> <out.png>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402
from export_actor import blit, write_png  # noqa: E402


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    n = nori.read(sys.argv[1])
    frame = next(a.frames[0] for a in n.anims if a.frames)
    x0 = min(p.x for p in frame.planes)
    y0 = min(p.y for p in frame.planes)
    x1 = max(p.x + n.bitmaps[p.bmp].w for p in frame.planes)
    y1 = max(p.y + n.bitmaps[p.bmp].h for p in frame.planes)
    w, h = x1 - x0, y1 - y0
    img = bytearray(w * h * 4)
    for p in frame.planes:
        blit(img, w, h, n.bitmaps[p.bmp], p.x - x0, p.y - y0, p.flip & 1, p.flip & 2)
    os.makedirs(os.path.dirname(os.path.abspath(sys.argv[2])), exist_ok=True)
    write_png(sys.argv[2], w, h, bytes(img))
    print(f'{os.path.basename(sys.argv[2])}: {w}x{h}')


if __name__ == '__main__':
    main()
