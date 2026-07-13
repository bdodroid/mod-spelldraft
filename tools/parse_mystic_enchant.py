#!/usr/bin/env python3
"""Parse Ascension's MysticEnchant.dbc into a reviewable enchant catalogue.

Joins each enchant record against Ascension's Spell.dbc (standard 3.3.5 layout,
234 fields / 936-byte records) to pull the enchant's display name, rank text and
effect description, then emits CSV + JSON.

MysticEnchant.dbc layout (31 int32 fields, reverse engineered):
    f0  enchant ID
    f1  effect spell ID (name/description live in Spell.dbc; IDs < ~81000 are
        native 3.3.5 spells — mostly WotLK major-glyph auras)
    f2  roll weight (float; higher = more common)
    f3  quality      (string ref: RE_QUALITY_POOR..RE_QUALITY_ARTIFACT)
    f4  base quality (string ref; tier the enchant chain starts at)
    f5  required level
    f6  secondary spell ID (per-record unique; the apply/scroll spell)
    f7-f12 boolean flags (allowed acquisition contexts)
    f13 slot/equip bitmask
    f15-f17 spec affinity tags (string refs: RESTORATION, ARMS, ... or NONE)

Usage:
    ./parse_mystic_enchant.py [--backup PATH] [--out DIR]
"""

import argparse
import csv
import json
import mmap
import struct

DEFAULT_BACKUP = ("/run/media/system/Storage/Games/AscensionWow/"
                  "Ascension Launcher/resources/ascension-live/Backup")

# Standard 3.3.5a Spell.dbc string-column indices (0-based, int32 fields)
SPELL_NAME_FIELD = 136
SPELL_RANK_FIELD = 153
SPELL_DESC_FIELD = 170

NATIVE_SPELL_ID_MAX = 81000  # highest 3.3.5a spell id is ~80864


def read_header(buf):
    magic, recs, fields, recsize, strsize = struct.unpack_from('<4sIIII', buf, 0)
    if magic != b'WDBC':
        raise ValueError('not a WDBC file')
    return recs, fields, recsize, strsize


def parse_mystic_enchant(path):
    data = open(path, 'rb').read()
    recs, _, recsize, _ = read_header(data)
    strblock = data[20 + recs * recsize:]

    strings, off = {}, 0
    for s in strblock.split(b'\x00')[:-1]:
        strings[off] = s.decode()
        off += len(s) + 1

    def tag(v):
        s = strings.get(v, '')
        return s.replace('RE_QUALITY_', '')

    enchants = []
    for i in range(recs):
        r = struct.unpack_from('<31i', data, 20 + i * recsize)
        enchants.append({
            'id': r[0],
            'spell': r[1],
            'weight': round(struct.unpack('<f', struct.pack('<i', r[2]))[0], 2),
            'quality': tag(r[3]),
            'base_quality': tag(r[4]),
            'level': r[5],
            'apply_spell': r[6],
            'slot_mask': r[13],
            'specs': [strings[r[k]] for k in (15, 16, 17)
                      if strings.get(r[k]) not in (None, 'NONE')],
            'native': r[1] < NATIVE_SPELL_ID_MAX,
        })
    return enchants


def load_spell_strings(path, wanted_ids):
    f = open(path, 'rb')
    recs, _, recsize, strsize = read_header(f.read(20))
    mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    strstart = 20 + recs * recsize

    def getstr(o):
        if o <= 0 or o >= strsize:
            return ''
        end = mm.find(b'\x00', strstart + o)
        return mm[strstart + o:end].decode('utf-8', 'replace')

    lookup = {}
    for i in range(recs):
        base = 20 + i * recsize
        rid = struct.unpack_from('<I', mm, base)[0]
        if rid in wanted_ids:
            offs = [struct.unpack_from('<i', mm, base + fld * 4)[0]
                    for fld in (SPELL_NAME_FIELD, SPELL_RANK_FIELD, SPELL_DESC_FIELD)]
            lookup[rid] = tuple(getstr(o) for o in offs)
    return lookup


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--backup', default=DEFAULT_BACKUP)
    ap.add_argument('--out', default='.')
    args = ap.parse_args()

    dbc_dir = f'{args.backup}/Extracted/DBCs/DBFilesClient'
    enchants = parse_mystic_enchant(f'{dbc_dir}/MysticEnchant.dbc')
    spells = load_spell_strings(f'{dbc_dir}/Spell.dbc',
                                {e['spell'] for e in enchants})

    for e in enchants:
        name, rank, desc = spells.get(e['spell'], ('<missing>', '', ''))
        e.update(name=name, rank=rank, desc=desc)

    with open(f'{args.out}/mystic_enchants.json', 'w') as fh:
        json.dump(enchants, fh, indent=1)

    fields = ['id', 'name', 'rank', 'quality', 'base_quality', 'level',
              'weight', 'specs', 'native', 'spell', 'apply_spell',
              'slot_mask', 'desc']
    with open(f'{args.out}/mystic_enchants.csv', 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for e in enchants:
            row = dict(e)
            row['specs'] = '|'.join(e['specs'])
            w.writerow(row)

    print(f'{len(enchants)} enchants written to {args.out}/mystic_enchants.{{csv,json}}')


if __name__ == '__main__':
    main()
