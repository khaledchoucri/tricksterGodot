"""Export original item art for the game's ItemData resources.

For every item ID it writes the inventory icon to <out>/icons/items/<id>.png
(ItemParam InvFileName, animation InvBundleNum, frame 0), and for weapons
the held sprite to <out>/weapons/item_<id>.png + .json (see export_weapon.py).

usage: python -I export_items.py <client Trickster folder> <tables dir> <out dir> <item id,...>

The output belongs in the git-ignored `original_assets/` folder.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402
from export_actor import blit, write_png  # noqa: E402
import export_weapon  # noqa: E402

ITEM_TABLES = ['ItemParam2', 'ItemParamEx', 'ItemParamEx2', 'ItemParamCM2']
WEAPON_TYPE = 2


def load_items(tables_dir):
    rows = {}
    for t in ITEM_TABLES:
        path = os.path.join(tables_dir, t + '.json')
        if os.path.exists(path):
            for r in json.load(open(path, encoding='utf-8')):
                rows.setdefault(str(r.get('ID')), r)
    return rows


def client_path(client, rel):
    rel = (rel or '').strip().replace('\\', '/')
    path = os.path.join(client, rel) if rel else ''
    return path if path and os.path.exists(path) else ''


def export_icon(path, anim, out_png):
    n = nori.read(path)
    if not n.anims:
        return False
    a = n.anims[min(anim, len(n.anims) - 1)]
    if not a.frames or not a.frames[0].planes:
        return False
    p = a.frames[0].planes[0]
    bm = n.bitmaps[p.bmp]
    if bm is None:
        return False
    img = bytearray(bm.w * bm.h * 4)
    blit(img, bm.w, bm.h, bm, 0, 0, 0, 0)
    write_png(out_png, bm.w, bm.h, bytes(img))
    return True


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    client, tables_dir, out, ids = sys.argv[1:]
    rows = load_items(tables_dir)
    icons = os.path.join(out, 'icons', 'items')
    weapons = os.path.join(out, 'weapons')
    os.makedirs(icons, exist_ok=True)
    os.makedirs(weapons, exist_ok=True)
    done = 0
    for iid in filter(None, ids.split(',')):
        row = rows.get(iid)
        if not row:
            print(f'item {iid}: not in the item tables, skipped')
            continue
        inv = client_path(client, row.get('InvFileName'))
        if inv and export_icon(inv, int(row.get('InvBundleNum') or 0), os.path.join(icons, iid + '.png')):
            done += 1
        else:
            print(f'item {iid}: no icon')
        if int(row.get('Type') or 0) == WEAPON_TYPE:
            eq = client_path(client, row.get('EquipFileName'))
            if not eq or not export_weapon.export(eq, os.path.join(weapons, f'item_{iid}.png')):
                print(f'item {iid}: no held weapon sprite')
    print(f'items: {done} icons exported')


if __name__ == '__main__':
    main()
