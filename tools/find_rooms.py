"""Suggest combat-room rectangles inside exported Trickster maps.

Scores every window by how much connected walkable ground it holds, picks the
best non-overlapping ones, and draws them on a preview for review.

usage: python -I find_rooms.py <exported map dir> <preview.png> [--count 3]
"""
import argparse
import json
import os
import struct
import sys
import zlib
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_actor import write_png  # noqa: E402

ROOM_W, ROOM_H = 1120, 680  # world pixels


def read_png(path):
    d = open(path, 'rb').read()
    w, h = struct.unpack('>II', d[16:24])
    idat, p = b'', 8
    while p < len(d):
        n = struct.unpack('>I', d[p:p + 4])[0]
        t = d[p + 4:p + 8]
        if t == b'IDAT':
            idat += d[p + 8:p + 8 + n]
        p += 12 + n
    raw = zlib.decompress(idat)
    stride = w * 4
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    return w, h, rows


def largest_component(walk, x0, y0, cw, ch):
    seen = set()
    best = 0
    for sy in range(y0, y0 + ch):
        for sx in range(x0, x0 + cw):
            if (sx, sy) in seen or not walk[sy][sx]:
                continue
            q = deque([(sx, sy)])
            seen.add((sx, sy))
            n = 0
            while q:
                x, y = q.popleft()
                n += 1
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if x0 <= nx < x0 + cw and y0 <= ny < y0 + ch and (nx, ny) not in seen and walk[ny][nx]:
                        seen.add((nx, ny))
                        q.append((nx, ny))
            best = max(best, n)
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('map_dir')
    ap.add_argument('preview')
    ap.add_argument('--count', type=int, default=3)
    args = ap.parse_args()
    info = json.load(open(os.path.join(args.map_dir, 'map.json'), encoding='utf-8'))
    col = info['collision']
    w, h, rows = read_png(os.path.join(args.map_dir, 'collision.png'))
    walk = [[rows[y][x * 4 + 3] == 0 for x in range(w)] for y in range(h)]
    cell = col['cell']
    cw, ch = ROOM_W // cell, ROOM_H // cell
    cands = []
    for y0 in range(0, h - ch + 1, 4):
        for x0 in range(0, w - cw + 1, 4):
            total = sum(walk[y][x] for y in range(y0, y0 + ch, 2) for x in range(x0, x0 + cw, 2))
            cands.append((total, x0, y0))
    cands.sort(reverse=True)
    picked = []
    for total, x0, y0 in cands[:400]:
        if any(abs(x0 - px) < cw * 0.8 and abs(y0 - py) < ch * 0.8 for _, px, py, _ in picked):
            continue
        comp = largest_component(walk, x0, y0, cw, ch) / (cw * ch)
        if comp < 0.45:
            continue
        picked.append((comp, x0, y0, total))
        if len(picked) >= args.count:
            break
    rooms = [{'rect': [x0 * cell, y0 * cell, ROOM_W, ROOM_H], 'walkable': round(comp, 2)} for comp, x0, y0, _ in picked]
    print(json.dumps(rooms))

    # Preview: ground scaled down 4x with room outlines.
    gw, gh, grows = read_png(os.path.join(args.map_dir, 'ground.png'))
    s = 4
    pw, ph = gw // s, gh // s
    px = bytearray(pw * ph * 4)
    for y in range(ph):
        src = grows[y * s]
        for x in range(pw):
            px[(y * pw + x) * 4:(y * pw + x) * 4 + 4] = src[x * s * 4:x * s * 4 + 4]
    for k, r in enumerate(rooms):
        x, y, rw, rh = [v // s for v in r['rect']]
        color = bytes(((255, 60, 60), (60, 200, 255), (255, 220, 60), (120, 255, 120))[k % 4]) + b'\xff'
        for t in range(3):
            for xx in range(x, min(x + rw, pw)):
                for yy in (y + t, y + rh - 1 - t):
                    if 0 <= yy < ph:
                        px[(yy * pw + xx) * 4:(yy * pw + xx) * 4 + 4] = color
            for yy in range(y, min(y + rh, ph)):
                for xx in (x + t, x + rw - 1 - t):
                    if 0 <= xx < pw:
                        px[(yy * pw + xx) * 4:(yy * pw + xx) * 4 + 4] = color
    write_png(args.preview, pw, ph, bytes(px))


if __name__ == '__main__':
    main()
