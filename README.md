# mod-spelldraft
**Classless-ish Randomized Spell Draft Mode for AzerothCore (3.3.5a)**

`mod-spelldraft` is a custom game mode that transforms the standard World of Warcraft leveling experience into a randomized, classless ability draft. 

Designed primarily for players who want a fun, rogue-like draft experience on their private server, this module removes traditional class boundaries while maintaining race and class identity:
*   **Race & Class Identity:** You still pick a starting race and class, receiving their native starting stats, class quests, and base attributes.
*   **Universal Quests:** All class-restricted quests are unlocked, allowing any class to complete any other class's quest chain (such as the Warrior's Whirlwind weapon quest or the Warlock's pet summon quests).
*   **Ability Drafting as You Level:** Every level-up intercepts standard progression and prompts you with a choice of 3 randomized active spells.
*   **Tomes and Scrolls in the World:** Defeating enemies gives you a chance to loot custom items to customize your build:
    *   *Scrolls of Reroll/Ban:* Prune or roll again on your active ability draft choices.
    *   *Lost Grimoires:* Trigger a bonus active spell draft at any time.
    *   *Tomes of Talents:* Draft custom passive talents (like *Cruelty*, *Ignite*, or *Conviction*) from any class. Access your drafted talents and spells by typing `/spelldraft` in the game chat.
*   **Universal Gear & Weapon Proficiencies:** Any character can equip any armor type (Cloth to Plate) and wield any weapon type, with weapon skills training automatically to the level cap on login.
*   **Automatic Spell Ranking:** No need to visit class trainers. Drafted spells automatically upgrade to their highest available rank as you level up.
*   **Mystic Enchants (Random Loot Enchantments):** Gear of Uncommon quality or better has a chance to roll unique bonuses when looted, crafted, or won. These enchants grant passive glyph-tier effects, combat proc recipes (such as cross-class spell triggers), or cosmetic shapeshift overrides, and can be rerolled, imbued, or transferred via Nibbs the Imp.
*   **Prestige System:** Reach level 80 and reset back to level 1 (or level 55 for Death Knights) with a prestige title. While spells and talents are wiped on reset, you earn **Prestige Tokens** (10 per reset) and starting bonus rerolls for your next run.
*   **Prestige Rewards Shop:** Access a custom, tabbed reward shop within your Grimoire interface (`/spelldraft` menu, click the Gold Purse icon next to the Prestige label) to purchase rare mounts, vanity companion pets, account-bound heirloom weapons and armor (+XP scaling), scrolls, and transformation toys using your Prestige Tokens.

---

## Player Connection Guide (Client-Only)

If you are a player connecting to a server running SpellDraft, you do **not** need to install or build the server module. You only need the client files:
1. Go to the **Releases** section of this repository and download the latest `wow-client.zip`.
2. Extract the zip file, copy the `Interface/` folder into your World of Warcraft game directory, and copy `Data/patch-P.mpq` into your client's `Data/` folder.
   * The shipped `patch-P.mpq` is built for the **native (unmodified) WotLK 3.3.5a client**.
   * **HD / custom repack clients**: do **not** use the shipped archive — it would override your repack's databases with vanilla data (broken/green models, altered tooltips). A patch must be compiled against your specific repack; see [Building Client Patches for HD Repacks](#building-client-patches-for-hd-repacks) (usually your server owner provides this build).
   * ⚠️ Install exactly **one** SpellDraft patch archive. Mounting the same archive twice (e.g. as both `patch-P.mpq` and a locale patch) silently corrupts the 3.3.5 client's memory and crashes with `ERROR #132` on every exit.
3. **Fully close and relaunch the game** after copying — custom `.mpq` patches only load at client startup, not on `/reload`.

---

## Requirements & Dependencies

Before installing, ensure your server meets the following external dependencies:

