#!/usr/bin/env python3
"""Extract Ascension's draft spell rarities from CharacterAdvancement.dbc.

CharacterAdvancement.dbc is Ascension's master draft-entry table (one row per
draftable ability/talent). Relevant fields (of 179, reverse engineered):
    f0   entry ID
    f1   type string ref: 'Ability' | 'Talent' | 'TalentAbility' | 'None'
    f5   spell ID (IDs < ~81000 are native 3.3.5 spells)
    f14  rank count
    f16  quality, primary   (Poor/Normal/Uncommon/Rare/Epic/Legendary/Artifact)
    f20  quality, mode B    (differs for a minority of rows; game-mode variant)
    f24  quality, mode C
    f47  display name string ref
    f64  icon string ref

Usage:
    ./parse_character_advancement.py [--backup PATH] [--out DIR]
"""

import argparse
import csv
import struct

DEFAULT_BACKUP = ("/run/media/system/Storage/Games/AscensionWow/"
                  "Ascension Launcher/resources/ascension-live/Backup")
NATIVE_SPELL_ID_MAX = 81000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--backup', default=DEFAULT_BACKUP)
    ap.add_argument('--out', default='.')
    args = ap.parse_args()

    path = f'{args.backup}/Extracted/DBCs/DBFilesClient/CharacterAdvancement.dbc'
    data = open(path, 'rb').read()
    magic, recs, nfields, recsize, strsize = struct.unpack_from('<4sIIII', data, 0)
    if magic != b'WDBC':
        raise ValueError('not a WDBC file')

    strblock = data[20 + recs * recsize:]
    strings, off = {}, 0
    for s in strblock.split(b'\x00')[:-1]:
        strings[off] = s.decode('utf-8', 'replace')
        off += len(s) + 1

    rows = []
    for i in range(recs):
        r = struct.unpack_from(f'<{nfields}i', data, 20 + i * recsize)
        q = strings.get(r[16], '')
        q20, q24 = strings.get(r[20], ''), strings.get(r[24], '')
        rows.append({
            'entry': r[0],
            'spell': r[5],
            'name': strings.get(r[47], ''),
            'type': strings.get(r[1], ''),
            'quality': q,
            'quality_alt': q20 if q20 != q else (q24 if q24 != q else ''),
            'ranks': r[14],
            'native': 0 < r[5] < NATIVE_SPELL_ID_MAX,
        })

    rows.sort(key=lambda r: r['spell'])
    fields = ['entry', 'spell', 'name', 'type', 'quality', 'quality_alt',
              'ranks', 'native']
    dest = f'{args.out}/ascension_draft_rarities.csv'
    with open(dest, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    native = sum(1 for r in rows if r['native'])
    print(f'{len(rows)} entries ({native} native 3.3.5 spells) -> {dest}')


if __name__ == '__main__':
    main()
