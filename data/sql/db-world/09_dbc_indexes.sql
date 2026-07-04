-- Add indexes and convert engines to InnoDB for DBC-mimic tables
DROP PROCEDURE IF EXISTS AddDBCIndexes;
DELIMITER //
CREATE PROCEDURE AddDBCIndexes()
BEGIN
    ALTER TABLE `dbc_spells` ENGINE=InnoDB, CONVERT TO CHARACTER SET utf8mb4;
    ALTER TABLE `dbc_skilllineability` ENGINE=InnoDB, CONVERT TO CHARACTER SET utf8mb4;
    ALTER TABLE `dbc_skillline` ENGINE=InnoDB, CONVERT TO CHARACTER SET utf8mb4;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics 
        WHERE table_schema = DATABASE() AND table_name = 'dbc_skilllineability' AND index_name = 'idx_sla_spell'
    ) THEN
        ALTER TABLE `dbc_skilllineability` ADD INDEX `idx_sla_spell` (`Spell`);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics 
        WHERE table_schema = DATABASE() AND table_name = 'dbc_skilllineability' AND index_name = 'idx_sla_skillline'
    ) THEN
        ALTER TABLE `dbc_skilllineability` ADD INDEX `idx_sla_skillline` (`SkillLine`);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics 
        WHERE table_schema = DATABASE() AND table_name = 'dbc_spells' AND index_name = 'idx_spells_level'
    ) THEN
        ALTER TABLE `dbc_spells` ADD INDEX `idx_spells_level` (`SpellLevel`);
    END IF;
END //
DELIMITER ;
CALL AddDBCIndexes();
DROP PROCEDURE IF EXISTS AddDBCIndexes;
