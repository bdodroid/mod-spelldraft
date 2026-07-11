-- Add prestige_tokens column to prestige_stats if it does not exist
ALTER TABLE `prestige_stats` ADD COLUMN `prestige_tokens` INT UNSIGNED NOT NULL DEFAULT 0;
