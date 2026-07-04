-- Migrate existing player items from old hijacked IDs to new consumable IDs
UPDATE `item_instance` SET `itemEntry` = 4427 WHERE `itemEntry` = 17731;
UPDATE `item_instance` SET `itemEntry` = 1078 WHERE `itemEntry` = 30811;
