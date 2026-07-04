-- Add bonus_drafts column to prestige_stats if it does not exist
SET @stmt = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `prestige_stats` ADD COLUMN `bonus_drafts` INT NOT NULL DEFAULT 0',
    'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'prestige_stats' AND COLUMN_NAME = 'bonus_drafts');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;