*   **AzerothCore WotLK (3.3.5a)**: Compiles and runs against the AzerothCore master branch.
*   **[mod-ale (Eluna Lua Engine)](https://github.com/azerothcore/mod-ale) — REQUIRED**: This module depends on the Eluna scripting engine to run gameplay logic. Standard/classic Eluna forks do not support the required event hooks—use the official AzerothCore `mod-ale` module.
*   **mod-playerbots — Optional**: Fully supported. Playerbots are automatically skipped by the drafting system and will function as normal classes without any conflict.
*   **[mod-multiclass-summons](https://github.com/bdodroid/mod-multiclass-summons) — Optional**: Fully supported. Integrates out of the box to allow any class to control and use summon spells (like ghouls, demons, and elementals) with working pet bars and controls, bypassing default class restrictions.

---

## Spell Draft & Gear Rules

### 1. Universal Proficiencies
To support multi-class build paths (e.g. a Rogue who drafts Warrior abilities), characters are automatically granted:
*   **Armor**: Cloth, Leather, Mail, and Plate Mail.
*   **Weapons**: All weapon types (Swords, Axes, Maces, Polearms, Staves, Daggers, Fist Weapons, Bows, Crossbows, Guns, Thrown, Wands) and Shield Block.

### 2. Spell Draft Prerequisites & Class Locks
Spells are filtered server-side to ensure players are never offered useless cards:
*   **Death Knight Rune Spells**: Locked to the Death Knight class (Class 6) due to engine limitations on rune resources. Spells requiring only Runic Power remain draftable by anyone.
*   **Stance & Form Requirements**: Stance/form-specific spells (like Shred, Intercept, Shield Slam) will not appear in the draft pool until the prerequisite form/stance is learned.

### 3. Stance/Form Starter Kits
Drafting a stance or form auto-grants basic spells so you can immediately fight:
*   **Cat Form (768)**: Claw (1082), Prowl (5215)
*   **Bear Form (5487/9634)**: Maul (6807), Demoralizing Roar (99)
*   **Battle Stance (2457)**: Charge (100)
*   **Defensive Stance (71)**: Taunt (355)
*   **Berserker Stance (2458)**: Pummel (6552)

### 4. Consumable Draft Items
To facilitate draft customization and progression during leveling, enemies drop specialized scrolls and books that can be consumed out of combat:
*   **Scroll of Reroll**: Consuming this scroll grants the player **+1 Draft Reroll** token.
*   **Scroll of Ban**: Consuming this scroll grants the player **+1 Draft Ban** token.
*   **Lost Grimoire**: Consuming this grimoire immediately opens a bonus active spell draft choice.
*   **Tome of Talents**: Consuming this tome opens a draft selection screen allowing you to choose one passive talent from any class matching your level.

These items drop from normal enemies throughout the world, with dungeon and raid bosses having a significantly increased chance to drop them.

---

## Mystic Enchants (Random Loot Enchantments)

Weapons and armor of Uncommon quality or better that you **loot, craft, or win** have a chance to roll a **Mystic Enchant** — a bonus effect bound to that specific item, shown as an extra line on its tooltip:
*   **Glyph-tier enchants** grant a passive glyph effect while the item is equipped.
*   **Proc enchants** trigger cross-class effects in combat (e.g. Fireball casts hurling a free Fire Blast).
*   **Form enchants** change your shapeshift appearance (e.g. Bear Form becoming the spirit bear Arcturis).

Visit **Nibbs the Imp** and choose *Open Mystic Enchant services* for the enchanting window:
*   **Reroll / Imbue** — drag an item into the slot and pay gold to reroll its enchant, or to add one to an un-enchanted item.
*   **Golden Imbue** — spend a **Prestige Token** for a guaranteed **Epic-or-better** enchant.
*   **Transfer** — pay gold (scaling with the enchant's rarity) to move an enchant from one item to another. Overwriting the destination's enchant asks for confirmation; the source keeps a spent marker.

## Cosmetic & Custom Glyphs

Rare world drops include **glyphs that socket through the standard Glyphs panel** (talent window, level 15+):
*   **Minor cosmetic glyphs** change a shapeshift form's appearance: *White Bear, Black Bear, Red Lynx, Forest Lynx, Black Wolf* (Blizzard's scrapped beta glyphs, restored) and *Glyph of the Orca* (aquatic form).
*   **Major effect glyphs** add new combat effects, such as *Glyph of the Zealot* (melee strikes can unleash an Exorcism).

Any creature can rarely drop one (bosses far more often), and three **Forgotten Grimoire** tomes hidden in remote corners of Azeroth and Northrend each hold a guaranteed random glyph for explorers who find them.

---

## Talent Points & Passive Progression

To give you more control over your character's build, `mod-spelldraft` features a custom Talent Point system alongside the active spell drafting:

*   **Earning Talent Points:** You earn **1 Talent Point per level-up** (from level 2 to 80). Death Knights are granted **54 Talent Points** on character creation (at level 55) to catch up.
*   **Purchasing Passives:** Open your Grimoire (type `/spelldraft` or click the *Grimoire* button on your talent frame) and and there you will find the **Talents** section. You can click on any unlocked passive talent from any class to purchase it using your points.
*   **Locked Talents (Draft-Only):** Active abilities, shapeshift forms, and playstyle-defining passive talents (like *Titan's Grip*, *Metamorphosis*, or *Tree of Life*) are **locked** (marked with a lock icon in the UI). These **cannot** be purchased with points and must be rolled and drafted from a **Tome of Talents** (drops chance from enemies and Bosses).
*   **Respecs:** If you wish to change your build, talk to **Nibbs the Imp** in starter zones or capital cities. He will reset all manually purchased talents and refund all spent points for free. Spells and talents you obtained through drafts are locked in and will not be touched by respecs.

---

## Death Knight Progression & Rules

Because Death Knights are a hero class and start at a higher level, the drafting system adapts to accommodate their progression:

*   **Starting State:** Upon character creation, a Death Knight starts at level 55, is granted all the standard native Death Knight starting abilities (Death Coil, Death Grip, Icy Touch, Plague Strike, Blood Strike, Blood Presence, Frost Presence, Death Gate, Runeforging, and the Acherus Deathcharger mount), and is immediately granted **5 spell drafts** to build their initial loadout.
*   **Drafts per Level:** Instead of 1 draft per level, Death Knights gain **3 active spell drafts per level-up** from level 56 to 80 to ensure they catch up with the spell counts of other classes.

---

## How Prestige Works

Once you reach the maximum level (80), you can visit the prestige NPC (Chromie) to prestige. The rules vary depending on your class type:

### Standard Classes
1.  **Level Reset:** Resets character level back to level 1.
2.  **Asset Mailbox Recovery:** Removes all your equipped gear and bags and mails them back to you so your inventory isn't lost.
3.  **Wipes Progress:** Clears all learned spells, active talents, quest histories, and action bars.
4.  **Scaling Rerolls & Bans:** Increases your prestige rank, grants a custom in-game title, and increases your starting rerolls/bans pool and rerolls per level-up for your next run.

### Death Knights
1.  **Level Reset:** Resets character level back to level 55.
2.  **Capital Gates Spawn:** Instead of starting back in the Ebon Hold starting zone, they spawn directly at the gates of their faction's capital city (Stormwind Gates for Alliance, Orgrimmar Gates for Horde).
3.  **Walk of Shame Quest:** Automatically accepts the final quest of the Death Knight starting chain ("Where Kings Walk" for Alliance, "Warchief's Blessing" for Horde) to integrate cleanly into the world.
4.  **Starting Spells:** Re-grants all the native starting Death Knight abilities (Death Coil, Death Grip, mount, Runeforging, etc.).
5.  **Asset Mailbox Recovery:** Removes all equipped gear and mails them back.
6.  **Wipes Progress:** Clears all drafted spells, active talents, quest histories, and action bars.
7.  **Catch-Up Mechanics:** Starts the next run with 5 drafts immediately, and gains 3 drafts per level-up from level 56 onwards.

---

## Step-by-Step Installation Instructions

### Option A: Automated Installation (Recommended)
We provide an automated script that performs all server-side staging, configuration, DBC deployment, and C++ Docker image rebuilding.

1. Clone or copy `mod-spelldraft` into your server's `/modules/` folder:
   ```bash
   git clone <repo_url> modules/mod-spelldraft
   ```
2. Run the server installer script:
   ```bash
   cd modules/mod-spelldraft
   ./install.sh
   ```
 3. **Install Client files:** Copy `wow-client/Interface/AddOns/SpellDraft` into your client's `Interface/AddOns/`, and copy `wow-client/Data/patch-P.mpq` into your client's `Data/` folder (native 3.3.5a clients; HD repack users must compile their own patch — see the HD section). Install exactly **one** SpellDraft archive per client — mounting the same archive twice corrupts the client heap and crashes with `ERROR #132` on every exit.
 4. Restart your server!

---

<details>
<summary><b>Option B: Manual Installation (Step-by-Step) - Click to expand</b></summary>

If you prefer to perform the steps yourself, follow this sequence:

1. **Place the module:** Clone or copy `mod-spelldraft` into your server's `/modules/` directory.
2. **Stage Lua scripts:** Copy the config and script files into your server's Lua scripts directory:
   ```bash
   mkdir -p ../../env/dist/etc/modules/lua_scripts/SpellDraft
   cp lua/spelldraft_config.lua ../../env/dist/etc/modules/lua_scripts/
   cp -r lua/SpellDraft/* ../../env/dist/etc/modules/lua_scripts/SpellDraft/
   ```
3. **Copy config:** Copy `conf/mod_spelldraft.conf.dist` to `../../env/dist/etc/modules/mod_spelldraft.conf`.
 4. **Deploy DBC files:** Copy `dbc/*.dbc` and any compiled server DBCs from `wow-client/DBC/*.dbc` (like `Spell.dbc` and `SpellShapeshiftForm.dbc`) into your server's runtime DBC directory:
    * **Docker:** Copy files directly into the named volume storage path on your host (e.g. `~/.local/share/containers/storage/volumes/wow-server-playerbots_ac-client-data/_data/dbc/`).
    * **Local:** Copy files into `/path/to/server/env/dist/data/dbc/`.
5. **Apply C++ core patch (Required for Combo Points):** Apply the C++ core patch to `Unit.cpp` to broadcast custom `SpellDraftCP` addon messages.

   Here is the Python script:
   ```python
   # patch_unit.py
   import sys
   u = "../../src/server/game/Entities/Unit/Unit.cpp"
   c = open(u, "r", encoding="utf-8").read()
   t = "playerMe->SendDirectMessage(&data);"
   r = t + """

        // Send custom SpellDraft addon message for custom combo point rendering
        std::string prefix = "SpellDraftCP";
        std::string message = std::to_string(m_comboPoints);
        std::string fullmsg = prefix + "\\t" + message;

        WorldPacket addonData(SMSG_MESSAGECHAT, 100);
        addonData << uint8(0); // CHAT_MSG_ADDON (Whisper/Normal channel context)
        addonData << int32(LANG_ADDON);
        addonData << playerMe->GetGUID();
        addonData << uint32(0);
        addonData << playerMe->GetGUID();
        addonData << uint32(fullmsg.length() + 1);
        addonData << fullmsg;
        addonData << uint8(0);
        playerMe->GetSession()->SendPacket(&addonData);"""

   if t in c and "SpellDraftCP" not in c:
       open(u, "w", encoding="utf-8").write(c.replace(t, r, 1))
   ```

   You can execute this patch directly from the `modules/mod-spelldraft/` directory in a single line:
   ```bash
   python3 -c 'import sys; u="../../src/server/game/Entities/Unit/Unit.cpp"; c=open(u,"r",encoding="utf-8").read(); t="playerMe->SendDirectMessage(&data);"; r=t+"\n\n        // Send custom SpellDraft addon message for custom combo point rendering\n        std::string prefix = \"SpellDraftCP\";\n        std::string message = std::to_string(m_comboPoints);\n        std::string fullmsg = prefix + \"\\t\" + message;\n\n        WorldPacket addonData(SMSG_MESSAGECHAT, 100);\n        addonData << uint8(0); // CHAT_MSG_ADDON (Whisper/Normal channel context)\n        addonData << int32(LANG_ADDON);\n        addonData << playerMe->GetGUID();\n        addonData << uint32(0);\n        addonData << playerMe->GetGUID();\n        addonData << uint32(fullmsg.length() + 1);\n        addonData << fullmsg;\n        addonData << uint8(0);\n        playerMe->GetSession()->SendPacket(&addonData);"; open(u,"w",encoding="utf-8").write(c.replace(t,r,1) if t in c and "SpellDraftCP" not in c else c)'
   ```
6. **Rebuild server:** Compile the C++ module code:
   * **Docker:** Rebuild the container: `docker compose build ac-worldserver` (or `docker compose up -d --build`).
   * **Local:** Run your local CMake and compilation toolchain.
 7. **Install Client files:** Copy/merge the contents of the `wow-client/` directory directly into your World of Warcraft client folder (which merges the `Data/` (including `Data/enUS/` locale patches) and `Interface/` subdirectories).

</details>

---

## Updating the Module

If you are updating to the latest version of `mod-spelldraft`, follow these steps to apply updates safely without losing any database data or player character progress:

### 1. Pull the Latest Code
Navigate to your module directory and pull the latest updates from GitHub:
```bash
cd modules/mod-spelldraft
git pull
```

### 2. Run the Installer Script
Run the automated installation script to redeploy the updated Lua scripts, configuration files, and DBC/C++ compiler changes:
```bash
./install.sh
```
> [!NOTE]
> The installation script will check if your active `mod_spelldraft.conf` configuration exists. If it does, it will **skip overwriting it** to preserve your custom settings.

### 3. Reload or Restart
To apply the changes, reload the Eluna scripting engine in-game or restart your server:
* **Reload Eluna (No Downtime):** Type `.eluna reload` in-game as a GM to immediately hot-reload the updated scripts. Affected players will just need to log out and back in to apply the updates.
* **Server Reboot:** Restart your worldserver container or process (e.g. `podman restart ac-worldserver` or `docker compose restart ac-worldserver`).

### 4. Update the Client Addon
Since updates may contain client-side fixes, copy the updated Addon files to your local game client:
* **Copy AddOn:** Copy the contents of `wow-client/Interface/AddOns/SpellDraft/` to your WoW client's `Interface/AddOns/SpellDraft/` directory, overwriting the old files.
* **Reload UI:** In-game, type `/reload` in the chat window to load the new AddOn layout.

---

## Configuration File Parameters

You can customize the draft system parameters by editing `lua_scripts/spelldraft_config.lua`:

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `MAX_LEVEL` | `80` | Level required to venture into Prestige Mode via gossip. |
| `NPC_ID` | `2069426` | Custom Chromie NPC gossip trigger. |
| `DRAFT_MODE_REROLLS` | `2` | Base reroll tokens given to characters starting a draft run (prestige 0). |
| `DRAFT_MODE_SPELLS` | `1` | Base number of spells a player gets when starting a draft. |
| `PRESTIGE1_REROLLS` | `5` | Starting rerolls granted at prestige 1. |
| `PRESTIGE1_REROLLS_PER_LEVEL` | `1` | Rerolls earned per level-up at prestige 1. |
| `PRESTIGE_REROLL_SCALING` | `2` | Reroll scaling increment added to both starting pool and per-level rerolls for each prestige rank beyond rank 1. |
| `DRAFT_BANS_START` | `5` | Initial bans given to characters to prune the spell pool. |
| `INCLUDE_RARITY_5` | `false` | Enable/disable broken/racial passives and infinitely spammable spells in the draft pool. |
| `REROLLS_PER_LEVELUP` | `0` | Rerolls earned per level-up at prestige 0 (none until first prestige). |
| `UNLIMITED_REROLLS_FIRST_DRAW` | `false` | When enabled, rerolls are free and unlimited until the character picks the very first spell of a draft run (`successful_drafts == 0`), regardless of class or level. The Reroll button shows `Reroll (∞)` while active; normal reroll accounting resumes after the first pick. Applies again on each prestige run, since the pick counter resets. |
| `CROSS_FACTION_PORTALS` | `false` | When enabled, all Portal/Teleport spells (both factions' capitals plus Theramore, Stonard, Shattrath, Dalaran, and Karazhan) are injected into the draft pool for both factions — Alliance characters can draft Horde city teleports and vice versa. Uses each spell's own rarity (teleports Common, portals Epic) and respects level requirements, bans, and already-known spells. |
| `POOL_AMOUNT` | `45` | The number of spells pooled from the full DB on every new draft. Every time a player reaches a level-up or consumes a Lost Grimoire, the system runs a database query to select 45 random, level-appropriate class abilities based on your configured rarity distribution. Rerolls select from this cached pool in memory instead of repeating heavy database queries, keeping server load minimal. |
| `RARITY_DISTRIBUTION` | `[0]=0.50, [1]=0.27, ...` | Probability ratios for Common (`[0]`), Uncommon (`[1]`), Rare (`[2]`), Epic (`[3]`), Legendary (`[4]`). |

### Prestige Shop Customization

The Prestige Shop inventory, item details, and token costs are defined and can be modified in two files:
1.  **Server-Side Costs:** The server-side cost validation is mapped in [spell_choice.lua](file:///home/bdodroid/wow-server-playerbots/modules/mod-spelldraft/lua/SpellDraft/spell_choice.lua#L927-L973) under the `costs` table in the `HandleBuyShopItem` function.
2.  **Client-Side UI:** The shop item entries, categories, descriptions, and displayed token costs are configured in [PrestigeShop.lua](file:///home/bdodroid/wow-server-playerbots/modules/mod-spelldraft/addon/SpellDraft/PrestigeShop.lua#L3-L75) under the `shopItems` table.

---

### Database-Level Loot Tuning

Because loot tables are applied once to the database during server startup/migration, drop rates are configured directly within the SQL files rather than the Lua config. 

To tune these drop rates, edit the `Chance` columns at the bottom of [05_prestige_draft_items.sql](data/sql/db-world/base/05_prestige_draft_items.sql) and the matching update statements in [08_consumable_id_swap.sql](data/sql/db-world/base/08_consumable_id_swap.sql).

| Item | Default (Normal/Elite) | Default (Bosses) | Location in SQL |
| :--- | :--- | :--- | :--- |
| **Scroll of Reroll** (`4427`) | `0.6%` | `10.0%` | `05_prestige_draft_items.sql` / `08_consumable_id_swap.sql` |
| **Scroll of Ban** (`1078`) | `0.6%` | `10.0%` | `05_prestige_draft_items.sql` / `08_consumable_id_swap.sql` |
| **Lost Grimoire** (`13149`) | `0.1%` | `5.0%` | `05_prestige_draft_items.sql` |
| **Tome of Talents** (`25462`) | `1.0%` | `15.0%` | `05_prestige_draft_items.sql` |


## GM Commands for Testing Consumable Items

For testing and verification in-game, you can use the following `.additem` commands to spawn the customized draft consumables:

*   **Tome of Talents**: `.additem 25462 <count>` (triggers passive talent drafting & progressive rank upgrading)
*   **Lost Grimoire**: `.additem 13149 <count>` (triggers an immediate bonus active spell draft)
*   **Scroll of Reroll**: `.additem 4427 <count>` (adds +1 Reroll charges)
*   **Scroll of Ban**: `.additem 1078 <count>` (adds +1 Ban charges)

### Mystic Enchants
*   `.rollre` — force-rolls a Mystic Enchant on every eligible weapon/armor item you carry (equipped + bags) at 100% chance; re-running it rerolls them.
*   Enchant services UI: talk to **Nibbs the Imp** (NPC `99000`) → *Open Mystic Enchant services*.

### Custom Glyphs
*   **Glyph of the Orca** (minor, cosmetic): `.additem 100001`
*   **Glyph of the Zealot** (major, effect): `.additem 100002`
*   Beta cosmetic glyphs: `.additem 40484` (White Bear), `.additem 40948` (Red Lynx), `.additem 43336` (Black Bear), `.additem 43337` (Forest Lynx), `.additem 43384` (Black Wolf)
*   Open the talent window → **Glyphs** tab, click the glyph item, then click a matching socket (level 15+). Minor glyphs morph the listed form; check effect glyphs with their combat proc.
*   Forgotten Grimoire spawns: `.go xyz -10782 -1378 40 0` (Duskwood), `.go xyz -7580 199 12 1` (Silithus), `.go xyz 4110 -4740 101 571` (Grizzly Hills).

---

## Building Client Patches for HD Repacks

The repository ships `wow-client/Data/patch-P.mpq` built for the **native 3.3.5a client only**. HD / custom repack clients need their own compile, for two reasons:

1. **Repacks ship modified DBCs.** They replace creature meshes/textures and often far more (one tested repack carries a 67 MB custom `Spell.dbc` in `patch-enUS-s.mpq`). Overriding those tables with native-based files breaks the repack: neon-green/invisible creature models, altered tooltips, and dangling database references that can destabilize the client. The patch must be compiled from the DBCs *your* repack actually uses — every repack is different, so no prebuilt HD archive is shipped.
2. **Repacks ship high-letter patches.** MPQ archives load in slot order (`patch-2..9`, then `patch-a..z`, locale patches outranking base ones at the same letter). A repack's own `patch-enUS-s.mpq` outranks `patch-P.mpq`, silently disabling SpellDraft's data — so HD builds are emitted as a **locale `-z` patch**, which outranks everything.

The two bundled tools handle this (no external MPQ software needed):

1. **Extract the client's effective DBCs** — the extractor walks the repack's full archive chain in load order and pulls out the version of each table the client actually resolves:
   ```bash
   python3 tools/extract_client_dbcs.py "/path/to/your hd client" /path/to/dbc_src
   ```
2. **Compile with an HD locale override patch:**
   ```bash
   python3 tools/build_client_patch.py --dbc-src /path/to/dbc_src --hd-locale enUS
   ```
   (Match `--hd-locale` to the client's locale folder, e.g. `enGB`, `deDE`.)
3. **Deploy** the resulting `wow-client/Data/enUS/patch-enUS-z.mpq` into the client's `Data/enUS/` folder. Do **not** also deploy `patch-P.mpq` — exactly one SpellDraft archive per client, ever (see the ERROR #132 warning in the connection guide).

Since all custom spells, items, glyphs, and models are defined in the single source of truth (`tools/client_patch_manifest.json`), compiling with your client's own database files as a base fully preserves all repack customizations while seamlessly adding all module features.

---

## Credits & Inspiration

This project is heavily inspired by and uses elements from the original [Prestige and Draft Mode](https://github.com/Youpeoples/Prestige-and-Draft-Mode) project by **Youpeoples** (Stephen Kania). 

We would like to extend our sincere thanks to **Youpeoples** and all contributors to the original repository for their awesome work and foundational layouts that made this custom classless drafting and prestige system possible!

---

## License

This project is completely open source. Anyone is free to copy, modify, distribute, or use any code, assets, or resources in this project for their own custom WoW server or any other purpose without restriction.
