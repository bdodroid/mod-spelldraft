-- ----------------------------------------------------------------------------
-- Characters-DB Uninstall & Clean Script for mod-spelldraft
-- WARNING: This script drops all character prestige progress, drafts, and bans
-- permanently. This is a destructive operation.
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS `prestige_stats`;
DROP TABLE IF EXISTS `drafted_spells`;
DROP TABLE IF EXISTS `draft_bans`;
DROP TABLE IF EXISTS `character_item_enchantments`;
