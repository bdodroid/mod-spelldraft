-- Create character tables for prestige and draft tracking with ON DELETE CASCADE

CREATE TABLE IF NOT EXISTS `prestige_stats` (
  `player_id` INT UNSIGNED NOT NULL PRIMARY KEY,
  `prestige_level` INT DEFAULT 0,
  `draft_state` TINYINT DEFAULT 0,
  `successful_drafts` INT DEFAULT 0,
  `total_expected_drafts` INT DEFAULT 0,
  `rerolls` INT DEFAULT 0,
  `stored_class` TINYINT DEFAULT 0,
  `offered_spell_1` INT DEFAULT 0,
  `offered_spell_2` INT DEFAULT 0,
  `offered_spell_3` INT DEFAULT 0,
  `bans` INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT `fk_prestige_stats_char` FOREIGN KEY (`player_id`) REFERENCES `characters`(`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `drafted_spells` (
  `player_guid` INT UNSIGNED NOT NULL,
  `spell_id` INT NOT NULL,
  PRIMARY KEY (`player_guid`, `spell_id`),
  CONSTRAINT `fk_drafted_spells_char` FOREIGN KEY (`player_guid`) REFERENCES `characters`(`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `draft_bans` (
  `player_id` INT UNSIGNED NOT NULL,
  `spell_id` INT NOT NULL,
  PRIMARY KEY (`player_id`, `spell_id`),
  CONSTRAINT `fk_draft_bans_char` FOREIGN KEY (`player_id`) REFERENCES `characters`(`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
