"""Finds each class's virtual function table in Trickster.bin from MSVC RTTI
(TypeDescriptor -> CompleteObjectLocator -> vtable[-1]) and writes
{class: [function addresses]} as JSON. usage: python vtables.py <out.json> [name regex]"""
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import re_config  # noqa: E402
import json
import re
import struct
import sys

BIN = re_config.TRICKSTER_BIN
b = open(BIN, 'rb').read()
pe = struct.unpack_from('<I', b, 0x3c)[0]
nsec = struct.unpack_from('<H', b, pe + 6)[0]
opt = struct.unpack_from('<H', b, pe + 20)[0]
base = struct.unpack_from('<I', b, pe + 24 + 28)[0]
secs = []
for i in range(nsec):
    o = pe + 24 + opt + i * 40
    name = b[o:o + 8].rstrip(b'\0').decode()
    vsize, va, rsize, raw = struct.unpack_from('<IIII', b, o + 8)
    secs.append((name, base + va, vsize, raw, rsize))


def off(addr):
    for _n, va, vs, raw, rs in secs:
        if va <= addr < va + min(vs, rs):
            return raw + addr - va
    return None


def va_of(o):
    for _n, va, vs, raw, rs in secs:
        if raw <= o < raw + rs:
            return va + o - raw
    return None


text = next(s for s in secs if s[0] == '.text')


def in_text(a):
    return text[1] <= a < text[1] + text[2]


pattern = re.compile(sys.argv[2]) if len(sys.argv) > 2 else re.compile('.')
dwords = {}
for m in re.finditer(rb'\.\?AV([A-Za-z0-9_@]+)@@\0', b):
    name = m.group(1).decode()
    if '@' in name and not name.endswith('Cake'):
        name = name.split('@')[0]
    if not pattern.search(name):
        continue
    td = va_of(m.start() - 8)
    dwords[td] = name

out = {}
for td, name in dwords.items():
    needle = struct.pack('<I', td)
    for m in re.finditer(re.escape(needle), b):
        col_off = m.start() - 12
        sig, offset = struct.unpack_from('<II', b, col_off)
        if sig != 0 or offset != 0:
            continue
        col = va_of(col_off)
        for v in re.finditer(re.escape(struct.pack('<I', col)), b):
            fns = []
            p = v.start() + 4
            while True:
                a = struct.unpack_from('<I', b, p)[0]
                if not in_text(a):
                    break
                fns.append('0x%x' % a)
                p += 4
            if fns:
                out.setdefault(name, fns)
json.dump(out, open(sys.argv[1], 'w'), indent=1)
print(len(out), 'classes;', sum(len(v) for v in out.values()), 'slots;',
      len({a for v in out.values() for a in v}), 'unique functions')
