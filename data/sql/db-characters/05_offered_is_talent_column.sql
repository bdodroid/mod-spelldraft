-- Persist whether the pending offered_spell_1..3 draft is a Tome of Talents
-- draft. The restore path previously guessed from "all offered ids are rank-1
-- talent spells", which misclassifies normal drafts that roll three talent
-- actives (they are regular pool entries) and locks the draft in talent mode.
ALTER TABLE `prestige_stats` ADD COLUMN `offered_is_talent` TINYINT NOT NULL DEFAULT 0;
