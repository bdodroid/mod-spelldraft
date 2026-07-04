-- Create Chromie Prestige Timekeeper creature template, model, and spawn coordinates
DELETE FROM `creature_template` WHERE `entry` = 2069426;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`, `flags_extra`, `AIName`, `ScriptName`) VALUES 
(2069426, 'Chromie', 'Prestige Timekeeper', 80, 80, 35, 1, 1, 1.14286, 0, 1, 2, '', '');

DELETE FROM `creature_template_model` WHERE `CreatureID` = 2069426;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES 
(2069426, 0, 21123, 1, 1);

DELETE FROM `creature` WHERE `guid` IN (5400678, 5400679);
INSERT INTO `creature` (`guid`, `id`, `map`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `spawnMask`, `phaseMask`) VALUES
(5400678, 2069426, 1, 1355.0, -4390.0, 29.0, 2.0, 120, 0, 0, 1, 0, 0, 1, 1),
(5400679, 2069426, 0, -5025.0, -825.0, 495.5, 2.0, 120, 0, 0, 1, 0, 0, 1, 1);
