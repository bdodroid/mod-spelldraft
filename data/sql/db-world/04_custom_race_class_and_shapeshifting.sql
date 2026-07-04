-- 1. Enable Custom Mage Race-Class Combinations (allows character creation)

-- Dwarf Mage (Race 3, Class 8)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
VALUES (3, 8, 0, 1, -6240, 331, 383, 0);

INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
VALUES
(3, 8, 0, 133, 0),    -- Fireball
(3, 8, 1, 168, 0),    -- Frost Armor
(3, 8, 2, 20594, 0);  -- Stoneform (Dwarf Active Racial)

-- Orc Mage (Race 2, Class 8)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
VALUES (2, 8, 1, 14, -618.518, -4251.67, 38.718, 0);

INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
VALUES
(2, 8, 0, 133, 0),    -- Fireball
(2, 8, 1, 168, 0),    -- Frost Armor
(2, 8, 2, 20572, 0);  -- Blood Fury (Orc Active Racial)

-- Night Elf Mage (Race 4, Class 8)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
VALUES (4, 8, 1, 141, 10311.3, 832.463, 1326.41, 5.69632);

INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
VALUES
(4, 8, 0, 133, 0),    -- Fireball
(4, 8, 1, 168, 0),    -- Frost Armor
(4, 8, 2, 58984, 0);  -- Shadowmeld (Night Elf Active Racial)

-- Tauren Mage (Race 6, Class 8)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
VALUES (6, 8, 1, 215, -2917.58, -257.98, 52.9968, 0);

INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
VALUES
(6, 8, 0, 133, 0),    -- Fireball
(6, 8, 1, 168, 0),    -- Frost Armor
(6, 8, 2, 20549, 0);  -- War Stomp (Tauren Active Racial)


-- 2. Enable Shapeshifting for All Races (prevents client-side shapeshift crashes)

-- Alliance races: Human (1), Dwarf (3), Gnome (7), Draenei (11) copy from Night Elf (4)
INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 1, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 4;

INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 3, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 4;

INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 7, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 4;

INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 11, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 4;

-- Horde races: Orc (2), Undead (5), Troll (8), Blood Elf (10) copy from Tauren (6)
INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 2, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 6;

INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 5, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 6;

INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 8, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 6;

INSERT IGNORE INTO `player_shapeshift_model` (`ShapeshiftID`, `RaceID`, `CustomizationID`, `GenderID`, `ModelID`)
SELECT `ShapeshiftID`, 10, `CustomizationID`, `GenderID`, `ModelID` FROM `player_shapeshift_model` WHERE `RaceID` = 6;


-- 3. Remove Broken/Triggered/NPC duplicate spells from the draft pool

DELETE FROM `dbc_spells` WHERE `Id` IN (
    -- Lightning Bolt (NPC)
    45284, 45286, 45287, 45288, 45289, 45290, 45291, 45292, 45293, 45294, 45295, 45296,
    -- Chain Lightning (NPC)
    45297, 45298, 45299, 45300, 45301, 45302,
    -- Corruption (NPC)
    16985,
    -- Curse of Agony (NPC)
    1014,
    -- Death Coil (NPC)
    52375,
    -- Holy Light (NPC)
    1042,
    -- Holy Shield (NPC)
    20925, 20927, 20928,
    -- Icy Touch (NPC)
    52372,
    -- Immolate (NPC)
    11668,
    -- Plague Strike (NPC)
    52373,
    -- Blood Strike (NPC)
    52374,
    -- Steady Shot (NPC)
    34120,
    -- Summon Water Elemental (NPC)
    35593, 36459,
    -- Arcane Missiles (Triggered damage)
    7269, 7270, 8418, 8419, 10273, 10274, 25346, 27076, 42844, 42845,
    -- Hurricane (Triggered damage)
    48467,
    -- Lightning Shield (Triggered charges)
    26363, 26364, 26365, 26366, 26367, 26369, 26370, 26371,
    -- Mind Sear (Triggered damage)
    53023,
    -- Cleave (Felguard)
    30213, 30219, 30223, 47994,
    -- Intercept (Felguard)
    30151, 30194, 30198, 47996,
    -- Ravage (Ravager)
    53558, 53559, 53560, 53561, 53562
);

