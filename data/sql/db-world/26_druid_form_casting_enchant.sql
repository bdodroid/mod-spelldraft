-- Mystic Enchant powering SpellDraft.AllowSpellsInDruidForms mode 2 (ME).
-- The enchant applies hidden marker aura 990001 while equipped; the C++ hook
-- (src/SpellDraft.cpp, castMode == 2) allows Warlock-family casts in Druid
-- forms while that aura is present.

-- Hidden passive dummy marker aura (same column pattern as the glyph marker
-- auras in 25_custom_glyphs_client.sql: passive + do-not-display, infinite
-- duration, self-target dummy).
DELETE FROM `spell_dbc` WHERE `ID` = 990001;
INSERT INTO `spell_dbc`
    (`ID`, `Attributes`, `AttributesEx`, `Targets`, `InterruptFlags`, `ProcChance`,
     `CastingTimeIndex`, `DurationIndex`, `RangeIndex`, `EquippedItemClass`,
     `Effect_1`, `ImplicitTargetA_1`, `EffectAura_1`, `EffectMiscValue_1`,
     `SpellVisualID_1`, `SpellIconID`, `SchoolMask`, `Name_Lang_enUS`) VALUES
    (990001, 192, 0, 0, 0, 101, 1, 21, 1, -1, 6, 1, 4, 0, 0, 107, 1, 'Shadow Fel Werebear');

DELETE FROM `custom_random_enchantments` WHERE `id` = 900019;
INSERT INTO `custom_random_enchantments`
    (`id`, `name`, `tooltip`, `quality`, `weight`, `min_level`, `slot_mask`, `handler`, `handler_data`) VALUES
    (900019, 'Shadow Fel Werebear', 'You may cast Warlock spells while in Bear Form or Dire Bear Form.', 5, 3, 20, 65535, 'aura', '990001');
