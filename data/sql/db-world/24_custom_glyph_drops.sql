-- Custom Glyph acquisition: rare creature drops + lootable world objects.
--
-- One shared reference loot group (90001) holds all 8 custom glyphs; creatures
-- roll it at a very low chance (boss-weighted), and three hidden "Forgotten
-- Grimoire" world objects award one guaranteed random glyph on a long respawn.

-- ============================================================================
-- 1. Shared glyph loot group: one of the 5 glyphs, equal weight
-- ============================================================================
DELETE FROM `reference_loot_template` WHERE `Entry` = 90001;
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (90001, 40484, 0, 0, 0, 1, 1, 1, 1, 'Custom Glyph - White Bear'),
    (90001, 40948, 0, 0, 0, 1, 1, 1, 1, 'Custom Glyph - Red Lynx'),
    (90001, 43336, 0, 0, 0, 1, 1, 1, 1, 'Custom Glyph - Black Bear'),
    (90001, 43337, 0, 0, 0, 1, 1, 1, 1, 'Custom Glyph - Forest Lynx'),
    (90001, 43384, 0, 0, 0, 1, 1, 1, 1, 'Custom Glyph - Black Wolf');

-- ============================================================================
-- 2. Rare creature drops: 0.05% from normal mobs, 2% from bosses (rank 3)
--    (same injection pattern as the Tome of Talents world drop)
-- ============================================================================
DELETE FROM `creature_loot_template` WHERE `Item` = 90001 AND `Reference` = 90001;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT ct.lootid, 90001, 90001,
    CASE WHEN MAX(ct.rank) = 3 THEN 2.0 ELSE 0.05 END,
    0, 1, 0, 1, 1, 'Custom Glyph drop (SpellDraft)'
FROM `creature_template` ct
WHERE ct.lootid > 0
GROUP BY ct.lootid;

-- ============================================================================
-- 3. Forgotten Grimoire world objects (guaranteed random glyph, 3h respawn)
--    Display 928 = glowing tome pedestal ("Tome of the Cabal" model)
-- ============================================================================
DELETE FROM `gameobject_template` WHERE `entry` BETWEEN 500001 AND 500003;
-- size 0.3 and lock 57 (Open + Treasure) match freely-lootable chests; Data2 = 10800
-- makes the tome restock every 3h (stays visible, goes inert between loots) match the native Tome of the Cabal;
-- size 1.0 renders as a room-sized book and lock 0 is not openable.
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `size`, `Data0`, `Data1`, `Data2`, `Data3`) VALUES
    (500001, 3, 928, 'Forgotten Grimoire', 0.3, 57, 500001, 10800, 0),
    (500002, 3, 928, 'Forgotten Grimoire', 0.3, 57, 500002, 10800, 0),
    (500003, 3, 928, 'Forgotten Grimoire', 0.3, 57, 500003, 10800, 0);

DELETE FROM `gameobject_loot_template` WHERE `Entry` BETWEEN 500001 AND 500003;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (500001, 90001, 90001, 100, 0, 1, 0, 1, 1, 'Forgotten Grimoire - random custom glyph'),
    (500002, 90001, 90001, 100, 0, 1, 0, 1, 1, 'Forgotten Grimoire - random custom glyph'),
    (500003, 90001, 90001, 100, 0, 1, 0, 1, 1, 'Forgotten Grimoire - random custom glyph');

-- Spawns: Blind Mary's haunted house (Duskwood), Hermit Ortell's cave
-- (Silithus), Hugh Glass's trapper camp (Grizzly Hills).
DELETE FROM `gameobject` WHERE `guid` BETWEEN 5720001 AND 5720003;
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`) VALUES
    (5720001, 500001, 0, 0, 0, 1, 1, -10782.5, -1377.9, 39.72, 0.113, 0, 0, 0.0567, 0.9984, 10800, 100, 1),
    (5720002, 500002, 1, 0, 0, 1, 1, -7580.9, 199.3, 11.55, 1.344, 0, 0, 0.6225, 0.7826, 10800, 100, 1),
    (5720003, 500003, 571, 0, 0, 1, 1, 4110.8, -4740.1, 100.87, 3.142, 0, 0, 1, 0, 10800, 100, 1);
