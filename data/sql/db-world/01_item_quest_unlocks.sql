-- 1. Remove class locks on all items (2047 = bitmask of all classes)
UPDATE `item_template` SET `AllowableClass` = 2047 WHERE `AllowableClass` != -1;

-- 2. Remove class locks on all quests (0 = all classes can accept)
UPDATE `quest_template_addon` SET `AllowableClasses` = 0 WHERE `AllowableClasses` != 0;
