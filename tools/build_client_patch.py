#!/usr/bin/env python3
"""Build the SpellDraft client patch (patch-P.mpq) + matching server SQL.

Custom glyphs need three client-side DBC additions (icons, socket gating, panel
tooltips): Item.dbc, Spell.dbc and GlyphProperties.dbc. The client replaces
whole files from patch archives, so this tool appends our rows to the NATIVE
files and packs the results into a fresh MPQ (v1, plain uncompressed storage —
readable by the stock 3.3.5 client and by mpyq for verification).

New records are cloned from native template records (no field-layout
archaeology): apply spells clone 54854 (a native glyph apply), marker auras
clone 54292 (the beta White Bear dummy aura), items clone the Item.dbc row of
native glyph item 43336.

Inputs:
    tools/client_patch_manifest.json   glyph definitions (single source of truth)
    --dbc-src DIR                      native Item.dbc / Spell.dbc / GlyphProperties.dbc
                                       (docker cp them from ac-worldserver:/azerothcore/env/dist/data/dbc)
Outputs:
    wow-client/Data/patch-P.mpq
    data/sql/db-world/25_custom_glyphs_client.sql
"""

import argparse
import json
import struct
from pathlib import Path

MODULE = Path(__file__).resolve().parent.parent

APPLY_TEMPLATE_SPELL = 54854   # native "Glyph of Frenzied Regeneration" apply spell
MARKER_TEMPLATE_SPELL = 54292  # native beta "Glyph of the White Bear" dummy aura
ITEM_TEMPLATE_ENTRY = 43336    # native beta glyph item (class 16)

SPELL_ID_FIELD = 0
SPELL_MISCVALUE1_FIELD = 110
SPELL_ICON_FIELD = 133
SPELL_NAME_FIELD = 136
SPELL_DESC_FIELD = 170

# ============================================================================
# MPQ v1 writer (plain multi-sector, uncompressed)
# ============================================================================

def _build_crypt_table():
    table = [0] * 0x500
    seed = 0x00100001
    for index1 in range(0x100):
        index2 = index1
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp1 = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp2 = seed & 0xFFFF
            table[index2] = temp1 | temp2
            index2 += 0x100
    return table

_CRYPT = _build_crypt_table()


