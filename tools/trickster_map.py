"""Reader for Trickster maps: .til (tiles), .lyr (layers), .md3 (grid data)
and .bac (map objects, NORI format).

Formats were worked out from the client files; see docs/poc/map-format.md.
"""
import os
import struct
import sys
import zlib
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nori  # noqa: E402

TILE = 32
TRANSPARENT_555 = 0x7C1F
EMPTY_CELL = 0xFFFF


@dataclass
class GridLayer:
    name: str
    cols: int
    rows: int
    cells: list  # raw u32 per cell, row-major: tile | sheet << 16 | flags << 24
    objects: list = field(default_factory=list)  # decals placed on this layer


@dataclass
class MapObject:
    x: int
    y: int
    anim: str


@dataclass
class ObjectLayer:
    name: str
    kind: int
    objects: list = field(default_factory=list)


@dataclass
class TrickMap:
    width: int
    height: int
    cols: int
    rows: int
    tiles: list           # one RGBA tile (32*32*4 bytes) per entry, sheet by sheet
    sheet_starts: list    # index of each sheet's first tile within `tiles`
    grid_layers: list
    object_layers: list
    layers: list          # every layer in draw order (GridLayer or ObjectLayer)
    fine_grid: tuple      # (cols, rows, cell size) of the .md3 fine grid
    md3: bytes
    bac: object           # nori.Nori or None


def _load(path: str) -> bytes:
    """Some map files are zlib-packed: magic (0xC0D0 or 0xE0F0), sizes, then zlib data."""
    b = open(path, 'rb').read()
    magic, real, packed = struct.unpack_from('<III', b, 0)
    if magic in (0xC0D0, 0xE0F0) and b[12] == 0x78:
        out = zlib.decompress(b[12:12 + packed])
        assert len(out) == real, 'unexpected unpacked size'
        return out
    return b


def _offset_table(b: bytes) -> list:
    """Offset tables start at 0 and increase; the first non-increasing value ends them."""
    offs = []
    p = 0
    while p + 4 <= len(b):
        (v,) = struct.unpack_from('<I', b, p)
        if (offs and v <= offs[-1]) or (not offs and v != 0) or v >= len(b):
            break
        offs.append(v)
        p += 4
    return offs


def _decode_555(raw: bytes) -> bytes:
    out = bytearray(len(raw) * 2)
    o = 0
    for (v,) in struct.iter_unpack('<H', raw):
        if v != TRANSPARENT_555:
            r = (v >> 10) & 31
            g = (v >> 5) & 31
            b = v & 31
            out[o:o + 4] = bytes((r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2, 255))
        o += 4
    return bytes(out)


def _blocks_fit(b: bytes, offs: list) -> bool:
    """Whether each tile block at these offsets holds exactly cols x rows tiles within the file."""
    base = 4 * len(offs)
    for o in offs:
        if base + o + 12 > len(b):
            return False
        sz, cols, rows = struct.unpack_from('<3I', b, base + o)
        if sz != cols * rows * TILE * TILE * 2 or base + o + 12 + sz > len(b):
            return False
    return True


def read_tiles(path: str):
    """Tile sets: an offset table, then blocks of (size, cols, rows, pixels).
    Pixels are stored tile after tile (each 32x32 tile contiguous, 16-bit).
    An empty .til (the Gate of Caballa Relics) has no tiles. With a single block
    the block's size can pass for a second offset (the Gate of Desert Beach), so
    offsets are dropped until every block's header fits the file."""
    if os.path.getsize(path) < 12:
        return [], []
    b = _load(path)
    offs = _offset_table(b)
    while offs and not _blocks_fit(b, offs):
        offs.pop()
    base = 4 * len(offs)
    tiles, starts = [], []
    tile_bytes = TILE * TILE * 2
    for o in offs:
        sz, cols, rows = struct.unpack_from('<3I', b, base + o)
        px = b[base + o + 12:base + o + 12 + sz]
        starts.append(len(tiles))
        for i in range(cols * rows):
            tiles.append(_decode_555(px[i * tile_bytes:(i + 1) * tile_bytes]))
    return tiles, starts


def read_layers(path: str):
    b = _load(path)
    offs = _offset_table(b)
    base = 4 * len(offs)
    grids, objs, order = [], [], []
    for o in offs:
        p = base + o
        name = b[p:p + 32].split(b'\0')[0].decode('euc-kr', 'replace')
        ltype, kind, _a, _b, _c, _d, _size, cols, rows = struct.unpack_from('<9i', b, p + 32)
        q = p + 68
        if ltype == 2:
            cells = list(struct.unpack_from(f'<{cols * rows}I', b, q))
            grid = GridLayer(name, cols, rows, cells, _read_objects(b, q + 4 * cols * rows))
            grids.append(grid)
            order.append(grid)
        elif ltype == 0:
            layer = ObjectLayer(name, kind, _read_objects(b, q))
            objs.append(layer)
            order.append(layer)
    return grids, objs, order


def _read_objects(b: bytes, q: int) -> list:
    """An object list: a count, then 56-byte records (x, y, animation name)."""
    if q + 4 > len(b):
        return []
    (count,) = struct.unpack_from('<I', b, q)
    out = []
    for k in range(count):
        r = q + 4 + 56 * k
        if r + 56 > len(b):
            break
        _z, x, y, _w = struct.unpack_from('<4i', b, r)
        anim = b[r + 16:r + 48].split(b'\0')[0].decode('euc-kr', 'replace')
        out.append(MapObject(x, y, anim))
    return out


def read_md3(path: str):
    b = _load(path)
    assert b[:4] == b'MDN_', 'not an MDN_ file'
    v = struct.unpack_from('<27i', b, 4)
    width, height, _cw, _ch, cols, rows = v[7:13]
    fine = (v[24], v[25], v[26])
    return width, height, cols, rows, fine, b


def tile_for(m: 'TrickMap', cell: int):
    """Returns (rgba, flags) for a grid cell value, or None for an empty cell."""
    idx = cell & 0xFFFF
    if idx == EMPTY_CELL:
        return None
    sheet = (cell >> 16) & 0xFF
    if sheet >= len(m.sheet_starts):
        return None
    g = m.sheet_starts[sheet] + idx
    if g >= len(m.tiles):
        return None
    return m.tiles[g], cell >> 24


def read_map(base: str) -> TrickMap:
    width, height, cols, rows, fine, md3 = read_md3(base + '.md3')
    grids, objs, order = read_layers(base + '.lyr')
    tiles, starts = read_tiles(base + '.til')
    bac = nori.read(base + '.bac') if os.path.exists(base + '.bac') else None
    return TrickMap(width, height, cols, rows, tiles, starts, grids, objs, order, fine, md3, bac)
