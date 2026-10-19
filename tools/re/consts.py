"""usage: python consts.py <hex addr>... — reads 4-byte floats (and 8-byte doubles) at VAs in Trickster.bin."""
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import re_config  # noqa: E402
import struct, sys
b = open(re_config.TRICKSTER_BIN, 'rb').read()
pe = struct.unpack_from('<I', b, 0x3c)[0]; n = struct.unpack_from('<H', b, pe + 6)[0]
opt = struct.unpack_from('<H', b, pe + 20)[0]; base = struct.unpack_from('<I', b, pe + 24 + 28)[0]
secs = []
for i in range(n):
    o = pe + 24 + opt + i * 40
    vs, va, rs, raw = struct.unpack_from('<IIII', b, o + 8)
    secs.append((base + va, vs, raw, rs))
for a in sys.argv[1:]:
    v = int(a, 16)
    for va, vs, raw, rs in secs:
        if va <= v < va + rs:
            o = raw + v - va
            print(a, 'f32=%g' % struct.unpack_from('<f', b, o)[0], 'f64=%g' % struct.unpack_from('<d', b, o)[0])
