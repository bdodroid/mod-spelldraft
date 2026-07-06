-- Delete old entries to prevent duplicates
DELETE FROM `creature_template` WHERE `entry` = 99000;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 99000;
DELETE FROM `npc_vendor` WHERE `entry` = 99000;
DELETE FROM `npc_text` WHERE `ID` IN (99000, 99001, 99002);
DELETE FROM `gossip_menu` WHERE `MenuID` IN (99000, 99001, 99002);
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (99000, 99001, 99002);
DELETE FROM `creature` WHERE `id` = 99000;

-- 1. Create the NPC Template (gossip_menu_id = 99000, npcflag = 129, faction = 35)
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `unit_class`, `unit_flags`, `flags_extra`) VALUES
(99000, 'Nibbs', 'SpellDraft', 99000, 80, 80, 35, 129, 1, 768, 2);

-- 2. Associate the Warlock Imp model (4449) scaled to 1.2
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(99000, 0, 4449, 1.2, 1.0);

-- 3. Set up the vendor inventory (reagents and pouches)
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(99000, 1, 6265, 0, 0, 0),    -- Soul Shard
(99000, 2, 17030, 0, 0, 0),   -- Ankh
(99000, 3, 37201, 0, 0, 0),   -- Corpse Dust
(99000, 4, 17056, 0, 0, 0),   -- Light Feather
(99000, 5, 17033, 0, 0, 0),   -- Symbol of Divinity
(99000, 6, 44615, 0, 0, 0),   -- Devout Candle
(99000, 7, 17029, 0, 0, 0),   -- Sacred Candle
(99000, 8, 17021, 0, 0, 0),   -- Wild Berries
(99000, 9, 17026, 0, 0, 0),   -- Wild Thornroot
(99000, 10, 17031, 0, 0, 0),  -- Rune of Teleportation
(99000, 11, 17032, 0, 0, 0),  -- Rune of Portals
(99000, 12, 21841, 0, 0, 0),  -- Netherweave Bag (16 Slots)
(99000, 13, 22243, 0, 0, 0),  -- Small Soul Pouch (12 Slots)
(99000, 14, 21340, 0, 0, 0);  -- Soul Pouch (20 Slots)

-- Set the BuyPrice of Soul Shards to 1 silver (100 copper) so they are not free
UPDATE `item_template` SET `BuyPrice` = 100 WHERE `entry` = 6265;

-- 4. Insert custom gossip text dialogue
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(99000, 'Hey! Down here, giant! You want the good stuff, yeah? I\'ve got candles, teleport runes, corpse dust, and all the soul shards you can carry. Just don\'t ask where I got\'em, and don\'t tell the Warlock Council I\'m here! What do you need?'),
(99001, 'Type \'/spelldraft\' in chat or click the \'Grimoire\' button on your talent frame! That opens the main draft interface where you can see your current spells, draft pool, and options.'),
(99002, 'Once you hit level 80, you can talk to Chromie to \'Prestige\' back to level 1. You\'ll draft a whole new set of spells and earn prestige rewards. It keeps you leveling, and more importantly, keeps you buying my reagents!');

-- 5. Insert Gossip Menu headers
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(99000, 99000),
(99001, 99001),
(99002, 99002);

-- 6. Insert Gossip Option buttons (including OptionNpcFlag and VerifiedBuild = 0)
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `VerifiedBuild`) VALUES
(99000, 0, 1, 'I need to purchase reagents and bags.', 3, 128, 0, 0),
(99000, 1, 0, 'How do I use the SpellDraft menu and Grimoire?', 1, 1, 99001, 0),
(99000, 2, 0, 'What happens when I reach level 80?', 1, 1, 99002, 0),
(99001, 0, 0, 'Back...', 1, 1, 99000, 0),
(99002, 0, 0, 'Back...', 1, 1, 99000, 0);

-- 7. Spawn the guides at all racial starting locations & major cities
INSERT INTO `creature` (`id`, `map`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(99000, 0, -8910.15, -112.5, 81.85, 0.0),      -- Human (Northshire Abbey)
(99000, 1, -615.0, -4254.0, 38.0, 5.0),          -- Orc / Troll (Valley of Trials)
(99000, 1, -2912.4, -263.1, 53.2, 3.2),          -- Tauren (Camp Narache)
(99000, 0, 1662.67, 1672.0, 120.53, 2.7),        -- Undead (Deathknell)
(99000, 0, -6240.8, 331.4, 382.7, 6.1),          -- Dwarf / Gnome (Anvilmar)
(99000, 1, 10311.3, 831.6, 1326.4, 5.5),         -- Night Elf (Shadowglen)
(99000, 530, 10349.6, -6357.3, 33.4, 1.9),       -- Blood Elf (Sunstrider Isle)
(99000, 530, -3961.8, -13931.2, 100.4, 2.0),     -- Draenei (Ammen Vale)
-- Major Cities
(99000, 0, -8839.4, 633.2, 95.1, 4.6),           -- Stormwind City (Trade District center)
(99000, 1, 1611.0, -4389.13, 10.4952, 1.9),      -- Orgrimmar (Valley of Strength bank)
(99000, 0, -4918.4, -956.3, 502.2, 5.4),         -- Ironforge (The Commons center)
(99000, 0, 1610.1, 234.3, -52.0, 5.0),           -- Undercity (Trade Quarter center)
(99000, 1, 9795.1, 960.5, 16.3, 3.0),            -- Darnassus (Warrior's Terrace bank)
(99000, 530, 9455.5, -7275.4, 14.2, 3.8),        -- Silvermoon City (Bazaar bank)
(99000, 530, -4000.2, -11867.5, -0.4, 3.1),      -- The Exodar (Seat of the Naaru center)
(99000, 530, -1850.5, 5432.1, -10.1, 4.5),       -- Shattrath City (Center A'dal room)
(99000, 571, 5807.5, 589.6, 647.2, 0.8);         -- Dalaran (Runeweaver Square center)
