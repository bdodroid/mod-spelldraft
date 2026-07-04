CONFIG = {
    MAX_LEVEL = 80,  --Level Required to venture into Prestige Mode(s) via NPC_ID Gossip

    NPC_ID = 2069426, --Default Custom Chromie npc. But can be put on any npc with a Gossip Flag

    DRAFT_MODE_REROLLS = 2, --Base rerolls for a brand new character (prestige 0)

    DRAFT_MODE_SPELLS = 1,  --Base Amount of Spells a player gets when starting Draft

    -- Reroll scaling after prestige. Prestige 1 = 5 start, +1/level.
    -- Each prestige beyond 1 adds +2 to both start pool and per-level.
    -- Formula: start = 5 + 2*(prestige-1), per_level = 1 + 2*(prestige-1)
    PRESTIGE1_REROLLS = 5,           --Starting rerolls at prestige 1
    PRESTIGE1_REROLLS_PER_LEVEL = 1, --Rerolls per level-up at prestige 1
    PRESTIGE_REROLL_SCALING = 2,     --Added to both start and per-level for each prestige beyond 1

    DRAFT_BANS_START = 5, --Amount of bans every player gets at the start of a draft
    
    INCLUDE_RARITY_5 = false, --These are broken(like infinitely spammable, they stil function, spells. This will ruin any sort of balance on your server. But if you're singleplayer, who cares? This also includes racial passives for now.

    REROLLS_PER_LEVELUP = 0, --Rerolls per level-up at prestige 0 (none until first prestige)

    POOL_AMOUNT = 45, --How many spells get pooled for the player to choose from. Higher numbers burdens server exponentially playercount goes up. Careful with this.

    RARITY_DISTRIBUTION = { -- Sum of 1.0 Distribution of rarities of spells filling up POOL_AMOUNT
        [0] = 0.50,
        [1] = 0.27,
        [2] = 0.14,
        [3] = 0.06,
        [4] = 0.03,
    },

    PrestigeTitles = {  --Titles Linked to the prestige & draft system. 11 titles for prestige progress and one Temporary 'draft mode only' title to differentiate players from others.
        [1] = 523, [2] = 524, [3] = 525, [4] = 526,
        [5] = 527, [6] = 528, [7] = 529, [8] = 530,
        [9] = 531, [10] = 532, [11] = 537
    },

    --- CHROMIE DIALOGUE

    CHROMIE_LOCATION_HORDE = "Chromie can be found just outside Orgrimmar.",  --At Max level, player gets an on screen message to go visit chromie to prestige. This does not set the location, this is the faction specific part of the phrase. Horde.

    CHROMIE_LOCATION_ALLIANCE = "Chromie can be found just outside Ironforge.",--At Max level, player gets an on screen message to go visit chromie to prestige. This does not set the location, this is the faction specific part of the phrase. Alliance.


    --Lore explaining away prestige in-world
    prestigeDescription = [[
    In the vast weave of time, there are countless realities where your character made different choices.

    Perhaps a Troll warrior learned the secrets of the Light, or a Tauren mage studied the mysteries of the arcane.

    The Prestige System lets you tap into these echoes of alternate timelines, drawing from destinies you never walked.. but could have.

    The Bronze Dragonflight has safeguarded these echoes, and now, with the timelines becoming increasingly unstable, we’ve made these echoes accessible.. with a cost, of course.

    To Prestige is to reset your journey through time, returning to your youth while retaining special memories in the form of unique spells, chosen from other realities.
    ]],

    --Players who are not MAX_LEVEL will see this message
    prestigeBlockedMessage = "You are not yet at max level.\nYou cannot partake in prestigeous events.",

    --This is the displayed list of things lost upon prestige.
    prestigeLossList = {
        "- Earned Levels",
        "- Learned Spells",
        "- Quest History",
        "- Talents and Talent Points",
        "- Equipped Gear(Returned via Mail)"
    },
    startingGear = {
      -- 0-Indexed Equipment Slot Map:
      -- 0 = Head, 1 = Neck, 2 = Shoulders, 3 = Shirt, 4 = Chest/Robe, 5 = Waist, 
      -- 6 = Legs, 7 = Feet, 8 = Wrists, 9 = Hands, 10 = Finger 1, 11 = Finger 2, 
      -- 12 = Trinket 1, 13 = Trinket 2, 14 = Back, 15 = Main Hand, 16 = Off Hand, 
      -- 17 = Ranged, 18 = Tabard, 19 = Bag 1 (Quiver), 20 = Ammo (Rough Arrow/Shot)
      ["HUMAN_WARRIOR"] = {
        [3] = 38, -- Recruit's Shirt (Shirt)
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 49778, -- Worn Greatsword (Main Hand)
      },
      ["HUMAN_PALADIN"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 44, -- Squire's Pants (Legs)
        [7] = 43, -- Squire's Boots (Feet)
        [15] = 2361, -- Battleworn Hammer (Main Hand)
      },
      ["HUMAN_ROGUE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["HUMAN_PRIEST"] = {
        [3] = 53, -- Neophyte's Shirt (Shirt)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["HUMAN_MAGE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 55, -- Apprentice's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["HUMAN_WARLOCK"] = {
        [3] = 6097, -- Acolyte's Shirt (Shirt)
        [4] = 57, -- Acolyte's Robe (Robe)
        [7] = 59, -- Acolyte's Shoes (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["NIGHTELF_WARRIOR"] = {
        [4] = 1364, -- Ragged Leather Vest (Chest)
        [6] = 1366, -- Ragged Leather Pants (Legs)
        [7] = 1367, -- Ragged Leather Boots (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
      },
      ["NIGHTELF_ROGUE"] = {
        [3] = 2105, -- Thug Shirt (Shirt)
        [6] = 120, -- Thug Pants (Legs)
        [7] = 121, -- Thug Boots (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["NIGHTELF_PRIEST"] = {
        [4] = 53, -- Neophyte's Shirt (Chest)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["NIGHTELF_HUNTER"] = {
        [3] = 148, -- Rugged Trapper's Shirt (Shirt)
        [6] = 147, -- Rugged Trapper's Pants (Legs)
        [7] = 129, -- Rugged Trapper's Boots (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
        [17] = 2504, -- Worn Shortbow (Ranged)
        [20] = 2512, -- Rough Arrow (Ammo)
      },
      ["NIGHTELF_DRUID"] = {
        [4] = 6098, -- Neophyte's Robe (Robe)
        [6] = 6124, -- Novice's Pants (Legs)
        [7] = 129, -- Rugged Trapper's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["GNOME_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [3] = 38, -- Recruit's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [15] = 25, -- Worn Shortsword (Main Hand)
      },
      ["GNOME_ROGUE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["GNOME_MAGE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 55, -- Apprentice's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["GNOME_WARLOCK"] = {
        [3] = 6097, -- Acolyte's Shirt (Shirt)
        [4] = 57, -- Acolyte's Robe (Robe)
        [7] = 59, -- Acolyte's Shoes (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["DRAENEI_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [6] = 39, -- Recruit's Pants (Legs)
        [15] = 25, -- Worn Shortsword (Main Hand)
      },
      ["DRAENEI_PALADIN"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 44, -- Squire's Pants (Legs)
        [7] = 43, -- Squire's Boots (Feet)
        [15] = 2361, -- Battleworn Hammer (Main Hand)
      },
      ["DRAENEI_HUNTER"] = {
        [3] = 6130, -- Trapper's Shirt (Shirt)
        [6] = 6135, -- Primitive Kilt (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
        [17] = 2504, -- Worn Shortbow (Ranged)
        [20] = 2512, -- Rough Arrow (Ammo)
      },
      ["DRAENEI_PRIEST"] = {
        [3] = 53, -- Neophyte's Shirt (Shirt)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["DRAENEI_MAGE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 55, -- Apprentice's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["DRAENEI_SHAMAN"] = {
        [3] = 154, -- Primitive Mantle (Shirt)
        [4] = 6098, -- Neophyte's Robe (Robe)
        [6] = 153, -- Primitive Kilt (Legs)
        [15] = 36, -- Worn Mace (Main Hand)
      },
      ["DWARF_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 48, -- Footpad's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
      },
      ["DWARF_PALADIN"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 44, -- Squire's Pants (Legs)
        [7] = 43, -- Squire's Boots (Feet)
        [15] = 2361, -- Battleworn Hammer (Main Hand)
      },
      ["DWARF_HUNTER"] = {
        [3] = 6130, -- Trapper's Shirt (Shirt)
        [6] = 6135, -- Primitive Kilt (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
        [17] = 2508, -- Old Blunderbuss (Ranged)
        [20] = 2516, -- Light Shot (Ammo)
      },
      ["DWARF_ROGUE"] = {
        [4] = 6123, -- Novice's Robe (Robe)
        [6] = 120, -- Thug Pants (Legs)
        [7] = 121, -- Thug Boots (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["DWARF_PRIEST"] = {
        [3] = 53, -- Neophyte's Shirt (Shirt)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["ORC_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 25, -- Worn Shortsword (Main Hand)
      },
      ["ORC_HUNTER"] = {
        [3] = 148, -- Rugged Trapper's Shirt (Shirt)
        [6] = 147, -- Rugged Trapper's Pants (Legs)
        [7] = 129, -- Rugged Trapper's Boots (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
        [17] = 2504, -- Worn Shortbow (Ranged)
        [20] = 2512, -- Rough Arrow (Ammo)
      },
      ["ORC_ROGUE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["ORC_SHAMAN"] = {
        [3] = 154, -- Primitive Mantle (Shirt)
        [4] = 6098, -- Neophyte's Robe (Robe)
        [6] = 153, -- Primitive Kilt (Legs)
        [15] = 36, -- Worn Mace (Main Hand)
      },
      ["ORC_WARLOCK"] = {
        [3] = 6097, -- Acolyte's Shirt (Shirt)
        [4] = 57, -- Acolyte's Robe (Robe)
        [7] = 59, -- Acolyte's Shoes (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["TROLL_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 25, -- Worn Shortsword (Main Hand)
      },
      ["TROLL_HUNTER"] = {
        [3] = 148, -- Rugged Trapper's Shirt (Shirt)
        [6] = 147, -- Rugged Trapper's Pants (Legs)
        [7] = 129, -- Rugged Trapper's Boots (Feet)
        [15] = 25, -- Worn Shortsword (Main Hand)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
        [20] = 2512, -- Rough Arrow (Ammo)
      },
      ["TROLL_ROGUE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["TROLL_SHAMAN"] = {
        [3] = 154, -- Primitive Mantle (Shirt)
        [4] = 6098, -- Neophyte's Robe (Robe)
        [6] = 153, -- Primitive Kilt (Legs)
        [15] = 36, -- Worn Mace (Main Hand)
      },
      ["TROLL_PRIEST"] = {
        [3] = 53, -- Neophyte's Shirt (Shirt)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["TROLL_MAGE"] = {
        [4] = 56, -- Apprentice's Robe (Robe)
        [6] = 1395, -- Apprentice's Pants (Legs)
        [7] = 20895, -- Apprentice's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["UNDEAD_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 25, -- Worn Shortsword (Main Hand)
      },
      ["UNDEAD_ROGUE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["UNDEAD_MAGE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 55, -- Apprentice's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["UNDEAD_WARLOCK"] = {
        [3] = 6097, -- Acolyte's Shirt (Shirt)
        [4] = 57, -- Acolyte's Robe (Robe)
        [7] = 59, -- Acolyte's Shoes (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["UNDEAD_PRIEST"] = {
        [3] = 53, -- Neophyte's Shirt (Shirt)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["TAUREN_WARRIOR"] = {
        [3] = 6125, -- Brawler's Harness (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 40, -- Recruit's Boots (Feet)
        [15] = 25, -- Worn Shortsword (Main Hand)
      },
      ["TAUREN_DRUID"] = {
        [4] = 6098, -- Neophyte's Robe (Robe)
        [6] = 139, -- Brawler's Pants (Legs)
        [7] = 140, -- Brawler's Boots (Feet)
        [15] = 35, -- Bent Staff (Main Hand)
      },
      ["TAUREN_SHAMAN"] = {
        [3] = 154, -- Primitive Mantle (Shirt)
        [4] = 6098, -- Neophyte's Robe (Robe)
        [6] = 153, -- Primitive Kilt (Legs)
        [15] = 36, -- Worn Mace (Main Hand)
      },
      ["BLOODELF_PALADIN"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 44, -- Squire's Pants (Legs)
        [7] = 43, -- Squire's Boots (Feet)
        [15] = 2361, -- Battleworn Hammer (Main Hand)
      },
      ["BLOODELF_ROGUE"] = {
        [3] = 45, -- Squire's Shirt (Shirt)
        [6] = 39, -- Recruit's Pants (Legs)
        [7] = 47, -- Footpad's Shoes (Feet)
        [15] = 2092, -- Worn Dagger (Main Hand)
      },
      ["BLOODELF_HUNTER"] = {
        [3] = 148, -- Rugged Trapper's Shirt (Shirt)
        [6] = 147, -- Rugged Trapper's Pants (Legs)
        [7] = 129, -- Rugged Trapper's Boots (Feet)
        [15] = 12282, -- Worn Battleaxe (Main Hand)
        [17] = 20980, -- Warder's Shortbow (Ranged)
        [19] = 2101, -- Light Quiver (Bag 1)
        [20] = 2512, -- Rough Arrow (Ammo)
      },
      ["BLOODELF_MAGE"] = {
        [4] = 56, -- Apprentice's Robe (Robe)
        [6] = 1395, -- Apprentice's Pants (Legs)
        [7] = 20895, -- Apprentice's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["BLOODELF_PRIEST"] = {
        [3] = 53, -- Neophyte's Shirt (Shirt)
        [6] = 52, -- Neophyte's Pants (Legs)
        [7] = 51, -- Neophyte's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["BLOODELF_WARLOCK"] = {
        [3] = 6097, -- Acolyte's Shirt (Shirt)
        [4] = 57, -- Acolyte's Robe (Robe)
        [7] = 59, -- Acolyte's Shoes (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["DEATHKNIGHT"] = {
        [0] = 34652, -- Acherus Knight's Hood (Head)
        [1] = 34657, -- Choker of Damnation (Neck)
        [4] = 34650, -- Acherus Knight's Tunic (Chest)
        [5] = 34651, -- Acherus Knight's Girdle (Waist)
        [6] = 34656, -- Acherus Knight's Legplates (Legs)
        [7] = 34648, -- Acherus Knight's Greaves (Feet)
        [9] = 34649, -- Acherus Knight's Gauntlets (Hands)
        [10] = 34658, -- Plague Band (Finger 1)
        [11] = 38147, -- Corrupted Band (Finger 2)
        [14] = 34659, -- Acherus Knight's Shroud (Back)
      },
      ["ORC_MAGE"] = {
        [4] = 56, -- Apprentice's Robe (Robe)
        [6] = 1395, -- Apprentice's Pants (Legs)
        [7] = 20895, -- Apprentice's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["DWARF_MAGE"] = {
        [4] = 56, -- Apprentice's Robe (Robe)
        [6] = 1395, -- Apprentice's Pants (Legs)
        [7] = 20895, -- Apprentice's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["TAUREN_MAGE"] = {
        [4] = 56, -- Apprentice's Robe (Robe)
        [6] = 1395, -- Apprentice's Pants (Legs)
        [7] = 20895, -- Apprentice's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      },
      ["NIGHTELF_MAGE"] = {
        [4] = 56, -- Apprentice's Robe (Robe)
        [6] = 1395, -- Apprentice's Pants (Legs)
        [7] = 20895, -- Apprentice's Boots (Feet)
        [15] = 20978, -- Apprentice's Staff (Main Hand)
      }
    },



    ---------------------------------------------------------------------------
    -- DRAFT PREREQUISITES
    -- Spells that require a specific class or a previously-drafted spell.
    ---------------------------------------------------------------------------

    -- Spells restricted to a specific player class (engine limitation).
    -- Key = spell ID, Value = required class ID (6 = Death Knight).
    -- These are DK abilities that cost Runes (not Runic Power). The Rune
    -- system is hardcoded to the DK class in the C++ engine.
    CLASS_LOCKED_SPELLS = {
        [45902] = 6,  -- Blood Strike (DEATHKNIGHT)
        -- Note: 52372, 52373, 52374 are removed from the pool by SQL 04.
        [55050] = 6,  -- Heart Strike (GENERAL)
        [45462] = 6,  -- Plague Strike (DEATHKNIGHT)
        [45477] = 6,  -- Icy Touch (DEATHKNIGHT)

        [49020] = 6,  -- Obliterate (DEATHKNIGHT)
        [49998] = 6,  -- Death Strike (DEATHKNIGHT)
        [50842] = 6,  -- Pestilence (DEATHKNIGHT)
        [48721] = 6,  -- Blood Boil (DEATHKNIGHT)
        [49184] = 6,  -- Howling Blast (GENERAL)
        [55090] = 6,  -- Scourge Strike (GENERAL)
        [43265] = 6,  -- Death and Decay (DEATHKNIGHT)
        [45524] = 6,  -- Chains of Ice (DEATHKNIGHT)
        [49576] = 6,  -- Death Grip (DEATHKNIGHT)
        [47476] = 6,  -- Strangulate (DEATHKNIGHT)
        [46584] = 6,  -- Raise Dead (DEATHKNIGHT)
        [42650] = 6,  -- Army of the Dead (DEATHKNIGHT)
        [42651] = 6,  -- Army of the Dead (DEATHKNIGHT)
        [50536] = 6,  -- Unholy Blight (GENERAL)
        [49222] = 6,  -- Bone Shield (GENERAL)
        [55233] = 6,  -- Vampiric Blood (GENERAL)
        [51271] = 6,  -- Unbreakable Armor (GENERAL)
        [51052] = 6,  -- Anti-Magic Zone (DEATHKNIGHT)
        [49158] = 6,  -- Corpse Explosion (GENERAL)
        [49005] = 6,  -- Mark of Blood (GENERAL)
        [49016] = 6,  -- Hysteria (GENERAL)
        [47568] = 6,  -- Empower Rune Weapon (DEATHKNIGHT)
    },

    -- Spells that require the player to already know a prerequisite spell.
    -- Key = spell ID, Value = single prereq ID or table of IDs (any one satisfies).
    SPELL_PREREQUISITES = {
        -- === Cat Form (768) required ===
        [5221]  = 768,   -- Shred
        [1822]  = 768,   -- Rake
        [6785]  = 768,   -- Ravage
        [9005]  = 768,   -- Pounce
        [1079]  = 768,   -- Rip
        [22568] = 768,   -- Ferocious Bite
        [22570] = 768,   -- Maim
        [33876] = 768,   -- Mangle (Cat)
        [8998]  = 768,   -- Cower
        [1850]  = 768,   -- Dash
        [5215]  = 768,   -- Prowl

        -- === Bear Form (5487) required ===
        [779]   = 5487,  -- Swipe (Bear)
        [6807]  = 5487,  -- Maul
        [6795]  = 5487,  -- Growl
        [5211]  = 5487,  -- Bash
        [33745] = 5487,  -- Lacerate
        [33878] = 5487,  -- Mangle (Bear)
        [22842] = 5487,  -- Frenzied Regeneration
        [5209]  = 5487,  -- Challenging Roar
        [99]    = 5487,  -- Demoralizing Roar
        [5229]  = 5487,  -- Enrage

        -- === Cat (768) OR Bear (5487) Form ===
        [16857] = {768, 5487},  -- Faerie Fire (Feral)
        [16979] = {768, 5487},  -- Feral Charge - Bear

        -- === Battle Stance (2457) required ===
        [100]   = 2457,  -- Charge
        [7384]  = 2457,  -- Overpower
        [694]   = 2457,  -- Mocking Blow
        [64382] = 2457,  -- Shattering Throw
        [20230] = 2457,  -- Retaliation
        [12328] = 2457,  -- Sweeping Strikes

        -- === Defensive Stance (71) required ===
        [23922] = 71,    -- Shield Slam
        [2565]  = 71,    -- Shield Block
        [871]   = 71,    -- Shield Wall
        [72]    = 71,    -- Shield Bash
        [676]   = 71,    -- Disarm
        [355]   = 71,    -- Taunt
        [23920] = 71,    -- Spell Reflection
        [46968] = 71,    -- Shockwave
        [50720] = 71,    -- Vigilance
        [12809] = 71,    -- Concussion Blow
        [12976] = 71,    -- Last Stand
        [12798] = 71,    -- Revenge Stun
        [3411]  = 71,    -- Intervene

        -- === Berserker Stance (2458) required ===
        [6552]  = 2458,  -- Pummel
        [18499] = 2458,  -- Berserker Rage
        [1719]  = 2458,  -- Recklessness
        [1680]  = 2458,  -- Whirlwind
        [20252] = 2458,  -- Intercept

        -- === Battle (2457) OR Defensive (71) Stance ===
        [6343]  = {2457, 71},    -- Thunder Clap

        -- === Battle (2457) OR Berserker (2458) Stance ===
        [5308]  = {2457, 2458},  -- Execute
        [20647] = {2457, 2458},  -- Execute

        -- === Rogue Stealth (1784) required ===
        [1842]  = 1784,  -- Disarm Trap
        [8676]  = 1784,  -- Ambush
        [1833]  = 1784,  -- Cheap Shot
        [703]   = 1784,  -- Garrote
        [6770]  = 1784,  -- Sap
        [921]   = 1784,  -- Pick Pocket
    },
}

function CONFIG.EnsurePlayerLanguage(player)
    local race = player:GetRace()
    
    -- Faction default languages (Alliance: Common, Horde: Orcish)
    local factionLanguageSkill = 98 -- Common
    local isHorde = (race == 2 or race == 5 or race == 6 or race == 8 or race == 10)
    if isHorde then
        factionLanguageSkill = 109 -- Orcish
    end

    if not player:HasSkill(factionLanguageSkill) then
        player:SetSkill(factionLanguageSkill, 1, 300, 300)
    end

    -- Blood Elf racial language (Thalassian)
    if race == 10 then
        if not player:HasSkill(137) then
            player:SetSkill(137, 1, 300, 300)
        end
    end
end
 
 