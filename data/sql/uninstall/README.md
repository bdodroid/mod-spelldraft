# Uninstall & Restoration Guide

This directory contains cleanup and restoration scripts for the **SpellDraft** module.

## Scripts Overview

### 1. `uninstall_world.sql`
Apply this script to your `acore_world` database. It does the following:
*   Restores the hijacked item templates for the four consumables (`4427`, `1078`, `13149`, `25462`) and original test items (`17731`, `30811`) back to their vanilla database definitions.
*   Deletes all injected custom consumable drop entries from `creature_loot_template`.
*   Restores original quest/celebras drops that were overridden.
*   Drops custom module tables: `dbc_spells`, `dbc_skilllineability`, and `dbc_skillline`.
*   Truncates `talent_dbc`.
*   Deletes Chromie creature template, model mapping, and spawns.
*   Deletes custom race-class combination character creation templates and shape-shifting models.

### 2. `uninstall_characters.sql`
Apply this script to your `acore_characters` database.
*   **WARNING:** This is a destructive operation.
*   It drops the module-owned tables (`prestige_stats`, `drafted_spells`, `draft_bans`), permanently deleting all player draft choices, bans, reroll counts, and prestige level progression.

---

## Irreversible Changes (Important!)

Some changes made by this module during installation are **destructive** and cannot be automatically rolled back via a script:
*   **Quest & Item Class Restriction Unlocks:** The script `01_item_quest_unlocks.sql` sets `AllowableClass = 2047` on all class-restricted items and `AllowableClasses = 0` on all quests.
*   Because the original class restrictions were not saved per-row, there is no way to automatically determine which classes were originally restricted to which items and quests.
*   **To restore original class restrictions, you must re-import a fresh/original copy of the stock AzerothCore world database.**

---

## Execution Order
1.  Apply `uninstall_world.sql` to your world database (e.g. `acore_world`).
2.  Apply `uninstall_characters.sql` to your characters database (e.g. `acore_characters`).
