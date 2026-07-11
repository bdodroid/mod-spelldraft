-- Remove level and riding skill requirements to consume Prestige Shop mount items
UPDATE `item_template` 
SET `RequiredLevel` = 1, `RequiredSkill` = 0, `RequiredSkillRank` = 0 
WHERE `entry` IN (33809, 49283, 32458, 45693, 50818, 30609, 46708);

-- Remove level requirements to use Prestige Shop cosmetic transformation items
UPDATE `item_template` 
SET `RequiredLevel` = 1 
WHERE `entry` IN (1973, 35275, 37254);

-- Set level-1, instant-cast dummy spells (24312) and correct descriptions on level-locked toys so the client allows clicking/using them at level 1 with correct tooltips
UPDATE `item_template` SET `spellid_1` = 24312, `description` = 'Use: Transform into a member of the opposite faction.' WHERE `entry` = 1973;
UPDATE `item_template` SET `spellid_1` = 24312, `description` = 'Use: Transform into a Blood Elf.' WHERE `entry` = 35275;
UPDATE `item_template` SET `spellid_1` = 24312, `description` = 'Use: Transform into a gorilla inside a purple sphere.' WHERE `entry` = 37254;
