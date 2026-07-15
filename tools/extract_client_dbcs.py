#!/usr/bin/env python3
"""Extract the EFFECTIVE DBC files from a WoW 3.3.5 client's MPQ chain.

The client resolves each file through its archive load order (base archives,
then patch-2..9/a..z, with locale patches outranking their base counterpart at
the same slot). Repacks ship modified DBCs in high-priority patches (e.g. an
HD repack's patch-enUS-s.mpq carries a 67 MB custom Spell.dbc), so building
our client patch from server/native DBCs silently erases repack content once
our archive wins priority. Always build from the DBCs the client actually
uses: point build_client_patch.py --dbc-src at this tool's output.

Usage:
    python3 tools/extract_client_dbcs.py "/path/to/wow 3.3.5a client" out_dir
    python3 tools/extract_client_dbcs.py client_dir out_dir Spell.dbc Item.dbc

Only zlib/bzip2 sector compression is implemented (covers Blizzard + common
tooling output for DBC files).
"""

import bz2
import glob
import os
import struct
import sys
import zlib


def _build_crypt_table():
    table = [0] * 0x500
    seed = 0x00100001
    for index1 in range(0x100):
        index2 = index1
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp1 = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[index2] = temp1 | (seed & 0xFFFF)
            index2 += 0x100
    return table


_CRYPT = _build_crypt_table()