def _hash_string(s, hash_type):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in s.upper():
        value = _CRYPT[(hash_type << 8) + ord(ch)]
        seed1 = (value ^ ((seed1 + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF
        seed2 = (ord(ch) + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def _encrypt(words, key):
    seed = 0xEEEEEEEE
    out = []
    for word in words:
        seed = (seed + _CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        out.append(word ^ ((key + seed) & 0xFFFFFFFF))
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (word + seed + (seed << 5) + 3) & 0xFFFFFFFF
    return out


def write_mpq(dest, files):
    """files: dict of archive path (backslashes) -> bytes."""
    files = dict(files)
    files['(listfile)'] = ('\r\n'.join(files) + '\r\n').encode()

    hash_size = 1
    while hash_size < len(files) * 2:
        hash_size *= 2

    header_size = 32
    blobs, block_entries = [], []
    offset = header_size
    hash_entries = [[0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]] * hash_size
    hash_entries = [list(e) for e in hash_entries]

    for block_index, (name, data) in enumerate(files.items()):
        blobs.append(data)
        # 0x80000000 EXISTS, stored raw as plain multi-sector (uncompressed
        # files carry no sector-offset table, so the payload is byte-identical).
        # Do NOT add 0x01000000 SINGLE_UNIT: the 3.3.5 client's async streaming
        # reader (used for .m2/.anim/.blp loaded during play) mishandles
        # single-unit files and corrupts the heap -> ERROR #132 on exit.
        block_entries.append((offset, len(data), len(data), 0x80000000))
        idx = _hash_string(name, 0) & (hash_size - 1)
        while hash_entries[idx][3] != 0xFFFFFFFF:
            idx = (idx + 1) & (hash_size - 1)
        hash_entries[idx] = [_hash_string(name, 1), _hash_string(name, 2), 0, block_index]
        offset += len(data)

    hash_words = []
    for e in hash_entries:
        hash_words += e
    block_words = []
    for e in block_entries:
        block_words += list(e)

    hash_data = struct.pack(f'<{len(hash_words)}I',
                            *_encrypt(hash_words, _hash_string('(hash table)', 3)))
    block_data = struct.pack(f'<{len(block_words)}I',
                             *_encrypt(block_words, _hash_string('(block table)', 3)))

    hash_pos = offset
    block_pos = hash_pos + len(hash_data)
    archive_size = block_pos + len(block_data)

    header = struct.pack('<4sIIHHIIII', b'MPQ\x1a', header_size, archive_size,
                         0, 3, hash_pos, block_pos, hash_size, len(block_entries))

    with open(dest, 'wb') as fh:
        fh.write(header)
        for blob in blobs:
            fh.write(blob)
        fh.write(hash_data)
        fh.write(block_data)


# ============================================================================
# DBC helpers
# ============================================================================

class Dbc:
    def __init__(self, path):
        data = open(path, 'rb').read()
        magic, self.recs, self.fields, self.recsize, self.strsize = \
            struct.unpack_from('<4sIIII', data, 0)
        assert magic == b'WDBC', path
        self.records = bytearray(data[20:20 + self.recs * self.recsize])
        self.strings = bytearray(data[20 + self.recs * self.recsize:])

    def get_record(self, rec_id):
        for i in range(self.recs):
            if struct.unpack_from('<I', self.records, i * self.recsize)[0] == rec_id:
                return list(struct.unpack_from(f'<{self.fields}i', self.records, i * self.recsize))
        raise KeyError(rec_id)

    def add_string(self, text):
        offset = len(self.strings)
        self.strings += text.encode('utf-8') + b'\x00'
        return offset

    def add_record(self, values):
        assert len(values) == self.fields
        self.records += struct.pack(f'<{self.fields}i', *values)
        self.recs += 1

    def dumps(self):
        return (struct.pack('<4sIIII', b'WDBC', self.recs, self.fields,
                            self.recsize, len(self.strings))
                + bytes(self.records) + bytes(self.strings))


# ============================================================================
# SQL emission (mirrors the client rows server-side)
# ============================================================================

def sql_escape(s):
    return s.replace('\\', '\\\\').replace("'", "\\'")


CMD_COLUMNS = ('ID', 'Flags', 'ModelName', 'SizeClass', 'ModelScale', 'BloodID',
               'FootprintTextureID', 'FootprintTextureLength', 'FootprintTextureWidth',
               'FootprintParticleScale', 'FoleyMaterialID', 'FootstepShakeSize',
               'DeathThudShakeSize', 'SoundID', 'CollisionWidth', 'CollisionHeight',
               'MountHeight', 'GeoBoxMinX', 'GeoBoxMinY', 'GeoBoxMinZ', 'GeoBoxMaxX',
               'GeoBoxMaxY', 'GeoBoxMaxZ', 'WorldEffectScale', 'AttachedEffectScale',
               'MissileCollisionRadius', 'MissileCollisionPush', 'MissileCollisionRaise')
CMD_FLOATS = {4, 7, 8, 9, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27}
CDI_COLUMNS = ('ID', 'ModelID', 'SoundID', 'ExtendedDisplayInfoID', 'CreatureModelScale',
               'CreatureModelAlpha', 'TextureVariation_1', 'TextureVariation_2',
               'TextureVariation_3', 'PortraitTextureName', 'BloodLevel', 'BloodID',
               'NPCSoundID', 'ParticleColorID', 'CreatureGeosetData', 'ObjectEffectPackageID')
CDI_FLOATS = {4}


def _sql_value(value, is_float):
    if isinstance(value, str):
        return "'" + sql_escape(value) + "'"
    if is_float:
        return repr(round(struct.unpack('<f', struct.pack('<i', value))[0], 6))
    return str(value)


def emit_creature_sql(lines, table, columns, floats, entries):
    if not entries:
        return
    ids = ', '.join(str(e['row'][0]) for e in entries)
    lines.append('')
    lines.append(f'DELETE FROM `{table}` WHERE `ID` IN ({ids});')
    lines.append(f"INSERT INTO `{table}` ({', '.join('`' + c + '`' for c in columns)}) VALUES")
    rows = []
    for e in entries:
        vals = [_sql_value(v, j in floats) for j, v in enumerate(e['row'])]
        rows.append('    (' + ', '.join(vals) + ')')
    lines.append(',\n'.join(rows) + ';')


def emit_sql(glyphs, manifest, dest):
    lines = [
        '-- Custom glyphs defined via the client patch pipeline.',
        '-- GENERATED by tools/build_client_patch.py from tools/client_patch_manifest.json',
        '-- (client side: wow-client/Data/patch-P.mpq). Do not edit by hand.',
        '',
        f"DELETE FROM `glyphproperties_dbc` WHERE `ID` IN ({', '.join(str(g['glyph_id']) for g in glyphs)});",
        'INSERT INTO `glyphproperties_dbc` (`ID`, `SpellID`, `GlyphSlotFlags`, `SpellIconID`) VALUES',
    ]
    rows = []
    for g in glyphs:
        flags = 1 if g['type'] == 'minor' else 0
        rows.append(f"    ({g['glyph_id']}, {g['effect_spell'] or g['marker_spell']}, {flags}, {g['socket_icon']})")
    lines.append(',\n'.join(rows) + ';')

    lines += [
        '',
        f"DELETE FROM `spell_dbc` WHERE `ID` IN ({', '.join(str(i) for g in glyphs for i in (g['apply_spell'], g['marker_spell']) if i)});",
        'INSERT INTO `spell_dbc`',
        '    (`ID`, `Attributes`, `AttributesEx`, `Targets`, `InterruptFlags`, `ProcChance`,',
        '     `CastingTimeIndex`, `DurationIndex`, `RangeIndex`, `EquippedItemClass`,',
        '     `Effect_1`, `ImplicitTargetA_1`, `EffectAura_1`, `EffectMiscValue_1`,',
        '     `SpellVisualID_1`, `SpellIconID`, `SchoolMask`, `Name_Lang_enUS`) VALUES',
    ]
    rows = []
    for g in glyphs:
        rows.append(f"    ({g['apply_spell']}, 268435456, 2048, 131072, 63, 101, 1, 0, 1, -1,"
                    f" 74, 0, 0, {g['glyph_id']}, 12369, {g['spell_icon']}, 1, '{sql_escape(g['name'])}')")
        if not g['effect_spell']:
            # Hidden passive dummy aura (Attributes 0xC0), self-target, infinite
            # duration (DurationIndex 21), aligned to the column list above.
            rows.append(f"    ({g['marker_spell']}, 192, 0, 0, 0, 101, 1, 21, 1, -1,"
                        f" 6, 1, 4, 0, 0, {g['spell_icon']}, 1, '{sql_escape(g['name'])}')")
    lines.append(',\n'.join(rows) + ';')

    entries = ', '.join(str(g['item_entry']) for g in glyphs)
    lines += [
        '',
        f'DELETE FROM `item_template` WHERE `entry` IN ({entries});',
        'INSERT INTO `item_template`',
        '    (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `BuyPrice`, `SellPrice`,',
        '     `InventoryType`, `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`, `stackable`,',
        '     `bonding`, `description`, `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `Material`) VALUES',
    ]
    rows = []
    for g in glyphs:
        rows.append(f"    ({g['item_entry']}, 16, 0, '{sql_escape(g['name'])}', {g['item_display']},"
                    f" 3, 0, 25000, 0, -1, -1, 60, 15, 1, 2,"
                    f" '', {g['apply_spell']}, 0, -1, -1)")
    lines.append(',\n'.join(rows) + ';')

    lines += [
        '',
        f"DELETE FROM `custom_glyphs` WHERE `glyph_id` IN ({', '.join(str(g['glyph_id']) for g in glyphs)});",
        'INSERT INTO `custom_glyphs` (`glyph_id`, `name`, `handler`, `handler_data`) VALUES',
    ]
    rows = [f"    ({g['glyph_id']}, '{sql_escape(g['name'])}', '{g['handler']}', '{g['handler_data']}')"
            for g in glyphs]
    lines.append(',\n'.join(rows) + ';')

    lines += [
        '',
        '-- Add to the shared glyph drop pool',
        f"DELETE FROM `reference_loot_template` WHERE `Entry` = 90001 AND `Item` IN ({entries});",
        'INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES',
    ]
    rows = [f"    (90001, {g['item_entry']}, 0, 0, 0, 1, 1, 1, 1, 'Custom Glyph - {sql_escape(g['name'])}')"
            for g in glyphs]
    lines.append(',\n'.join(rows) + ';')

    emit_creature_sql(lines, 'creaturemodeldata_dbc', CMD_COLUMNS, CMD_FLOATS,
                      manifest.get('creature_model_data', []))
    emit_creature_sql(lines, 'creaturedisplayinfo_dbc', CDI_COLUMNS, CDI_FLOATS,
                      manifest.get('creature_display_info', []))
    lines.append('')

    Path(dest).write_text('\n'.join(lines))


# ============================================================================

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dbc-src', required=True,
                    help='dir with native Item.dbc, Spell.dbc, GlyphProperties.dbc')
    args = ap.parse_args()
    src = Path(args.dbc_src)

    glyphs = json.loads((MODULE / 'tools/client_patch_manifest.json').read_text())['glyphs']

    items = Dbc(src / 'native_Item.dbc' if (src / 'native_Item.dbc').exists() else src / 'Item.dbc')
    spells = Dbc(src / 'native_Spell.dbc' if (src / 'native_Spell.dbc').exists() else src / 'Spell.dbc')
    props = Dbc(src / 'native_GlyphProperties.dbc' if (src / 'native_GlyphProperties.dbc').exists() else src / 'GlyphProperties.dbc')
    shapeshifts = Dbc(src / 'native_SpellShapeshiftForm.dbc' if (src / 'native_SpellShapeshiftForm.dbc').exists() else src / 'SpellShapeshiftForm.dbc')

    # Set SHAPESHIFT_FLAG_STANCE (0x1) for Druid forms in SpellShapeshiftForm.dbc
    # to allow the client to cast any spell without auto-unshifting.
    DRUID_FORMS = {1, 3, 4, 5, 8} # Cat, Travel, Aqua, Bear, Dire Bear
    for i in range(shapeshifts.recs):
        offset = i * shapeshifts.recsize
        row = list(struct.unpack_from(f'<{shapeshifts.fields}i', shapeshifts.records, offset))
        form_id = row[0]
        if form_id in DRUID_FORMS:
            row[19] |= 1  # Field 19 is flags1
            struct.pack_into(f'<{shapeshifts.fields}i', shapeshifts.records, offset, *row)

    # Clear Druid form bits from StancesNot so no spell is blocked while
    # shapeshifted. 3.3.5 Spell.dbc stores Stances/StancesNot as 64-bit pairs:
    # Stances = fields 12-13, StancesNot = fields 14-15 (13/15 are always-zero
    # high words). Only field 14 is touched. Never OR Druid bits into Stances
    # (field 12): the client renders every Stances bit into the fixed-size
    # "Requires <form>, ..." tooltip line, and inflating ~1000 spells' masks
    # overflows that buffer -> silent heap corruption -> ERROR #132 on exit.
    # Casting-while-shifted is granted by SHAPESHIFT_FLAG_STANCE above instead.
    DRUID_FORM_MASK = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 7) | (1 << 30)
    for i in range(spells.recs):
        offset = i * spells.recsize
        row = list(struct.unpack_from(f'<{spells.fields}i', spells.records, offset))
        stances_not = row[14] & 0xFFFFFFFF
        if stances_not & DRUID_FORM_MASK:
            stances_not &= ~DRUID_FORM_MASK
            row[14] = stances_not if stances_not < 0x80000000 else stances_not - 0x100000000
            struct.pack_into(f'<{spells.fields}i', spells.records, offset, *row)

    apply_template = spells.get_record(APPLY_TEMPLATE_SPELL)
    marker_template = spells.get_record(MARKER_TEMPLATE_SPELL)
    item_template = items.get_record(ITEM_TEMPLATE_ENTRY)

    for g in glyphs:
        # Item.dbc: id, class, subclass, sound, material, display, invtype, sheathe
        row = list(item_template)
        row[0] = g['item_entry']
        row[5] = g['item_display']
        items.add_record(row)

        # Apply spell: clone native glyph apply, retarget the glyph property.
        row = list(apply_template)
        row[SPELL_ID_FIELD] = g['apply_spell']
        row[SPELL_MISCVALUE1_FIELD] = g['glyph_id']
        row[SPELL_ICON_FIELD] = g['spell_icon']
        row[SPELL_NAME_FIELD] = spells.add_string(g['name'])
        row[SPELL_DESC_FIELD] = spells.add_string(g['tooltip'])
        spells.add_record(row)

        # Marker aura (cosmetics): clone the beta dummy aura; its description is
        # what the glyph panel shows for the socketed glyph.
        if not g['effect_spell']:
            row = list(marker_template)
            row[SPELL_ID_FIELD] = g['marker_spell']
            row[SPELL_ICON_FIELD] = g['spell_icon']
            row[SPELL_NAME_FIELD] = spells.add_string(g['name'])
            row[SPELL_DESC_FIELD] = spells.add_string(g['tooltip'])
            spells.add_record(row)

        flags = 1 if g['type'] == 'minor' else 0
        props.add_record([g['glyph_id'], g['effect_spell'] or g['marker_spell'], flags, g['socket_icon']])

    manifest = json.loads((MODULE / 'tools/client_patch_manifest.json').read_text())

    def append_manifest_rows(dbc, entries):
        for entry in entries:
            row = list(entry['row'])
            for j in entry['string_fields']:
                row[j] = dbc.add_string(row[j]) if row[j] else 0
            dbc.add_record(row)

    cmd = Dbc(src / 'native_CreatureModelData.dbc' if (src / 'native_CreatureModelData.dbc').exists() else src / 'CreatureModelData.dbc')
    cdi = Dbc(src / 'native_CreatureDisplayInfo.dbc' if (src / 'native_CreatureDisplayInfo.dbc').exists() else src / 'CreatureDisplayInfo.dbc')
    append_manifest_rows(cmd, manifest.get('creature_model_data', []))
    append_manifest_rows(cdi, manifest.get('creature_display_info', []))

    archive = {
        'DBFilesClient\\Item.dbc': items.dumps(),
        'DBFilesClient\\Spell.dbc': spells.dumps(),
        'DBFilesClient\\GlyphProperties.dbc': props.dumps(),
        'DBFilesClient\\CreatureModelData.dbc': cmd.dumps(),
        'DBFilesClient\\CreatureDisplayInfo.dbc': cdi.dumps(),
        'DBFilesClient\\SpellShapeshiftForm.dbc': shapeshifts.dumps(),
    }
    for md in manifest.get('model_dirs', []):
        src_dir = Path(md['src'])
        if not src_dir.is_absolute():
            src_dir = MODULE / src_dir
        for p in sorted(src_dir.iterdir()):
            if p.is_file():
                archive[md['dest'] + '\\' + p.name] = p.read_bytes()

    # Verbatim files copied in as-is (custom DBCs that wholesale-replace native
    # ones, e.g. the custom-title CharTitles.dbc — formerly shipped as patch-P).
    for vf in manifest.get('verbatim_files', []):
        src = Path(vf['src'])
        if not src.is_absolute():
            src = MODULE / src
        archive[vf['dest']] = src.read_bytes()

    dest = MODULE / 'wow-client/Data/patch-P.mpq'
    write_mpq(dest, archive)
    print(f'wrote {dest} ({dest.stat().st_size} bytes)')

    # Write localized version for enUS clients to support overriding repack/vanilla localized Spell.dbc
    localized_dir = MODULE / 'wow-client/Data/enUS'
    localized_dir.mkdir(parents=True, exist_ok=True)
    dest_loc = localized_dir / 'patch-enUS-z.mpq'
    write_mpq(dest_loc, archive)
    print(f'wrote localized version to {dest_loc}')
    print()
    print('WARNING: deploy EXACTLY ONE of patch-P.mpq / patch-enUS-z.mpq per client,')
    print('never both. Mounting the same archive twice corrupts the 3.3.5 client heap')
    print('and crashes with ERROR #132 on exit. Use patch-enUS-z.mpq for enUS clients')
    print('(it outranks repack patches like patch-enUS-s); patch-P.mpq otherwise.')


    # Write loose DBCs for server deployment (install.sh will copy these to the server)
    server_dbc_dir = MODULE / 'dbc'
    server_dbc_dir.mkdir(parents=True, exist_ok=True)
    (server_dbc_dir / 'Spell.dbc').write_bytes(spells.dumps())
    (server_dbc_dir / 'SpellShapeshiftForm.dbc').write_bytes(shapeshifts.dumps())
    print(f'wrote loose server DBCs to {server_dbc_dir}')

    sql_dest = MODULE / 'data/sql/db-world/25_custom_glyphs_client.sql'
    emit_sql(glyphs, manifest, sql_dest)
    print(f'wrote {sql_dest}')


if __name__ == '__main__':
    main()
