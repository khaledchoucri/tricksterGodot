"""Convert IMA ADPCM WAV files (format 0x11, used by many Trickster sounds)
to 16-bit PCM, which Godot can import. PCM files are left untouched.

usage: python -I convert_audio.py <file.wav> [...]
"""
import struct
import sys

STEPS = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
    73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
    449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
    9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
]
INDEX = [-1, -1, -1, -1, 2, 4, 6, 8]


def chunks(b):
    p = 12
    while p + 8 <= len(b):
        cid, size = b[p:p + 4], struct.unpack_from('<I', b, p + 4)[0]
        yield cid, b[p + 8:p + 8 + size]
        p += 8 + size + (size & 1)


def decode_block(block, channels):
    preds, idxs = [], []
    for c in range(channels):
        pred, idx = struct.unpack_from('<hB', block, 4 * c)
        preds.append(pred)
        idxs.append(min(max(idx, 0), 88))
    out = [[p] for p in preds]
    data = block[4 * channels:]
    # Data comes in 4-byte groups per channel (8 samples each).
    for g in range(0, len(data), 4 * channels):
        for c in range(channels):
            group = data[g + 4 * c:g + 4 * c + 4]
            for byte in group:
                for nib in (byte & 0x0F, byte >> 4):
                    step = STEPS[idxs[c]]
                    diff = step >> 3
                    if nib & 1:
                        diff += step >> 2
                    if nib & 2:
                        diff += step >> 1
                    if nib & 4:
                        diff += step
                    preds[c] += -diff if nib & 8 else diff
                    preds[c] = max(-32768, min(32767, preds[c]))
                    idxs[c] = max(0, min(88, idxs[c] + INDEX[nib & 7]))
                    out[c].append(preds[c])
    return out


def convert(path):
    b = open(path, 'rb').read()
    parts = dict(chunks(b))
    fmt = parts[b'fmt ']
    tag, channels, rate, _bps, align, _bits = struct.unpack_from('<HHIIHH', fmt, 0)
    if tag != 0x11:
        return False
    data = parts[b'data']
    samples = [[] for _ in range(channels)]
    for p in range(0, len(data), align):
        block = data[p:p + align]
        if len(block) < 4 * channels:
            break
        for c, s in enumerate(decode_block(block, channels)):
            samples[c].extend(s)
    n = min(len(s) for s in samples)
    pcm = bytearray()
    for i in range(n):
        for c in range(channels):
            pcm += struct.pack('<h', samples[c][i])
    header = struct.pack('<4sI4s4sIHHIIHH4sI', b'RIFF', 36 + len(pcm), b'WAVE', b'fmt ', 16, 1, channels,
                         rate, rate * channels * 2, channels * 2, 16, b'data', len(pcm))
    with open(path, 'wb') as f:
        f.write(header + pcm)
    return True


if __name__ == '__main__':
    done = [p for p in sys.argv[1:] if convert(p)]
    print(f'converted {len(done)} ADPCM file(s) to PCM')
