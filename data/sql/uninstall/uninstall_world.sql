-- ----------------------------------------------------------------------------
-- World-DB Uninstall & Restore Script for mod-spelldraft
-- WARNING: AllowableClass/AllowableClasses mass-updates on items and quests
-- (done by 01_item_quest_unlocks.sql) are NOT reversible from a script
-- because original per-row values were never captured.
-- To completely restore these, you MUST re-import your stock world database.
-- ----------------------------------------------------------------------------

-- 1. Restore modified item templates to their stock values
UPDATE `item_template` SET
  `class` = 0,
  `subclass` = 8,
  `name` = 'Deprecated Scroll of Spirit Armor V',
  `Quality` = 1,
  `Flags` = 16,
  `BuyPrice` = 390,
  `SellPrice` = 97,
  `InventoryType` = 0,
  `RequiredLevel` = 39,
  `stackable` = 5,
  `maxcount` = 0,
  `spellid_1` = 0,
  `spelltrigger_1` = 0,
  `spellcharges_1` = 0,
  `Material` = 4,
  `bonding` = 0,
  `Description` = ''
WHERE `entry` = 4427;

UPDATE `item_template` SET
  `class` = 12,
  `subclass` = 0,
  `name` = 'Deprecated Writ of Lakeshire',
  `Quality` = 1,
  `Flags` = 16,
  `BuyPrice` = 0,
  `SellPrice` = 0,
  `InventoryType` = 0,
  `RequiredLevel` = 0,
  `stackable` = 10,
  `maxcount` = 0,
  `spellid_1` = 0,
  `spelltrigger_1` = 0,
  `spellcharges_1` = 0,
  `Material` = 4,
  `bonding` = 0,
  `PageText` = 27,
  `Description` = 'Signed by the Honorable Magistrate Solomon.'
WHERE `entry` = 1078;

UPDATE `item_template` SET
  `class` = 0,
  `subclass` = 0,
  `name` = 'Eldarathian Tome of Summoning Vol. 1',
  `Quality` = 1,
  `Flags` = 0,
  `BuyPrice` = 0,
  `SellPrice` = 0,
  `InventoryType` = 0,
  `RequiredLevel` = 0,
  `stackable` = 1,
  `maxcount` = 0,
  `spellid_1` = 0,
  `spelltrigger_1` = 0,
  `spellcharges_1` = 0,
  `Material` = -1,
  `Description` = ''
WHERE `entry` = 13149;

UPDATE `item_template` SET
  `class` = 12,
  `subclass` = 0,
  `name` = 'Tome of Dusk',
  `Quality` = 1,
  `Flags` = 2048,
  `BuyPrice` = 0,
  `SellPrice` = 0,
  `InventoryType` = 0,
  `RequiredLevel` = 0,
  `stackable` = 1,
  `maxcount` = 0,
  `spellid_1` = 0,
  `spelltrigger_1` = 0,
  `spellcharges_1` = 0,
  `Material` = -1,
  `Description` = ''
WHERE `entry` = 25462;

-- Restore 17731 and 30811 to be absolutely clean
UPDATE `item_template` SET
  `class` = 12,
  `subclass` = 0,
  `name` = 'Scroll of Celebras',
  `Quality` = 1,
  `Flags` = 64,
  `BuyPrice` = 0,
  `SellPrice` = 0,
  `InventoryType` = 0,
  `RequiredLevel` = 0,
  `stackable` = 1,
  `maxcount` = 0,
  `spellid_1` = 0,
  `spelltrigger_1` = 0,
  `spellcharges_1` = 0,
  `Material` = 4,
  `bonding` = 4,
  `Description` = ''
WHERE `entry` = 17731;

UPDATE `item_template` SET
  `class` = 0,
  `subclass` = 0,
  `name` = 'Scroll of Demonic Unbanishing',
  `Quality` = 1,
  `Flags` = 64,
  `BuyPrice` = 700,
  `SellPrice` = 175,
  `InventoryType` = 0,
  `RequiredLevel` = 0,
  `stackable` = 20,
  `maxcount` = 0,
  `spellid_1` = 37834,
  `spelltrigger_1` = 0,
  `spellcharges_1` = -1,
  `Material` = 4,
  `bonding` = 0,
  `Description` = ''
WHERE `entry` = 30811;

-- 2. Remove injected loot templates
DELETE FROM `creature_loot_template` WHERE `Item` IN (4427, 1078, 13149, 25462) 
  AND (`Chance` IN (0.6, 10.0, 0.1, 5.0, 1.0, 15.0) 
       OR `Chance` BETWEEN 0.59 AND 0.61 
       OR `Chance` BETWEEN 9.9 AND 10.1 
       OR `Chance` BETWEEN 0.09 AND 0.11 
       OR `Chance` BETWEEN 4.9 AND 5.1 
       OR `Chance` BETWEEN 0.99 AND 1.01 
       OR `Chance` BETWEEN 14.9 AND 15.1);

-- Restore original drops that were hijacked/deleted
DELETE FROM `creature_loot_template` WHERE `Entry` = 12225 AND `Item` = 17731;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(12225, 17731, 0, 100, 1, 1, 0, 1, 1, 'Celebras the Cursed - Scroll of Celebras');

DELETE FROM `creature_loot_template` WHERE `Entry` IN (21503, 21505) AND `Item` = 30811;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(21503, 30811, 0, 35, 1, 1, 0, 1, 1, 'Sunfury Warlock - Scroll of Demonic Unbanishing'),
(21505, 30811, 0, 35, 1, 1, 0, 1, 1, 'Sunfury Summoner - Scroll of Demonic Unbanishing');

-- 3. Drop module-owned DBC/lookup tables and delete talent_dbc contents
DROP TABLE IF EXISTS `dbc_spells`;
DROP TABLE IF EXISTS `dbc_skilllineability`;
DROP TABLE IF EXISTS `dbc_skillline`;
DELETE FROM `talent_dbc`;

-- 4. Delete Chromie prestige timekeeper and spawns
DELETE FROM `creature_template` WHERE `entry` = 2069426;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 2069426;
DELETE FROM `creature` WHERE `guid` IN (5400678, 5400679, 5400680);
DELETE FROM `npc_text` WHERE `ID` BETWEEN 100301 AND 100308;

-- 5. Delete custom race-class info and shapeshift entries
DELETE FROM `playercreateinfo` WHERE `race` IN (2, 3, 4, 6) AND `class` = 8;
DELETE FROM `playercreateinfo_action` WHERE `race` IN (2, 3, 4, 6) AND `class` = 8;
DELETE FROM `player_shapeshift_model` WHERE `RaceID` IN (1, 2, 3, 5, 7, 8, 10, 11);
