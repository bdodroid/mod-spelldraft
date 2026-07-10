-- Remove class conditions for Pet Trainer Gossip Menu Text and Options
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 14 AND SourceGroup = 4783 AND ConditionTypeOrReference = 15 AND ConditionValue1 = 4;
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = 4783 AND ConditionTypeOrReference = 15 AND ConditionValue1 = 4;

-- Also allow non-hunters to see the friendly greeting text by removing the negative hunter condition on Text 5839
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 14 AND SourceGroup = 4783 AND SourceEntry = 5839;

-- Remove TextID 5839 (unfriendly text) from gossip_menu to guarantee friendly text 5838 is always shown
DELETE FROM gossip_menu WHERE MenuID = 4783 AND TextID = 5839;

-- Allow Soulok Stormfury stables for all classes
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = 9576 AND ConditionTypeOrReference = 15 AND ConditionValue1 = 4;
