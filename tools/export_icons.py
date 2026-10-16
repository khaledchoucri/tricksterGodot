"""Export original skill icons for the skill cards (SkillParam2.FileName).

usage: python -I export_icons.py <client Trickster folder> <SkillParam2.json> <out dir> <skill id,...>

Writes <out dir>/<skill id>.png for every icon present in the client; missing
icon files are skipped (the HUD falls back to a plain tile).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402
from export_actor import blit, write_png  # noqa: E402


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    client, table, out, ids = sys.argv[1:]
    rows = {r['ID']: r for r in json.load(open(table, encoding='utf-8'))}
    os.makedirs(out, exist_ok=True)
    done = 0
    for sid in filter(None, ids.split(',')):
        row = rows.get(sid)
        path = os.path.join(client, row['FileName'].replace('\\', '/')) if row else ''
        if not path or not os.path.exists(path):
            print(f'icon for skill {sid}: not in the client, skipped')
            continue
        n = nori.read(path)
        p = n.anims[0].frames[0].planes[0] if n.anims and n.anims[0].frames else None
        bm = n.bitmaps[p.bmp if p else 0]
        img = bytearray(bm.w * bm.h * 4)
        blit(img, bm.w, bm.h, bm, 0, 0, 0, 0)
        write_png(os.path.join(out, f'{sid}.png'), bm.w, bm.h, bytes(img))
        done += 1
    print(f'icons: {done} exported')


if __name__ == '__main__':
    main()
