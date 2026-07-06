-- mod-spelldraft: Scale down Warlock pet stats for low levels (1-9 for Voidwalker, 1-19 for Succubus, 1-29 for Felhunter, 1-49 for Felguard).
-- In retail WotLK, Warlocks cannot learn these pets until level 10/20/30/50. Consequently, the default database sets all
-- stats below these levels to 1 (HP = 1, mana = 1, armor = 1), causing drafted pets to die instantly in combat at low levels.

UPDATE `pet_levelstats` p
JOIN (
    SELECT creature_entry, level AS base_level, hp, mana, armor, str, agi, sta, inte, spi, min_dmg, max_dmg
    FROM `pet_levelstats`
    WHERE (creature_entry = 1860 AND level = 10)  -- Voidwalker
       OR (creature_entry = 1863 AND level = 20)  -- Succubus
       OR (creature_entry = 417 AND level = 30)   -- Felhunter
       OR (creature_entry = 17252 AND level = 50)  -- Felguard
) base ON p.creature_entry = base.creature_entry
SET 
    p.hp = GREATEST(30, ROUND(base.hp * p.level / base.base_level)),
    p.mana = GREATEST(10, ROUND(base.mana * p.level / base.base_level)),
    p.armor = GREATEST(20, ROUND(base.armor * p.level / base.base_level)),
    p.str = GREATEST(10, ROUND(base.str * p.level / base.base_level)),
    p.agi = GREATEST(10, ROUND(base.agi * p.level / base.base_level)),
    p.sta = GREATEST(10, ROUND(base.sta * p.level / base.base_level)),
    p.inte = GREATEST(10, ROUND(base.inte * p.level / base.base_level)),
    p.spi = GREATEST(10, ROUND(base.spi * p.level / base.base_level)),
    p.min_dmg = GREATEST(1, ROUND(base.min_dmg * p.level / base.base_level)),
    p.max_dmg = GREATEST(2, ROUND(base.max_dmg * p.level / base.base_level))
WHERE p.level < base.base_level;
