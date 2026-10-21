"""Export a Trickster map for Godot.

Writes to <out_dir>:
  ground.png      every flat layer baked together (tiles, decals, shadows)
  collision.png   walkability mask from the .md3 (white = blocked), 16 px cells
  ground_type.png ground material per 16 px cell (red channel = value)
  objects/*.png   one image per upright object animation, frame 0
  map.json        sizes, object placements and sprite anchors

usage: python -I export_map.py <map base path without extension> <out_dir>

The output belongs in the git-ignored `original_assets/` folder.
"""
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trickster_map as tm  # noqa: E402
from export_actor import write_png  # noqa: E402
from render_map import Canvas  # noqa: E402

# Object layer kinds seen in the files: 3 grass, 5 shadows, 6 main props, 7 effects.
UPRIGHT_KINDS = {6}
TOP_KINDS = {7}
MD3_WALK, MD3_GROUND = 1, 3


def md3_sections(b: bytes) -> dict:
    """Grid sections after the header: (type, cols, rows, cell w, cell h, bytes)."""
    out = {}
    p = 0x60
    while p + 20 <= len(b):
        t, c, r, cw, ch = struct.unpack_from('<5i', b, p)
        if c <= 0 or r <= 0 or c * r > len(b) - p - 20 or cw <= 0:
            break
        # Some town maps repeat a type with a tiny coarse grid; keep the
        # first (full-resolution) section of each type.
        out.setdefault(t, (c, r, cw, b[p + 20:p + 20 + c * r]))
        p += 20 + c * r
    return out


# A plane offset past this is garbage: the Gate of Caballa Relics' hamster has one at
# 0xCDCDCDCD (MSVC's fill for uninitialised memory), which the game can't have drawn.
PLANE_LIMIT = 1 << 16


def drawn_planes(bac, anim):
    """The first frame's planes that have a bitmap and a sane offset."""
    return [p for p in anim.frames[0].planes
            if bac.bitmaps[p.bmp] is not None and abs(p.x) < PLANE_LIMIT and abs(p.y) < PLANE_LIMIT]


def draw_anim_frame(canvas, bac, anim, x, y):
    for p in drawn_planes(bac, anim):
        bm = bac.bitmaps[p.bmp]
        if bm is not None:
            canvas.blit_bitmap(bm, x + p.x, y + p.y, p.flip,
                               p.opacity / 100.0 if p.opacity < 100 else 1.0, p.blend)


def export(base: str, out: str) -> dict:
    m = tm.read_map(base)
    anims = {a.title: a for a in m.bac.anims} if m.bac else {}
    os.makedirs(os.path.join(out, 'objects'), exist_ok=True)

    ground = Canvas(m.width, m.height)
    upright, top = [], []
    for layer in m.layers:
        if isinstance(layer, tm.FloorLayer):
            ground.blit_rows(layer.rows)
        if isinstance(layer, tm.GridLayer):
            for i, cell in enumerate(layer.cells):
                t = tm.tile_for(m, cell)
                if t is not None:
                    ground.blit_tile(t[0], (i % layer.cols) * tm.TILE, (i // layer.cols) * tm.TILE,
                                     flip_h=bool(t[1] & 1))
        kind = getattr(layer, 'kind', -1)
        for o in sorted(layer.objects, key=lambda o: o.y):
            a = anims.get(o.anim)
            if not a or not a.frames:
                continue
            if kind in UPRIGHT_KINDS:
                upright.append(o)
            elif kind in TOP_KINDS:
                top.append(o)
            else:
                draw_anim_frame(ground, m.bac, a, o.x, o.y)
    write_png(os.path.join(out, 'ground.png'), m.width, m.height, bytes(ground.px))

    # One sprite per animation used by upright or top objects.
    sprites = {}
    for o in upright + top:
        if o.anim in sprites:
            continue
        a = anims[o.anim]
        planes = drawn_planes(m.bac, a)
        if not planes:
            continue
        x0 = min(p.x for p in planes)
        y0 = min(p.y for p in planes)
        x1 = max(p.x + m.bac.bitmaps[p.bmp].w for p in planes)
        y1 = max(p.y + m.bac.bitmaps[p.bmp].h for p in planes)
        c = Canvas(x1 - x0, y1 - y0, transparent=True)
        draw_anim_frame(c, m.bac, a, -x0, -y0)
        sid = f'o{len(sprites):03d}'
        write_png(os.path.join(out, 'objects', sid + '.png'), c.w, c.h, bytes(c.px))
        sprites[o.anim] = {'id': sid, 'anchor': [-x0, -y0], 'size': [c.w, c.h]}

    sections = md3_sections(m.md3)
    info = {'width': m.width, 'height': m.height, 'objects': [], 'top': []}
    if MD3_WALK in sections:
        c, r, cell, data = sections[MD3_WALK]
        px = b''.join(bytes((255, 255, 255, 255)) if v else bytes((0, 0, 0, 0)) for v in data)
        write_png(os.path.join(out, 'collision.png'), c, r, px)
        info['collision'] = {'cols': c, 'rows': r, 'cell': cell}
    if MD3_GROUND in sections:
        c, r, cell, data = sections[MD3_GROUND]
        write_png(os.path.join(out, 'ground_type.png'), c, r, b''.join(bytes((v, 0, 0, 255)) for v in data))
        info['ground_type'] = {'cols': c, 'rows': r, 'cell': cell}
    for key, objs in (('objects', upright), ('top', top)):
        for o in objs:
            if o.anim in sprites:
                s = sprites[o.anim]
                info[key].append({'sprite': s['id'], 'x': o.x, 'y': o.y})
    info['sprites'] = {s['id']: {'anchor': s['anchor'], 'size': s['size']} for s in sprites.values()}
    with open(os.path.join(out, 'map.json'), 'w', encoding='utf-8') as f:
        json.dump(info, f, indent=1)
    return info


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    info = export(sys.argv[1], sys.argv[2])
    print(f"{os.path.basename(sys.argv[1])}: {info['width']}x{info['height']}, "
          f"{len(info['objects'])} props, {len(info['sprites'])} sprites")
