"""Render a Trickster map to a PNG for checking the decoder.

usage: python -I render_map.py <map base path without extension> <out.png> [--scale 4]
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trickster_map as tm  # noqa: E402
from export_actor import write_png  # noqa: E402


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = bytearray(w * h * 4)

    def blit_tile(self, rgba, x0, y0, flip_h=False, alpha=1.0):
        for y in range(tm.TILE):
            ty = y0 + y
            if not 0 <= ty < self.h:
                continue
            row = rgba[y * tm.TILE * 4:(y + 1) * tm.TILE * 4]
            if flip_h:
                row = b''.join(row[i:i + 4] for i in range(len(row) - 4, -4, -4))
            if alpha >= 1.0 and all(row[i] == 255 for i in range(3, len(row), 4)):
                n = min(tm.TILE, self.w - x0)
                if n > 0:
                    o = (ty * self.w + x0) * 4
                    self.px[o:o + n * 4] = row[:n * 4]
                continue
            self._blend_row(row, x0, ty, alpha)

    def _blend_row(self, row, x0, ty, alpha):
        for x in range(len(row) // 4):
            a = row[x * 4 + 3]
            tx = x0 + x
            if not a or not 0 <= tx < self.w:
                continue
            o = (ty * self.w + tx) * 4
            if alpha >= 1.0:
                self.px[o:o + 4] = row[x * 4:x * 4 + 4]
            else:
                for c in range(3):
                    self.px[o + c] = int(self.px[o + c] * (1 - alpha) + row[x * 4 + c] * alpha)
                self.px[o + 3] = 255

    def blit_bitmap(self, bm, x0, y0, flip, alpha=1.0, mode=0):
        for y in range(bm.h):
            sy = bm.h - 1 - y if flip & 2 else y
            ty = y0 + y
            if not 0 <= ty < self.h:
                continue
            row = bm.rgba[sy * bm.w * 4:(sy + 1) * bm.w * 4]
            if flip & 1:
                row = b''.join(row[i:i + 4] for i in range(len(row) - 4, -4, -4))
            if mode == 0:
                self._blend_row(row, x0, ty, alpha)
            else:  # additive / darken modes approximated as half-strength blend
                self._blend_row(row, x0, ty, 0.5 * alpha)


def render(m, draw_objects=True):
    """Draws each layer in file order: its tiles, then the objects placed on it."""
    c = Canvas(m.width, m.height)
    anims = {a.title: a for a in m.bac.anims} if m.bac else {}

    def draw_objects_of(objs):
        for o in sorted(objs, key=lambda o: o.y):
            a = anims.get(o.anim)
            if not a or not a.frames:
                continue
            for p in a.frames[0].planes:
                bm = m.bac.bitmaps[p.bmp]
                if bm is not None:
                    c.blit_bitmap(bm, o.x + p.x, o.y + p.y, p.flip,
                                  p.opacity / 100.0 if p.opacity < 100 else 1.0, p.blend)

    for layer in m.layers:
        if isinstance(layer, tm.GridLayer):
            for i, cell in enumerate(layer.cells):
                t = tm.tile_for(m, cell)
                if t is not None:
                    rgba, flags = t
                    c.blit_tile(rgba, (i % layer.cols) * tm.TILE, (i // layer.cols) * tm.TILE,
                                flip_h=bool(flags & 1))
        if draw_objects:
            draw_objects_of(layer.objects)
    return c


def downscale(c, s):
    w, h = c.w // s, c.h // s
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            o = ((y * s) * c.w + x * s) * 4
            out[(y * w + x) * 4:(y * w + x) * 4 + 4] = c.px[o:o + 4]
    return w, h, bytes(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('base')
    ap.add_argument('out')
    ap.add_argument('--scale', type=int, default=4)
    ap.add_argument('--no-objects', action='store_true')
    args = ap.parse_args()
    m = tm.read_map(args.base)
    c = render(m, not args.no_objects)
    w, h, px = downscale(c, args.scale) if args.scale > 1 else (c.w, c.h, bytes(c.px))
    write_png(args.out, w, h, px)
    print(f'{args.out}: {w}x{h}')


if __name__ == '__main__':
    main()
