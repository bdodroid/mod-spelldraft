#!/usr/bin/env python3
"""Generate the tan werebear texture set from the fel originals.

The Ascension backup ships only one werebear tint (dark fur, fel-green
accents). This tool decodes the three DXT-compressed texture variations,
re-tints them toward a warm tan using per-pixel luminance (preserving all
shading detail and the alpha channel), and writes uncompressed BLP2 files
(encoding 3, BGRA, full mip chain) that the stock 3.3.5 client reads natively.

Usage:
    python3 tools/recolor_werebear.py --src <werebear dir> --out client_assets/werebear_tan
"""

import argparse
import struct
from pathlib import Path

TAN_DARK = (58, 40, 24)    # shadow end of the fur ramp
TAN_LIGHT = (226, 192, 142)  # highlight end of the fur ramp
SOURCES = {
    'werebear_4253131.blp': ('werebear_tan1.blp', 'fur'),
    'werebear_4253130.blp': ('werebear_tan2.blp', 'glow'),
    'werebear_4253133.blp': ('werebear_tan3.blp', 'fur'),
}


def decode_dxt(data, width, height, dxt5):
    """Returns a flat [r,g,b,a] list of length w*h*4."""
    out = bytearray(width * height * 4)
    block_bytes = 16 if dxt5 else 8
    bw = (width + 3) // 4
    pos = 0
    for by in range((height + 3) // 4):
        for bx in range(bw):
            block = data[pos:pos + block_bytes]
            pos += block_bytes
            if dxt5:
                a0, a1 = block[0], block[1]
                abits = int.from_bytes(block[2:8], 'little')
                color_block = block[8:]
            else:
                color_block = block
            c0, c1, cbits = struct.unpack_from('<HHI', color_block, 0)

            def rgb565(c):
                return (((c >> 11) & 0x1F) * 255 // 31,
                        ((c >> 5) & 0x3F) * 255 // 63,
                        (c & 0x1F) * 255 // 31)
            p0, p1 = rgb565(c0), rgb565(c1)
            palette = [p0, p1]
            if c0 > c1 or dxt5:
                palette.append(tuple((2 * a + b) // 3 for a, b in zip(p0, p1)))
                palette.append(tuple((a + 2 * b) // 3 for a, b in zip(p0, p1)))
            else:
                palette.append(tuple((a + b) // 2 for a, b in zip(p0, p1)))
                palette.append((0, 0, 0))

            for py in range(4):
                y = by * 4 + py
                if y >= height:
                    break
                for px in range(4):
                    x = bx * 4 + px
                    if x >= width:
                        continue
                    ci = (cbits >> (2 * (py * 4 + px))) & 3
                    r, g, b = palette[ci]
                    if dxt5:
                        ai = (abits >> (3 * (py * 4 + px))) & 7
                        if ai == 0:
                            alpha = a0
                        elif ai == 1:
                            alpha = a1
                        elif a0 > a1:
                            alpha = ((8 - ai) * a0 + (ai - 1) * a1) // 7
                        elif ai == 6:
                            alpha = 0
                        elif ai == 7:
                            alpha = 255
                        else:
                            alpha = ((6 - ai) * a0 + (ai - 1) * a1) // 5
                    else:
                        alpha = 255
                    o = (y * width + x) * 4
                    out[o:o + 4] = bytes((r, g, b, alpha))
    return out


def tan_tint(rgba, width, height, mode):
    if mode == 'glow':
        # Kill the fel emissive layer entirely: a plain bear has no glow.
        for i in range(0, width * height * 4, 4):
            rgba[i] = rgba[i + 1] = rgba[i + 2] = 0
        return rgba

    for i in range(0, width * height * 4, 4):
        r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]
        lum = (r * 77 + g * 151 + b * 28) >> 8
        # Fel runes: green-dominant pixels. Melt them into the fur by dropping
        # them to a typical fur luminance instead of tinting their brightness.
        if g > r * 5 // 4 and g > b * 5 // 4 and g > 40:
            lum = 52
        t = min(255, lum * 5 // 3)  # fur is dark overall; open up the ramp
        rgba[i] = TAN_DARK[0] + (TAN_LIGHT[0] - TAN_DARK[0]) * t // 255
        rgba[i + 1] = TAN_DARK[1] + (TAN_LIGHT[1] - TAN_DARK[1]) * t // 255
        rgba[i + 2] = TAN_DARK[2] + (TAN_LIGHT[2] - TAN_DARK[2]) * t // 255
    return rgba


def downsample(rgba, width, height):
    nw, nh = max(1, width // 2), max(1, height // 2)
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        for x in range(nw):
            acc = [0, 0, 0, 0]
            for dy in range(2):
                for dx in range(2):
                    sx, sy = min(width - 1, x * 2 + dx), min(height - 1, y * 2 + dy)
                    o = (sy * width + sx) * 4
                    for c in range(4):
                        acc[c] += rgba[o + c]
            o = (y * nw + x) * 4
            out[o:o + 4] = bytes(v // 4 for v in acc)
    return out, nw, nh


def write_blp_raw(dest, rgba, width, height):
    mips = []
    data, w, h = rgba, width, height
    while True:
        # encoding 3 stores BGRA
        buf = bytearray(len(data))
        buf[0::4] = data[2::4]
        buf[1::4] = data[1::4]
        buf[2::4] = data[0::4]
        buf[3::4] = data[3::4]
        mips.append(bytes(buf))
        if w == 1 and h == 1:
            break
        data, w, h = downsample(data, w, h)

    header_size = 20 + 64 + 64 + 256 * 4  # header + offsets + lengths + (unused) palette
    offsets, lengths = [0] * 16, [0] * 16
    pos = header_size
    for i, m in enumerate(mips[:16]):
        offsets[i], lengths[i] = pos, len(m)
        pos += len(m)

    with open(dest, 'wb') as fh:
        fh.write(struct.pack('<4sIBBBBII', b'BLP2', 1, 3, 8, 0, 1, width, height))
        fh.write(struct.pack('<16I', *offsets))
        fh.write(struct.pack('<16I', *lengths))
        fh.write(b'\x00' * 1024)
        for m in mips[:16]:
            fh.write(m)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    for src_name, (dest_name, mode) in SOURCES.items():
        d = open(Path(args.src) / src_name, 'rb').read()
        _, _, comp, alpha_depth, _, _, w, h = struct.unpack_from('<4sIBBBBII', d, 0)
        mip_off = struct.unpack_from('<16I', d, 20)[0]
        mip_len = struct.unpack_from('<16I', d, 84)[0]
        assert comp == 2, f'{src_name}: expected DXT'
        rgba = decode_dxt(d[mip_off:mip_off + mip_len], w, h, dxt5=alpha_depth > 1)
        rgba = tan_tint(rgba, w, h, mode)
        write_blp_raw(out / dest_name, rgba, w, h)
        print(f'{src_name} -> {dest_name} ({w}x{h})')


if __name__ == '__main__':
    main()
