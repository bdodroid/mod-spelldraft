-- Custom Glyph system v2: Blizzard's scrapped WotLK-beta cosmetic glyphs,
-- resurrected. The five "Deprecated Glyph of the ..." items (40484, 40948,
-- 43336, 43337, 43384) still have COMPLETE native chains in every 3.3.5
-- client AND the server DBCs:
--
--     item -> apply spell (effect 74) -> GlyphProperties (minor) -> dummy aura
--     White Bear   40484 -> 54291 -> prop 141 -> aura 54292
--     Red Lynx     40948 -> 54910 -> prop 182 -> aura 54912
--     Black Bear   43336 -> 58173 -> prop 438 -> aura 58132
--     Forest Lynx  43337 -> 58166 -> prop 436 -> aura 58133
--     Black Wolf   43384 -> 58262 -> prop 472 -> aura 58134
--
-- So NO dbc overrides are needed at all: the native glyph UI sockets them with
-- correct icons, gating and panel tooltips. The only DB work is restoring the
-- items (Blizzard zeroed spellid_1 on three of them) and registering the glyph
-- property ids for the Lua display engine (spelldraft_glyphs.lua), which
-- morphs the matching shapeshift forms while the glyph is socketed.
--
-- Effect (major) glyphs are deferred: no deprecated major-flagged carriers
-- exist, so those need the client-MPQ route later.

-- ============================================================================
-- 0. Remove the abandoned v1 approach (custom ids were invisible client-side)
-- ============================================================================
DELETE FROM `glyphproperties_dbc` WHERE `ID` BETWEEN 1501 AND 1520;
DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 200001 AND 200199;
DELETE FROM `item_template` WHERE `entry` BETWEEN 100001 AND 100020;

-- ============================================================================
-- 1. Resurrect the five beta glyph items
-- ============================================================================
UPDATE `item_template` SET
    `name` = 'Glyph of the White Bear', `Quality` = 3, `RequiredLevel` = 15, `bonding` = 2,
    `BuyPrice` = 0, `SellPrice` = 25000, `stackable` = 1, `maxcount` = 0,
    `spellid_1` = 54291, `spelltrigger_1` = 0, `spellcharges_1` = -1,
    `description` = 'While in Bear Form or Dire Bear Form, you take the shape of the great white spirit bear Arcturis. (Minor Glyph)'
WHERE `entry` = 40484;

UPDATE `item_template` SET
    `name` = 'Glyph of the Red Lynx', `Quality` = 3, `RequiredLevel` = 15, `bonding` = 2,
    `BuyPrice` = 0, `SellPrice` = 25000, `stackable` = 1, `maxcount` = 0,
    `spellid_1` = 54910, `spelltrigger_1` = 0, `spellcharges_1` = -1,
    `description` = 'While in Cat Form, you take the shape of a flame-furred springpaw lynx. (Minor Glyph)'
WHERE `entry` = 40948;

UPDATE `item_template` SET
    `name` = 'Glyph of the Black Bear', `Quality` = 3, `RequiredLevel` = 15, `bonding` = 2,
    `BuyPrice` = 0, `SellPrice` = 25000, `stackable` = 1, `maxcount` = 0,
    `spellid_1` = 58173, `spelltrigger_1` = 0, `spellcharges_1` = -1,
    `description` = 'While in Bear Form or Dire Bear Form, you take the shape of a night-black ashenvale bear. (Minor Glyph)'
WHERE `entry` = 43336;

UPDATE `item_template` SET
    `name` = 'Glyph of the Forest Lynx', `Quality` = 3, `RequiredLevel` = 15, `bonding` = 2,
    `BuyPrice` = 0, `SellPrice` = 25000, `stackable` = 1, `maxcount` = 0,
    `spellid_1` = 58166, `spelltrigger_1` = 0, `spellcharges_1` = -1,
    `description` = 'While in Cat Form, you take the shape of a shadowy forest nightsaber. (Minor Glyph)'
WHERE `entry` = 43337;

UPDATE `item_template` SET
    `name` = 'Glyph of the Black Wolf', `Quality` = 3, `RequiredLevel` = 15, `bonding` = 2,
    `BuyPrice` = 0, `SellPrice` = 25000, `stackable` = 1, `maxcount` = 0,
    `spellid_1` = 58262, `spelltrigger_1` = 0, `spellcharges_1` = -1,
    `description` = 'While in Ghost Wolf form, you take the shape of the storm wolf Skoll. (Minor Glyph)'
WHERE `entry` = 43384;

-- ============================================================================
-- 2. Registry for the Lua display engine (glyph property id -> form override)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `custom_glyphs` (
    `glyph_id` INT NOT NULL PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `handler` VARCHAR(32) NOT NULL DEFAULT 'none',
    `handler_data` VARCHAR(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB;

DELETE FROM `custom_glyphs`;
INSERT INTO `custom_glyphs` (`glyph_id`, `name`, `handler`, `handler_data`) VALUES
    (141, 'Glyph of the White Bear', 'display', '5487,9634:31094'),
    (182, 'Glyph of the Red Lynx', 'display', '768:18167'),
    (438, 'Glyph of the Black Bear', 'display', '5487,9634:706'),
    (436, 'Glyph of the Forest Lynx', 'display', '768:3030'),
    (472, 'Glyph of the Black Wolf', 'display', '2645:29673');
