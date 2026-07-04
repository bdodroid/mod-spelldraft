-- Totem display models for races without native shaman support.
-- Stock player_totem_model only covers Orc(2), Dwarf(3), Tauren(6), Troll(8),
-- Draenei(11). Any other race summoning a drafted totem gets ModelID 0 — a blue
-- checkerboard cube ("TotemSlot X with RaceID (Y) have no totem model data" in logs).
-- Alliance races use the Draenei models, Horde races use the classic Orc models.
-- Loaded at startup (ObjectMgr::LoadPlayerTotemModels) — worldserver restart required.

DELETE FROM `player_totem_model` WHERE `RaceID` IN (1, 4, 5, 7, 10);
INSERT INTO `player_totem_model` (`TotemID`, `RaceID`, `ModelID`) VALUES
-- Human (Draenei models)
(1, 1, 19074),
(2, 1, 19073),
(3, 1, 19075),
(4, 1, 19071),
-- Night Elf (Draenei models)
(1, 4, 19074),
(2, 4, 19073),
(3, 4, 19075),
(4, 4, 19071),
-- Undead (Orc models)
(1, 5, 30758),
(2, 5, 30757),
(3, 5, 30759),
(4, 5, 30756),
-- Gnome (Draenei models)
(1, 7, 19074),
(2, 7, 19073),
(3, 7, 19075),
(4, 7, 19071),
-- Blood Elf (Orc models)
(1, 10, 30758),
(2, 10, 30757),
(3, 10, 30759),
(4, 10, 30756);
