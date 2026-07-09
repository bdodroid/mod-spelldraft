-- Custom Chromie npc_text entries for mod-spelldraft
DELETE FROM `npc_text` WHERE `ID` BETWEEN 100301 AND 100308;
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES
(100301, 'Greetings, traveler. The timeways are ever-shifting, and alternate paths of destiny whisper in the winds. I can help you weave these temporal echoes, or start your journey anew through time.'),
(100302, 'In the vast weave of time, there are countless realities where your character made different choices. To Prestige is to reset your journey through time, returning to your youth at level 1 (or 55 for Death Knights). While you lose your levels, quest history, and current spells, you retain your items (returned via mail), gold, and professions. Crucially, you will start your next journey with permanent, scaling upgrades: more starting rerolls and bans, and a permanent experience bonus!'),
(100303, 'The following will be removed when you prestige:\n\n- Earned Levels\n- Learned Spells\n- Quest History\n- Talents and Talent Points\n- Equipped Gear (Returned via Mail)\n\nAre you ready to reset your timeline?'),
(100304, 'WARNING: Prestiging is a permanent choice that cannot be undone. Make sure you meet the requirements:\n\n- You must have at least 10 free inventory slots.\n- You must dismiss your active pet.\n\nAre you absolutely certain you want to proceed?'),
(100305, 'WARNING: Prestiging is a permanent choice that cannot be undone. Make sure you meet the requirements:\n\n- You must have at least 10 free inventory slots.\n- You must dismiss your active pet.\n- You must have the SpellDraft Addon and client patch installed.\n\nAre you absolutely certain you want to proceed into Draft Mode?'),
(100306, 'Here are your current draft stats:'),
(100307, 'WARNING: This will reset your character as if you prestiged, but without increasing your prestige level or granting prestige rewards. You will lose your current spells, level, and quest history, and start over at level 1.\n\nAre you absolutely certain you want to end drafting?'),
(100308, 'You are not yet at max level (80).\nYou cannot partake in prestigious events. Return to me once you have reached your full potential.');
