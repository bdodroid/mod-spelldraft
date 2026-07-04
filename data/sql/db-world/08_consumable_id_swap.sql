-- ----------------------------------------------------------------------------
-- TUNING CONFIGURATION - MIGRATED CONSUMABLE DROP RATES
-- Note: This file migrates the custom scroll injections (originally 17731 & 30811)
-- to their new final IDs (4427 & 1078 respectively) and sets their drop rates
-- in creature_loot_template.
--
-- If you adjust drop rates in 05_prestige_draft_items.sql, make sure to also update
-- the corresponding values here if they are applied on an existing installation.
--
-- Current Default Migrated Drop Rates:
-- - Scroll of Reroll (4427): Normal/Elite = 0.6%, Bosses = 10.0% (Line 84)
-- - Scroll of Ban (1078): Normal/Elite = 0.6%, Bosses = 10.0% (Line 85)
-- ----------------------------------------------------------------------------

-- 1. Swap target templates to entries 4427 (Scroll of Reroll) and 1078 (Scroll of Ban)
UPDATE `item_template` SET
  `class` = 0,
  `subclass` = 8,
  `name` = 'Scroll of Reroll',
  `Quality` = 2,
  `Flags` = 0,
  `BuyPrice` = 1000,
  `SellPrice` = 250,
  `InventoryType` = 0,
  `RequiredLevel` = 1,
  `stackable` = 20,
  `maxcount` = 0,
  `spellid_1` = 24312,
  `spelltrigger_1` = 0,
  `spellcharges_1` = -1,
  `Material` = 4,
  `bonding` = 0,
  `PageText` = 0,
  `Description` = 'Consuming this scroll grants you +1 Draft Reroll.'
WHERE `entry` = 4427;

UPDATE `item_template` SET
  `class` = 12,
  `subclass` = 0,
  `name` = 'Scroll of Ban',
  `Quality` = 2,
  `Flags` = 0,
  `BuyPrice` = 1000,
  `SellPrice` = 250,
  `InventoryType` = 0,
  `RequiredLevel` = 1,
  `stackable` = 20,
  `maxcount` = 0,
  `spellid_1` = 24312,
  `spelltrigger_1` = 0,
  `spellcharges_1` = -1,
  `Material` = 4,
  `bonding` = 0,
  -- 1078 was a readable letter; a nonzero PageText makes the client open the
  -- reading UI on right-click instead of using the item.
  `PageText` = 0,
  `Description` = 'Consuming this scroll grants you +1 Draft Ban.'
WHERE `entry` = 1078;

-- 2. Restore original hijacked retail item templates (17731 and 30811)
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

-- 3. Migrate loot injections for custom scrolls before re-inserting original vanilla drops
-- Drop any rows already on the new IDs first: if this file runs after the swap has
-- already happened (or after 05 re-applies its 17731/30811 injections), the UPDATEs
-- below would otherwise collide with existing (Entry, Item, Reference, GroupId) PKs.
DELETE FROM `creature_loot_template` WHERE `Item` = 4427 AND (`Chance` BETWEEN 0.59 AND 0.61 OR `Chance` BETWEEN 9.9 AND 10.1);
DELETE FROM `creature_loot_template` WHERE `Item` = 1078 AND (`Chance` BETWEEN 0.59 AND 0.61 OR `Chance` BETWEEN 9.9 AND 10.1);
UPDATE `creature_loot_template` SET `Item` = 4427 WHERE `Item` = 17731 AND (`Chance` BETWEEN 0.59 AND 0.61 OR `Chance` BETWEEN 9.9 AND 10.1);
UPDATE `creature_loot_template` SET `Item` = 1078 WHERE `Item` = 30811 AND (`Chance` BETWEEN 0.59 AND 0.61 OR `Chance` BETWEEN 9.9 AND 10.1);

-- 4. Restore original drop sources deleted by 05:84
DELETE FROM `creature_loot_template` WHERE `Entry` = 12225 AND `Item` = 17731;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(12225, 17731, 0, 100, 1, 1, 0, 1, 1, 'Celebras the Cursed - Scroll of Celebras');

DELETE FROM `creature_loot_template` WHERE `Entry` IN (21503, 21505) AND `Item` = 30811;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(21503, 30811, 0, 35, 1, 1, 0, 1, 1, 'Sunfury Warlock - Scroll of Demonic Unbanishing'),
(21505, 30811, 0, 35, 1, 1, 0, 1, 1, 'Sunfury Summoner - Scroll of Demonic Unbanishing');