def hash_string(s, hash_type):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in s.upper():
        value = _CRYPT[(hash_type << 8) + ord(ch)]
        seed1 = (value ^ ((seed1 + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF
        seed2 = (ord(ch) + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def decrypt(data, key):
    seed = 0xEEEEEEEE
    count = len(data) // 4
    words = struct.unpack(f'<{count}I', data[:count * 4])
    out = []
    for word in words:
        seed = (seed + _CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        plain = word ^ ((key + seed) & 0xFFFFFFFF)
        out.append(plain)
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (plain + seed + (seed << 5) + 3) & 0xFFFFFFFF
    return struct.pack(f'<{count}I', *out) + data[count * 4:]


def _decompress(blob, want):
    if len(blob) >= want:
        return blob[:want]
    method, payload = blob[0], blob[1:]
    if method == 0x02:
        return zlib.decompress(payload)
    if method == 0x10:
        return bz2.decompress(payload)
    raise NotImplementedError(f'sector compression mask 0x{method:02x}')


class Mpq:
    def __init__(self, path):
        self.file = open(path, 'rb')
        base = 0
        header = self.file.read(0x20)
        while header[:4] != b'MPQ\x1a':
            base += 0x200
            self.file.seek(base)
            header = self.file.read(0x20)
            if not header:
                raise ValueError(f'{path}: no MPQ header')
        self.base = base
        (_, _, _, version, sector_shift,
         hash_pos, block_pos, hash_count, block_count) = struct.unpack('<4sIIHHIIII', header)
        if version >= 1:
            ext = self.file.read(12)
            _, hash_hi, block_hi = struct.unpack('<QHH', ext)
            hash_pos |= hash_hi << 32
            block_pos |= block_hi << 32
        self.sector_size = 512 << sector_shift
        self.file.seek(base + hash_pos)
        self.hash = struct.unpack(
            f'<{hash_count * 4}I',
            decrypt(self.file.read(hash_count * 16), hash_string('(hash table)', 3)))
        self.file.seek(base + block_pos)
        self.block = struct.unpack(
            f'<{block_count * 4}I',
            decrypt(self.file.read(block_count * 16), hash_string('(block table)', 3)))
        self.hash_count = hash_count

    def find(self, name):
        want_a, want_b = hash_string(name, 1), hash_string(name, 2)
        idx = hash_string(name, 0) & (self.hash_count - 1)
        for _ in range(self.hash_count):
            entry = self.hash[idx * 4:idx * 4 + 4]
            if entry[3] == 0xFFFFFFFF:
                return None
            if entry[0] == want_a and entry[1] == want_b and entry[3] != 0xFFFFFFFE:
                return entry[3]
            idx = (idx + 1) & (self.hash_count - 1)
        return None

    def read(self, name):
        block_index = self.find(name)
        if block_index is None:
            return None
        offset, csize, fsize, flags = self.block[block_index * 4:block_index * 4 + 4]
        key = None
        if flags & 0x10000:
            key = hash_string(name.split('\\')[-1], 3)
            if flags & 0x20000:
                key = ((key + offset) ^ fsize) & 0xFFFFFFFF
        self.file.seek(self.base + offset)
        raw = self.file.read(csize)
        compressed = flags & 0x300
        if flags & 0x01000000:  # single unit
            if key is not None:
                raw = decrypt(raw, key)
            return _decompress(raw, fsize) if compressed else raw[:fsize]
        if not compressed:
            if key is not None:
                raw = b''.join(decrypt(raw[i:i + self.sector_size], key + i // self.sector_size)
                               for i in range(0, len(raw), self.sector_size))
            return raw[:fsize]
        sectors = (fsize + self.sector_size - 1) // self.sector_size
        table_len = sectors + 1 + (1 if flags & 0x04000000 else 0)
        table = raw[:table_len * 4]
        if key is not None:
            table = decrypt(table, (key - 1) & 0xFFFFFFFF)
        offsets = struct.unpack(f'<{table_len}I', table)
        out = bytearray()
        for i in range(sectors):
            blob = raw[offsets[i]:offsets[i + 1]]
            if key is not None:
                blob = decrypt(blob, (key + i) & 0xFFFFFFFF)
            out += _decompress(blob, min(self.sector_size, fsize - len(out)))
        return bytes(out[:fsize])


DEFAULT_DBCS = ['Spell.dbc', 'SpellShapeshiftForm.dbc', 'Item.dbc', 'GlyphProperties.dbc',
                'CreatureModelData.dbc', 'CreatureDisplayInfo.dbc', 'CharTitles.dbc',
                'CharBaseInfo.dbc']

# Our own outputs must not be treated as a base.
OWN_ARCHIVES = {'patch-p.mpq', 'patch-enus-z.mpq'}


def load_ordered_archives(client_dir):
    data_dir = None
    for entry in os.listdir(client_dir):
        if entry.lower() == 'data':
            data_dir = os.path.join(client_dir, entry)
    if not data_dir:
        raise SystemExit(f'no Data dir under {client_dir}')
    paths = glob.glob(os.path.join(data_dir, '*.[mM][pP][qQ]')) + \
        glob.glob(os.path.join(data_dir, '*', '*.[mM][pP][qQ]'))
    paths = [p for p in paths if os.path.basename(p).lower() not in OWN_ARCHIVES]

    def priority(path):
        name = os.path.basename(path).lower()
        is_locale = os.path.dirname(path) != data_dir
        is_patch = name.startswith('patch')
        stem = name[:-4].replace('patch-enus', 'patch').replace('patch-engb', 'patch')
        slot = '1' if stem == 'patch' else stem.split('-')[-1]
        return (is_patch, slot, is_locale)

    return sorted(paths, key=priority)


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    client_dir, out_dir = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3:] or DEFAULT_DBCS
    os.makedirs(out_dir, exist_ok=True)

    best = {}
    for path in load_ordered_archives(client_dir):
        try:
            archive = Mpq(path)
        except Exception as exc:
            print(f'skip {os.path.basename(path)}: {exc}')
            continue
        for dbc in wanted:
            if archive.find('DBFilesClient\\' + dbc) is not None:
                best[dbc] = path

    for dbc in wanted:
        if dbc not in best:
            print(f'{dbc:30s} NOT FOUND in any archive')
            continue
        data = Mpq(best[dbc]).read('DBFilesClient\\' + dbc)
        dest = os.path.join(out_dir, dbc)
        with open(dest, 'wb') as fh:
            fh.write(data)
        _, recs, _, _, _ = struct.unpack_from('<4sIIII', data, 0)
        print(f'{dbc:30s} {recs:6d} records  <- {os.path.basename(best[dbc])}')


if __name__ == '__main__':
    main()
