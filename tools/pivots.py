"""Reader for Trickster equipment pivot files (.pvt / .pvo).

Each character has a pivot file (CharacterInfo.PivotFileName) that says where
held and worn items sit on every frame of its animations. The file is a list of
sections, one per item sprite (weapon001.nri, shield001.nri, hat001.nri...):
the item's file name, a small header, then 16-byte records:

    i16 x, i16 y        item origin relative to the character's feet
    u8  anim, u8 frame  index into the character .nri's animations / frames
    u16 (unused)
    u8, u8, u8          three percentages (usually 100; meaning unknown)
    u8  (unused)
    u8  item_frame      which frame of the item's single animation to draw
    u8 0xFF, u8 (0xFF or 0x01)
    u8  layer           0x03 draws in front of the body, 0x00 behind it

Frames with no record don't show the item.
"""
import re
import struct

RECORD = 16


def _is_record(b: bytes, p: int) -> bool:
    return p + RECORD <= len(b) and b[p + 8] == 0x64 and b[p + 9] == 0x64 \
        and b[p + 11] == 0 and b[p + 13] == 0xFF


def read(path: str) -> dict:
    """Returns {item file name (lower case): {(anim, frame): (x, y, item_frame, layer)}}.

    Sections are preceded by a u32 id. Most item sprites have no records of
    their own: the file's index lists them as `u32 id, u16 type, char
    name[32], u32 group`, and they share the records of the section whose id
    is `group` (hat019.nri uses hat001.nri's pivots)."""
    b = open(path, 'rb').read()
    names = [(m.start(), m.end(), m.group(1).decode().lower())
             for m in re.finditer(rb'([A-Za-z_0-9]+\.nri)\x00', b)]
    out = {}
    by_id = {}
    refs = {}
    for i, (start, end, name) in enumerate(names):
        stop = names[i + 1][0] if i + 1 < len(names) else len(b)
        # The header after the name varies in length; records start at the
        # first offset where several records line up.
        p = end
        while p < stop and not all(_is_record(b, p + k * RECORD) for k in range(3)):
            p += 1
        recs = {}
        while p < stop and _is_record(b, p):
            x, y, anim, frame = struct.unpack_from('<hhBB', b, p)
            recs.setdefault((anim, frame), (x, y, b[p + 12], b[p + 15]))
            p += RECORD
        if recs:
            out[name] = recs
            if start >= 6:
                by_id[struct.unpack_from('<I', b, start - 6)[0]] = name
        elif start + 36 <= len(b):
            refs[name] = struct.unpack_from('<I', b, start + 32)[0]
    for name, group in refs.items():
        if name not in out and group in by_id:
            out[name] = out[by_id[group]]
    return out


if __name__ == '__main__':
    import sys
    for name, recs in read(sys.argv[1]).items():
        print(f'{name}: {len(recs)} frames')
