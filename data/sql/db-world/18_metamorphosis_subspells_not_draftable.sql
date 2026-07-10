-- Shadow Cleave (50581) and Immolation Aura (50589) are Demon Form abilities:
-- unusable without Metamorphosis (47241), which grants them as a starter kit.
-- Rarity 99 marks them non-draftable so they never drop as standalone picks.
UPDATE `dbc_spells` SET `Rarity` = 99 WHERE `Id` IN (50581, 50589);
