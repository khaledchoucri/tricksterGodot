"""Reader for Trickster equipment pivot files (.pvt / .pvo).

Each character has a pivot file (CharacterInfo.PivotFileName) that says where
held and worn items sit on every frame of its animations. The file holds
sections, one per item sprite (weapon001.nri, shield001.nri, hat001.nri...):

    u32 id, u16 count, char name[32], then count 16-byte records:

    i16 x, i16 y        item origin relative to the character's feet
    u8  anim, u8 frame  index into the character .nri's animations / frames
    u16 (unused)
    u8  scale_x         width in percent: a shield seen edge-on is drawn at 70-90
    u8  scale_y         height in percent (always 100)
    u8  depth           draw order against the body, which sits at 100
    u8  (unused)
    u8  item_frame      which frame of the item's single animation to draw
    u8 0xFF, u8 (0xFF or 0x01)
    u8  (unused)        leftover memory: 0xCD fill, 0x7C from colour keys...

The client's loader (0x50d940, called for <chr>.pvo then <chr>.pvt by
0x50dc20) reads the u16 count and then count * 16 bytes in one go, so the
records are a fixed-size run after the 32-byte name.

Reading: the depth byte is the layer. Every hat record says 105, head pieces
110, ears 120, masks 100 (always over the face), tails 90 when the back is to
the camera and 100 otherwise, and a shield goes 95 / 100 / 105 as it swings
behind, beside and in front of the body. Items at or above BODY_DEPTH draw over
the body, in depth order. (The last byte, read as the layer before, holds
uninitialised fill like 0xCD and flips frame to frame in a walk cycle.)

The file ends with an index of every item sprite, `u32 id, u16 count, char
name[32], u32 group`: most items have no records of their own and share those
of the section whose id is `group` (hat019.nri uses hat001.nri's pivots).

Frames with no record don't show the item.
"""
import re
import struct

RECORD = 16
NAME = 32
# The body's own depth: items at or above it draw over the body.
BODY_DEPTH = 100


def _records(b: bytes, p: int, count: int) -> list:
    """The `count` records at `p`, or [] if they don't fit or aren't records."""
    end = p + count * RECORD
    if not count or end > len(b) or any(b[q + 13] != 0xFF for q in range(p, end, RECORD)):
        return []
    return [b[q:q + RECORD] for q in range(p, end, RECORD)]


def read(path: str) -> dict:
    """Returns {item file name (lower case): {(anim, frame): (x, y, item_frame, depth, scale_x)}}.

    Sections hold their own records; index entries point at a section by id."""
    b = open(path, 'rb').read()
    out = {}
    by_id = {}
    refs = {}
    for m in re.finditer(rb'([A-Za-z_0-9]+\.nri)\x00', b):
        start, name = m.start(), m.group(1).decode().lower()
        if start < 6:
            continue
        sid, count = struct.unpack_from('<IH', b, start - 6)
        recs = _records(b, start + NAME, count)
        if recs:
            table = {}
            for r in recs:
                x, y, anim, frame = struct.unpack_from('<hhBB', r)
                table.setdefault((anim, frame), (x, y, r[12], r[10], r[8]))
            # A name can head two sections (face_cm_001 in chr015.pvo: one stray
            # record, then the real table); the fuller one is the item's.
            if len(table) > len(out.get(name, {})):
                out[name] = table
            if len(table) > len(by_id.get(sid, {})):
                by_id[sid] = table
        elif start + NAME + 4 <= len(b):
            refs.setdefault(name, struct.unpack_from('<I', b, start + NAME)[0])
    for name, group in refs.items():
        if name not in out and group in by_id:
            out[name] = by_id[group]
    return out


if __name__ == '__main__':
    import sys
    for name, recs in read(sys.argv[1]).items():
        print(f'{name}: {len(recs)} frames')
