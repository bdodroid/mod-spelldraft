-- Safe addition of talent_points to prestige_stats if not exists
SET @dbname = DATABASE();
SET @tablename = "prestige_stats";
SET @columnname = "talent_points";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_name = @tablename
     AND column_name = @columnname
     AND table_schema = @dbname) > 0,
  "SELECT 1",
  "ALTER TABLE `prestige_stats` ADD COLUMN `talent_points` INT NOT NULL DEFAULT 0"
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Create manually_acquired_talents table
CREATE TABLE IF NOT EXISTS `manually_acquired_talents` (
  `player_guid` INT UNSIGNED NOT NULL,
  `spell_id` INT NOT NULL,
  PRIMARY KEY (`player_guid`, `spell_id`),
  CONSTRAINT `fk_manually_acquired_talents_char` FOREIGN KEY (`player_guid`) REFERENCES `characters`(`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Backfill: grant existing Draft Mode players the points earned from levels
-- gained before this column existed (1 point per level past 1; DKs at 55 get 54).
-- Guarded so a re-run never clobbers points that have since been spent.
UPDATE `prestige_stats` ps
JOIN `characters` c ON c.`guid` = ps.`player_id`
SET ps.`talent_points` = GREATEST(c.`level` - 1, 0)
WHERE ps.`draft_state` = 1
  AND ps.`talent_points` = 0
  AND NOT EXISTS (SELECT 1 FROM `manually_acquired_talents` m WHERE m.`player_guid` = ps.`player_id`);
