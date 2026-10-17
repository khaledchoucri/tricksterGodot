"""Export worn equipment sprites (hats, shields, masks, ears...) and where
they sit on a character, frame by frame.

Trickster draws worn items as separate sprites over (or under) the body. An
item's .nri holds one animation whose frames are the item seen from each
angle; the character's pivot file (.pvo, see pivots.py) says, for every
body frame, where the item's origin goes, which of its frames to draw and
whether it goes behind the body.

usage: python -I export_equip.py <client dir> <actor out dir> <actor name> <chr.pvo> <item.nri>...

Writes, for each item, original_assets/equip/<item>.png (its frames side by
side) and .json ({"frames": [[x, w, h, ox, oy]...]}: where each frame sits in
the strip, its size, and its top-left relative to the item's origin), and for
the actor <actor out dir>/<name>_equip.json:
    {"groups": {group: {animation: [[x, y, item_frame, front] or 0 per frame]}},
     "items": {item: group}}
Items that share pivots (most hats share hat001's) share a group. Needs the
actor's manifest from export_actor.py, which records each frame's source.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402
import pivots  # noqa: E402
from export_actor import blit, write_png  # noqa: E402

# Kinds always drawn over the body: they sit on the head, so even seen from
# behind they cover it. Shields and tails follow the pivot's layer byte.
ALWAYS_FRONT = ('hat', 'face', 'head', 'ear')


def export_item(path, out_dir):
    """Writes <out_dir>/<stem>.png and .json; returns the frame count (0 if empty)."""
    item = nori.read(path)
    if not item.anims or not item.anims[0].frames:
        return 0
    frames = []
    for fr in item.anims[0].frames:
        if not fr.planes:
            frames.append((None, 0, 0, 0, 0))
            continue
        x0 = min(p.x for p in fr.planes)
        y0 = min(p.y for p in fr.planes)
        x1 = max(p.x + item.bitmaps[p.bmp].w for p in fr.planes)
        y1 = max(p.y + item.bitmaps[p.bmp].h for p in fr.planes)
        w, h = x1 - x0, y1 - y0
        img = bytearray(w * h * 4)
        for p in fr.planes:
            blit(img, w, h, item.bitmaps[p.bmp], p.x - x0, p.y - y0, p.flip & 1, p.flip & 2)
        frames.append((img, w, h, x0, y0))
    sw = sum(f[1] for f in frames) or 1
    sh = max(f[2] for f in frames) or 1
    strip = bytearray(sw * sh * 4)
    info = []
    at = 0
    for img, w, h, ox, oy in frames:
        info.append([at, w, h, ox, oy])
        if img:
            for y in range(h):
                o = (y * sw + at) * 4
                strip[o:o + w * 4] = img[y * w * 4:(y + 1) * w * 4]
        at += w
    stem = os.path.splitext(os.path.basename(path))[0].lower()
    write_png(os.path.join(out_dir, stem + '.png'), sw, sh, bytes(strip))
    with open(os.path.join(out_dir, stem + '.json'), 'w') as f:
        json.dump({'frames': info}, f)
    return len(frames)


def main():
    client, actor_dir, name, pvo = sys.argv[1:5]
    items = sys.argv[5:]
    manifest = json.load(open(os.path.join(actor_dir, name + '.json'), encoding='utf-8'))
    piv = pivots.read(pvo)
    equip_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(actor_dir))), 'equip')
    os.makedirs(equip_dir, exist_ok=True)
    groups = {}
    by_records = {}
    out_items = {}
    for path in items:
        fname = os.path.basename(path).lower()
        stem = os.path.splitext(fname)[0]
        recs = piv.get(fname)
        if not recs:
            print(f'{name}: no pivots for {fname}, skipped')
            continue
        if not os.path.exists(os.path.join(equip_dir, stem + '.json')) and not export_item(path, equip_dir):
            print(f'{name}: {fname} has no frames, skipped')
            continue
        kind = stem.split('_')[0].rstrip('0123456789')
        key = (id(recs), kind in ALWAYS_FRONT)
        if key not in by_records:
            table = {}
            for act, info in manifest['actions'].items():
                for d, frames in info['dirs'].items():
                    row = []
                    for f in frames:
                        rec = recs.get(tuple(f['src'])) if 'src' in f else None
                        if rec:
                            front = 1 if kind in ALWAYS_FRONT else (1 if rec[3] else 0)
                            row.append([rec[0], rec[1], rec[2], front])
                        else:
                            row.append(0)
                    table[f'{act}_{d}'] = row
            gname = f'g{len(groups)}'
            groups[gname] = table
            by_records[key] = gname
        out_items[stem] = by_records[key]
    with open(os.path.join(actor_dir, name + '_equip.json'), 'w') as f:
        json.dump({'groups': groups, 'items': out_items}, f)
    print(f'{name}: {len(out_items)} worn items in {len(groups)} pivot groups')


if __name__ == '__main__':
    main()
