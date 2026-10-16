"""Reader for Trickster NORI sprite files (.nri / .bac).

Format reference: Libre Trickster's TNT docs (docs/NORI_format.md). This is an
independent Python implementation.
"""
import struct
import zlib
from dataclasses import dataclass, field


@dataclass
class Bitmap:
    w: int
    h: int
    x: int
    y: int
    rgba: bytes  # w*h*4, top-down rows


@dataclass
class Plane:
    bmp: int
    x: int
    y: int
    opacity: int
    flip: int
    blend: int
    flag: int


@dataclass
class Frame:
    duration: int
    planes: list


@dataclass
class Anim:
    title: str
    frames: list = field(default_factory=list)


@dataclass
class Nori:
    version: int
    bpp: int
    bitmaps: list   # index = bitmap struct index (first image of each struct)
    anims: list


def _inflate_if_needed(b: bytes) -> bytes:
    if b[:4] == b'NORI':
        return b
    tag, real, size = struct.unpack_from('<III', b, 0)
    if tag in (0xA0B0, 0xB0A0):  # bytes B0 A0 on disk
        return zlib.decompress(b[12:12 + size])
    raise ValueError('not a NORI file')


def _to_rgba(raw: bytes, w: int, h: int, bpp: int, palette) -> bytes:
    out = bytearray(w * h * 4)
    o = 0
    if bpp == 24:
        for i in range(0, w * h * 3, 3):
            bl, g, r = raw[i], raw[i + 1], raw[i + 2]
            if not (r == 255 and g == 0 and bl == 255):
                out[o:o + 4] = bytes((r, g, bl, 255))
            o += 4
    elif bpp == 16:
        for (v,) in struct.iter_unpack('<H', raw[:w * h * 2]):
            if v != 0x7C1F:
                r = (v >> 10) & 31; g = (v >> 5) & 31; bl = v & 31
                out[o:o + 4] = bytes((r << 3 | r >> 2, g << 3 | g >> 2, bl << 3 | bl >> 2, 255))
            o += 4
    elif bpp == 8:
        for idx in raw[:w * h]:
            if idx != 0:
                r, g, bl = palette[idx]
                out[o:o + 4] = bytes((r, g, bl, 255))
            o += 4
    else:
        raise ValueError(f'unsupported bpp {bpp}')
    return bytes(out)


def _rle_decode(data: bytes, w: int, h: int, Bpp: int) -> bytes:
    bg_px = {1: b'\x00', 2: b'\x1f\x7c', 3: b'\xff\x00\xff'}[Bpp]
    out = bytearray()
    p = 0
    for _ in range(h):
        line = bytearray()
        (enc,) = struct.unpack_from('<H', data, p); p += 2
        enc -= 2
        while enc > 0:
            bg, fg = struct.unpack_from('<HH', data, p); p += 4
            n = fg * Bpp
            line += bg_px * bg + data[p:p + n]; p += n
            enc -= 4 + n
        line = line[:w * Bpp]
        line += bg_px * (w - len(line) // Bpp)
        out += line
    return bytes(out)


def read(path: str, palette_override=None) -> Nori:
    b = _inflate_if_needed(open(path, 'rb').read())
    (version,) = struct.unpack_from('<I', b, 4)
    (n_anims,) = struct.unpack_from('<I', b, 28)
    g = 40
    assert b[g:g + 4] == b'GAWI', 'GAWI section missing'
    bpp, compressed, has_pal = struct.unpack_from('<III', b, g + 8)
    n_structs, gsize = struct.unpack_from('<II', b, g + 36)
    p = g + 44
    palette = None
    if has_pal:
        assert b[p:p + 4] == b'PAL_'
        (psize,) = struct.unpack_from('<I', b, p + 28)
        rgb = b[p + 32:p + 32 + 768]
        palette = [(rgb[i], rgb[i + 1], rgb[i + 2]) for i in range(0, 768, 3)]
        p += psize
    if palette_override:
        palette = palette_override
    p += 4 * n_structs  # bitmap offsets; structs are read sequentially instead
    Bpp = bpp // 8
    bitmaps = []
    for _ in range(n_structs):
        (count,) = struct.unpack_from('<I', b, p); p += 4
        first = None
        for _ in range(count):
            dlen, w, h, _p4, bx, by = struct.unpack_from('<6i', b, p); p += 24
            raw = b[p:p + dlen]; p += dlen
            if compressed:
                raw = _rle_decode(raw, w, h, Bpp)
            bm = Bitmap(w, h, bx, by, _to_rgba(raw, w, h, bpp, palette))
            if first is None:
                first = bm
        bitmaps.append(first)

    a0 = g + gsize
    anim_offs = struct.unpack_from(f'<{n_anims}I', b, a0)
    apos = a0 + 4 * n_anims
    anims = []
    for off in anim_offs:
        q = apos + off
        title = b[q:q + 32].split(b'\x00')[0].decode('euc-kr', 'replace')
        (nf,) = struct.unpack_from('<I', b, q + 32)
        f_offs = struct.unpack_from(f'<{nf}I', b, q + 36)
        fpos = q + 36 + 4 * nf
        anim = Anim(title)
        for fo in f_offs:
            r = fpos + fo
            dur, n_planes = struct.unpack_from('<Ii', b, r)
            planes = [Plane(*struct.unpack_from('<7i', b, r + 8 + 28 * k)) for k in range(max(n_planes, 0))]
            anim.frames.append(Frame(dur, planes))
        anims.append(anim)
    return Nori(version, bpp, bitmaps, anims)


if __name__ == '__main__':
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    n = read(sys.argv[1])
    print(f'v{n.version} bpp={n.bpp} bitmaps={len(n.bitmaps)} anims={len(n.anims)}')
    for i, a in enumerate(n.anims):
        planes = sum(len(f.planes) for f in a.frames)
        durs = [f.duration for f in a.frames]
        print(f'{i:3d} {a.title:<28} frames={len(a.frames):<3} planes={planes:<4} dur={durs[:6]}')
