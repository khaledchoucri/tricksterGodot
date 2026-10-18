"""Export the original particle effects ("cakes") that skills use.

Trickster draws skill effects with its own particle system: data/effect/cake.xml
defines CAKEs (an effect, e.g. "M_223_electric_field_keep") made of
SUBCREAMs, each pointing at a CREAM (one emitter: emission rate, lifetime,
sizes, colours, alphas, gravity, velocity...), whose particles are textures
from data/effect/cream.nri (one animation per texture, e.g. "jijick").

usage: python -I export_effects.py <client data/effect dir> <out dir> [cake name...]

With no cake names it only writes <out>/cake_names.json (every cake), which
the skill generators read to find each skill's effects.

Writes <out>/cakes.json ({cake: {"play": type, "subs": [{"time", "sort",
"cream": {param: value}}]}}) and, for each texture used, <out>/tex/<name>.png
(its frames side by side) with <name>.json ({"frames": [[x, w, h, ox, oy]]}).
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402
from export_actor import blit, write_png  # noqa: E402

NUMBERS = re.compile(r'^-?\d+(\.\d+)?( -?\d+(\.\d+)?)*\s*$')


def parse(xml):
    cakes, creams = {}, {}
    for m in re.finditer(r"<CAKE Name='([^']+)'[^>]*>(.*?)</CAKE>", xml, re.S):
        play = re.search(r"<CAKEPLAY Time='([^']*)' Type='([^']*)'", m.group(2))
        subs = []
        for sm in re.finditer(r"<SUBCREAM Name='[^']*' Time='([^']*)'>(.*?)</SUBCREAM>", m.group(2), re.S):
            name = re.search(r'<SubCreamName>([^<]*)</SubCreamName>', sm.group(2))
            sort = re.search(r'<SubCreamSortType>([^<]*)</SubCreamSortType>', sm.group(2))
            subs.append({'time': float(sm.group(1) or 0), 'cream': name.group(1) if name else '',
                         'sort': sort.group(1) if sort else 'Object_Over'})
        cakes[m.group(1)] = {'play': play.group(2) if play else 'PlayNormal', 'subs': subs}
    for m in re.finditer(r"<CREAM Name='([^']+)'>(.*?)</CREAM>", xml, re.S):
        params = {}
        for k, v in re.findall(r'<(\w+)>([^<]*)</\1>', m.group(2)):
            v = v.strip()
            if NUMBERS.match(v):
                nums = [float(x) for x in v.split()]
                params[k] = nums[0] if len(nums) == 1 else nums
            else:
                params[k] = v
        creams[m.group(1)] = params
    return cakes, creams


def export_texture(cream_nri, anim, out_path):
    frames = []
    for fr in anim.frames:
        if not fr.planes:
            frames.append((None, 0, 0, 0, 0))
            continue
        x0 = min(p.x for p in fr.planes)
        y0 = min(p.y for p in fr.planes)
        x1 = max(p.x + cream_nri.bitmaps[p.bmp].w for p in fr.planes)
        y1 = max(p.y + cream_nri.bitmaps[p.bmp].h for p in fr.planes)
        w, h = x1 - x0, y1 - y0
        img = bytearray(w * h * 4)
        for p in fr.planes:
            blit(img, w, h, cream_nri.bitmaps[p.bmp], p.x - x0, p.y - y0, p.flip & 1, p.flip & 2)
        frames.append((img, w, h, x0, y0))
    sw = sum(f[1] for f in frames) or 1
    sh = max([f[2] for f in frames] + [1])
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
    write_png(out_path + '.png', sw, sh, bytes(strip))
    with open(out_path + '.json', 'w') as f:
        json.dump({'frames': info}, f)


def safe(name):
    return re.sub(r'[^A-Za-z0-9_\-]+', '_', name)


def main():
    src, out = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3:]
    with open(os.path.join(src, 'cake.xml'), 'rb') as f:
        cakes, creams = parse(f.read().decode('utf-8', 'replace'))
    os.makedirs(os.path.join(out, 'tex'), exist_ok=True)
    if not wanted:
        with open(os.path.join(out, 'cake_names.json'), 'w', encoding='utf-8') as f:
            json.dump(sorted(cakes), f)
        print(f'effects: {len(cakes)} cake names')
        return
    picked = {}
    textures = set()
    for name in wanted:
        cake = cakes.get(name)
        if not cake:
            print(f'effects: no cake {name}')
            continue
        subs = []
        for sub in cake['subs']:
            cream = creams.get(sub['cream'])
            if cream is None:
                continue
            cream = dict(cream)
            cream['TextureFile'] = safe(str(cream.get('TextureName', '')))
            textures.add(str(cream.get('TextureName', '')))
            subs.append({'time': sub['time'], 'sort': sub['sort'], 'cream': cream})
        picked[name] = {'play': cake['play'], 'subs': subs}
    cream_nri = nori.read(os.path.join(src, 'cream.nri'))
    by_title = {a.title: a for a in cream_nri.anims}
    made = 0
    for t in sorted(textures):
        if t in by_title:
            export_texture(cream_nri, by_title[t], os.path.join(out, 'tex', safe(t)))
            made += 1
        else:
            print(f'effects: no texture {t}')
    with open(os.path.join(out, 'cakes.json'), 'w', encoding='utf-8') as f:
        json.dump(picked, f)
    print(f'effects: {len(picked)} cakes, {made} textures')


if __name__ == '__main__':
    main()
