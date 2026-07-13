-- Random Enchantment (RE) system: per-item rolled enchantments.
-- enchantment_id = 0 marks an item that rolled and received nothing,
-- preventing any future re-roll attempts on the same item instance.
CREATE TABLE IF NOT EXISTS `character_item_enchantments` (
    `item_guid` INT UNSIGNED NOT NULL PRIMARY KEY,
    `enchantment_id` INT NOT NULL DEFAULT 0,
    `rolled_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
