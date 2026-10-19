"""usage: python dis.py <start hex> <end hex> — disassembles Trickster.bin, annotating constant reads."""
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import re_config  # noqa: E402
import struct, sys, capstone
b = open(re_config.TRICKSTER_BIN, 'rb').read()
pe = struct.unpack_from('<I', b, 0x3c)[0]; n = struct.unpack_from('<H', b, pe + 6)[0]
opt = struct.unpack_from('<H', b, pe + 20)[0]; base = struct.unpack_from('<I', b, pe + 24 + 28)[0]
secs = []
for i in range(n):
    o = pe + 24 + opt + i * 40
    vs, va, rs, raw = struct.unpack_from('<IIII', b, o + 8)
    secs.append((base + va, rs, raw))
def off(a):
    for va, rs, raw in secs:
        if va <= a < va + rs: return raw + a - va
import re
start, end = int(sys.argv[1], 16), int(sys.argv[2], 16)
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
for ins in md.disasm(b[off(start):off(end)], start):
    note = ''
    m = re.search(r'(dword|qword) ptr \[(0x[0-9a-f]+)\]', ins.op_str)
    if m and ins.mnemonic.startswith('f'):
        o = off(int(m.group(2), 16))
        if o: note = '   ; = %g' % struct.unpack_from('<d' if m.group(1) == 'qword' else '<f', b, o)[0]
    print('%x  %-6s %s%s' % (ins.address, ins.mnemonic, ins.op_str, note))
