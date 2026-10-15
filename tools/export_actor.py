"""Export a Trickster actor sprite (.nri) into Godot-ready sprite sheets.

For each action (walk, attack, ...) it writes one PNG sheet with a row per
direction and a column per frame. Every cell shares the same foot anchor, so
an AnimatedSprite2D only needs a fixed offset. It also writes a SpriteFrames
resource (.tres) and a JSON manifest with frame durations.

usage:
  python -I export_actor.py <file.nri> <out_dir> <actor_name> [--actions walk,idle,...]

The output belongs in the git-ignored `original_assets/` folder: it is
copyrighted Trickster material for private prototyping only.
"""
import argparse
import json
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402

ACTIONS = {
    '서있기': 'idle', '걷기': 'walk', '달리기': 'run', '피격': 'hit', '기절': 'faint',
    '공격': 'attack', '공격2': 'attack2', '마법': 'cast', '자동행동': 'idle_auto',
    '자동행동2': 'idle_auto2', '회피': 'dodge', '피하기': 'dodge', '방어': 'guard',
    '막기': 'guard', '방패막기': 'shield_block', '기뻐하기': 'happy', '화내기': 'angry',
    '슬퍼하기': 'sad', '공격모드': 'combat_stance', '공격준비': 'attack_ready',
    '기모으기': 'charge', '던지기': 'throw', '무기크리티컬': 'weapon_crit', '점프': 'jump',
    '앉기': 'sit', '의자앉기1': 'chair_sit1', '의자앉기2': 'chair_sit2', '잠자기': 'sleep',
}
for i in range(10):
    ACTIONS[f'땅파기{i}'] = f'drill{i}'

# Screen directions. "Front" faces the camera (down the screen).
DIRECTIONS = {
    '위': 'n', '대각오른쪽뒤': 'ne', '오른쪽뒤': 'ne', '오른쪽': 'e', '대각오른쪽앞': 'se',
    '오른쪽앞': 'se', '아래': 's', '대각왼쪽앞': 'sw', '왼쪽앞': 'sw', '왼쪽': 'w',
    '대각왼쪽뒤': 'nw', '왼쪽뒤': 'nw',
}
DIR_ORDER = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne']


def parse_title(title):
    if '_' not in title:
        return None
    act, d = title.split('_', 1)
    if act not in ACTIONS or d not in DIRECTIONS:
        return None
    return ACTIONS[act], DIRECTIONS[d]


def blit(canvas, cw, ch, bm, dx, dy, flip_h, flip_v):
    for y in range(bm.h):
        sy = bm.h - 1 - y if flip_v else y
        ty = dy + y
        if not 0 <= ty < ch:
            continue
        row = bm.rgba[sy * bm.w * 4:(sy + 1) * bm.w * 4]
        for x in range(bm.w):
            sx = bm.w - 1 - x if flip_h else x
            a = row[sx * 4 + 3]
            if not a:
                continue
            tx = dx + x
            if 0 <= tx < cw:
                o = (ty * cw + tx) * 4
                canvas[o:o + 4] = row[sx * 4:sx * 4 + 4]


def write_png(path, w, h, rgba):
    raw = b''.join(b'\x00' + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('nri')
    ap.add_argument('out_dir')
    ap.add_argument('name')
    ap.add_argument('--actions', default='')
    ap.add_argument('--res-prefix', default='', help='res:// path of out_dir for the .tres')
    args = ap.parse_args()
    keep = set(filter(None, args.actions.split(',')))

    n = nori.read(args.nri)
    groups = {}  # action -> {dir: Anim}
    for a in n.anims:
        parsed = parse_title(a.title)
        if not parsed or (keep and parsed[0] not in keep):
            continue
        act, d = parsed
        groups.setdefault(act, {}).setdefault(d, a)

    # One shared cell size and anchor across all actions keeps the sprite stable.
    x0 = y0 = 10 ** 9
    x1 = y1 = -10 ** 9
    for dirs in groups.values():
        for a in dirs.values():
            for fr in a.frames:
                for p in fr.planes:
                    bm = n.bitmaps[p.bmp]
                    x0, y0 = min(x0, p.x), min(y0, p.y)
                    x1, y1 = max(x1, p.x + bm.w), max(y1, p.y + bm.h)
    cw, ch = x1 - x0, y1 - y0
    anchor = (-x0, -y0)  # pixel inside each cell where the feet sit

    os.makedirs(args.out_dir, exist_ok=True)
    manifest = {'actor': args.name, 'source': os.path.basename(args.nri), 'cell': [cw, ch],
                'anchor': list(anchor), 'actions': {}}
    for act, dirs in sorted(groups.items()):
        dir_list = [d for d in DIR_ORDER if d in dirs]
        cols = max(len(dirs[d].frames) for d in dir_list)
        sw, sh = cw * cols, ch * len(dir_list)
        sheet = bytearray(sw * sh * 4)
        info = {'sheet': f'{args.name}_{act}.png', 'dirs': {}}
        for r, d in enumerate(dir_list):
            frames = []
            for c, fr in enumerate(dirs[d].frames):
                cell = bytearray(cw * ch * 4)
                for p in fr.planes:
                    bm = n.bitmaps[p.bmp]
                    blit(cell, cw, ch, bm, p.x - x0, p.y - y0, p.flip & 1, p.flip & 2)
                for y in range(ch):
                    o = ((r * ch + y) * sw + c * cw) * 4
                    sheet[o:o + cw * 4] = cell[y * cw * 4:(y + 1) * cw * 4]
                frames.append({'col': c, 'row': r, 'ms': fr.duration})
            info['dirs'][d] = frames
        write_png(os.path.join(args.out_dir, info['sheet']), sw, sh, bytes(sheet))
        manifest['actions'][act] = info

    with open(os.path.join(args.out_dir, f'{args.name}.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=1)
    if args.res_prefix:
        write_sprite_frames(manifest, args.out_dir, args.res_prefix.rstrip('/'))
    print(f'{args.name}: {len(groups)} actions, cell {cw}x{ch}, anchor {anchor}')


def write_sprite_frames(m, out_dir, res):
    """Write a Godot 4 SpriteFrames .tres: animations named '<action>_<dir>'."""
    cw, ch = m['cell']
    ext, subs, anims = [], [], []
    for i, (act, info) in enumerate(sorted(m['actions'].items()), 1):
        ext.append(f'[ext_resource type="Texture2D" path="{res}/{info["sheet"]}" id="{i}"]')
        for d, frames in info['dirs'].items():
            items = []
            base = min(f['ms'] for f in frames) or 100
            for f in frames:
                sid = f'{act}_{d}_{f["col"]}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{i}")\n'
                            f'region = Rect2({f["col"] * cw}, {f["row"] * ch}, {cw}, {ch})\n')
                items.append(f'{{\n"duration": {f["ms"] / base:.3f},\n"texture": SubResource("{sid}")\n}}')
            loop = 'false' if act in ('attack', 'attack2', 'hit', 'faint', 'dodge', 'cast', 'throw',
                                      'weapon_crit', 'jump') else 'true'
            anims.append(f'{{\n"frames": [{", ".join(items)}],\n"loop": {loop},\n"name": &"{act}_{d}",\n'
                         f'"speed": {1000.0 / base:.3f}\n}}')
    body = (f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]\n\n'
            + '\n'.join(ext) + '\n\n' + '\n'.join(subs) + '\n[resource]\nanimations = ['
            + ', '.join(anims) + ']\n')
    with open(os.path.join(out_dir, f'{m["actor"]}.tres'), 'w', encoding='utf-8') as f:
        f.write(body)


if __name__ == '__main__':
    main()
