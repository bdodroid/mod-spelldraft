local scriptPath = debug.getinfo(1).source:sub(2)
local parentPath = scriptPath:match("(.+[/\\])") or ""
local rootPath = parentPath:match("(.+[/\\])[^/\\]+[/\\]$") or parentPath
dofile(rootPath .. "spelldraft_config.lua")

-- Playerbots must never enter the draft/prestige system.
-- IsBot() requires mod-ale with playerbots support; fall back to "not a bot" if absent.
local function IsBotPlayer(player)
    return player.IsBot ~= nil and player:IsBot()
end

local DUPLICATE_RACIAL_GROUPS = {
    -- Gift of the Naaru (Draenei)
    [59547] = { 28880, 59542, 59543, 59544, 59545, 59547, 59548 },
    -- Arcane Torrent (Blood Elf)
    [28730] = { 28730, 25046, 50613 }
}

local draftStateCache = {}

function SpellDraft_SetDraftStateCache(guid, state)
    draftStateCache[guid] = (state == 1 or state == true)
end

local function HasAnySpell(player, spellIds)
    for _, id in ipairs(spellIds) do
        if player:HasSpell(id) then
            return true
        end
    end
    return false
end


-- Configurable Chromie location messages
local CHROMIE_LOCATION_HORDE = CONFIG.CHROMIE_LOCATION_HORDE
local CHROMIE_LOCATION_ALLIANCE = CONFIG.CHROMIE_LOCATION_ALLIANCE
-- Check if the player is in draft state
local function IsPlayerInDraft(player)
    local guid = player:GetGUIDLow()
    if draftStateCache[guid] ~= nil then
        return draftStateCache[guid]
    end

    local query = CharDBQuery("SELECT draft_state FROM prestige_stats WHERE player_id = " .. guid)
    local inDraft = (query and query:GetUInt32(0) == 1) or false
    draftStateCache[guid] = inDraft
    return inDraft
end

-- Apply custom power values
local function ApplyDraftPowerTypes(player)
    if not player or not player:IsInWorld() then return end

    player:SetMaxPower(1, 1000) -- Rage (WoW scales Rage by 10, so 1000 = 100 Rage in UI)
    player:SetMaxPower(3, 100)  -- Energy (1-to-1 scaling)
    player:SetMaxPower(6, 1000) -- Runic Power (WoW scales Runic Power by 10, so 1000 = 100 RP in UI)

    -- Mana: ensure all characters have at least the baseline custom mana pool
    local intellect = player:GetStat(3) or 20
    local level = player:GetLevel() or 1
    local customMana = 150 + level * 50 + intellect * 15
    if player:GetMaxPower(0) < customMana then
        player:SetMaxPower(0, customMana)
        player:SetPower(customMana, 0) -- Initialize starting mana
    end

    -- Force Rage display to keep UI clean, letting client show native Health, Rage, and Mana
    if player:GetPowerType() ~= 1 then
        player:SetPowerType(1) -- Force Rage display
    end
end

-- Track ticking players
local draftTickerGUIDs = {}

local function StartDraftPowerTicker(player)
    local guid = player:GetGUIDLow()
    if draftTickerGUIDs[guid] then return end  -- Already ticking

    local eventId = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p or not p:IsInWorld() then
            RemoveEventById(draftTickerGUIDs[guid])
            draftTickerGUIDs[guid] = nil
            return
        end

        if p:GetPowerType() ~= 1 then
            p:SetPowerType(1)  -- Force Rage display
        end
    end, 2000, 0)

    draftTickerGUIDs[guid] = eventId
end



-- On login: ensure DB row, give title, maybe start ticker
local function GetStoredClass(player)
    local guid = player:GetGUIDLow()
    local result = CharDBQuery("SELECT stored_class FROM prestige_stats WHERE player_id = " .. guid)
    if result then
        return result:GetUInt8(0)
    end
    return nil
end

-- On login: ensure DB row, give title, maybe start ticker
local function EnsurePrestigeEntry(_, player)
    if IsBotPlayer(player) then return end
    CONFIG.EnsurePlayerLanguage(player)
    local guid = player:GetGUIDLow()
    local query = CharDBQuery("SELECT prestige_level, draft_state FROM prestige_stats WHERE player_id = " .. guid)

    if query then
        local prestigeLevel = query:GetUInt32(0)
        local draftState = query:GetUInt32(1)
        draftStateCache[guid] = (draftState == 1)
        
    if player then
        local titleId = CONFIG.PrestigeTitles[prestigeLevel]
        if titleId and not player:HasTitle(titleId) then
            player:SetKnownTitle(titleId)
        end
        if prestigeLevel >= 1 then
            player:SendBroadcastMessage("|cff00ff00[Prestige]|r Permanent 50% Experience Bonus is active!")
        end
    end
        CreateLuaEvent(function()
            local p = GetPlayerByGUID(guid)
            if not p then return end

            -- Sync draft title 535
            local hasTitle = p:HasTitle(535)
            if draftState == 1 then
                if not hasTitle then
                    p:SetKnownTitle(535)
                end
                ApplyDraftPowerTypes(p)
                StartDraftPowerTicker(p)

                -- Bypass the draft anti-cheat while the module itself teaches spells,
                -- or every grant below gets blocked and removed again.
                if type(SpellDraft_SetSystemLearning) == "function" then
                    SpellDraft_SetSystemLearning(guid, true)
                end

                -- Ensure all armor and weapon proficiencies
                local proficiencies = {
                    9078, 9077, 8737, 750,           -- Cloth, Leather, Mail, Plate
                    196, 197, 198, 199, 201, 202,    -- Axes, Maces, Swords (1H+2H)
                    227, 1180, 200, 15590,           -- Staves, Daggers, Polearms, Fists
                    264, 5011, 266, 2567, 5009, 107, -- Bows, Xbows, Guns, Thrown, Wands, Block
                    75, 5019, 2764,                  -- Auto Shot, Shoot, Throw
                }
                for _, sid in ipairs(proficiencies) do
                    if not p:HasSpell(sid) then
                        p:LearnSpell(sid)
                    end
                end

                -- Ensure all racial active and passive abilities
                local race = p:GetRace()
                local racialSpells = {
                    [1]  = { 59752, 20598, 20599, 20597, 20864 }, -- Human: Every Man for Himself, The Human Spirit, Diplomacy, Sword Spec, Mace Spec
                    [2]  = { 20572, 20573, 20575, 20574 },         -- Orc: Blood Fury, Hardiness, Command, Axe Spec
                    [3]  = { 20594, 20596, 20595, 2481, 59224 },   -- Dwarf: Stoneform, Frost Resistance, Gun Spec, Find Treasure, Mace Spec
                    [4]  = { 58984, 20582, 20585, 20583 },         -- Night Elf: Shadowmeld, Quickness, Wisp Spirit, Nature Resistance
                    [5]  = { 7744, 20577, 5227, 20579 },           -- Undead: Will of the Forsaken, Cannibalize, Underwater Breathing, Shadow Resistance
                    [6]  = { 20549, 20550, 20552, 20551 },         -- Tauren: War Stomp, Endurance, Cultivation, Nature Resistance
                    [7]  = { 20589, 20591, 20593, 20592 },         -- Gnome: Escape Artist, Expansive Mind, Engineering Spec, Arcane Resistance
                    [8]  = { 26297, 20555, 20557, 20558, 26290, 58943 }, -- Troll: Berserking, Regeneration, Beast Slaying, Bow Spec, Throwing Spec, Da Voodoo Shuffle
                    [10] = { 28730, 20554, 822 },                  -- Blood Elf: Arcane Torrent, Arcane Affinity, Magic Resistance
                    [11] = { 59547, 28878, 28875, 28877 },         -- Draenei: Gift of the Naaru, Heroic Presence, Gemcutting, Shadow Resistance
                }
                local list = racialSpells[race]
                if list then
                    for _, spellId in ipairs(list) do
                        local hasSpell = false
                        if DUPLICATE_RACIAL_GROUPS[spellId] then
                            hasSpell = HasAnySpell(p, DUPLICATE_RACIAL_GROUPS[spellId])
                        else
                            hasSpell = p:HasSpell(spellId)
                        end
                        if not hasSpell then
                            p:LearnSpell(spellId)
                        end
                    end
                end

                -- Ensure starting class spells for their stored class
                local STARTING_CLASS_SPELLS = {
                    [1]  = { 78, 2457 },             -- Warrior: Heroic Strike, Battle Stance
                    [2]  = { 21084, 635 },           -- Paladin: Seal of Righteousness, Holy Light
                    [3]  = { 2973, 75 },            -- Hunter: Raptor Strike, Auto Shot
                    [4]  = { 1752 },                 -- Rogue: Sinister Strike
                    [5]  = { 585, 2050 },            -- Priest: Smite, Lesser Heal
                    [7]  = { 403, 331 },             -- Shaman: Lightning Bolt, Healing Wave
                    [8]  = { 133, 587 },             -- Mage: Fireball, Frost Armor
                    [9]  = { 686, 688 },             -- Warlock: Shadow Bolt, Summon Imp
                    [11] = { 5176, 5185 },           -- Druid: Wrath, Healing Touch
                }
                local storedClass = GetStoredClass(p)
                local classSpells = storedClass and STARTING_CLASS_SPELLS[storedClass]
                if classSpells then
                    for _, sid in ipairs(classSpells) do
                        if not p:HasSpell(sid) then
                            p:LearnSpell(sid)
                        end
                    end
                end

                if type(SpellDraft_SetSystemLearning) == "function" then
                    SpellDraft_SetSystemLearning(guid, false)
                end
            elseif hasTitle then
                p:UnsetKnownTitle(535)
            end
        end, 3000, 1)

    else
        local class = player:GetClass()
        local startingDrafts = (class == 6) and 5 or CONFIG.DRAFT_MODE_SPELLS
        local startingPoints = (class == 6) and 54 or 0
        -- Start drafting immediately on first login!
        -- Synchronous write: spell_choice.lua's delayed first-login retry (and any
        -- early SC_CHECK / zone change) must be able to read this row right away.
        CharDBQuery(string.format([[
            INSERT INTO prestige_stats
            (player_id, prestige_level, draft_state, stored_class, total_expected_drafts, rerolls, bans, talent_points)
            VALUES (%d, 0, 1, %d, %d, %d, %d, %d)
        ]], guid, class, startingDrafts, CONFIG.DRAFT_MODE_REROLLS, CONFIG.DRAFT_BANS_START, startingPoints))

        -- Custom Mage Race starting gear injection
        if class == 8 then
            local race = player:GetRace()
            if race == 2 or race == 4 or race == 6 then
                player:AddItem(45, 1)    -- Squire's Shirt
                player:AddItem(39, 1)    -- Recruit's Pants
                player:AddItem(55, 1)    -- Apprentice's Boots
                player:AddItem(35, 1)    -- Bent Staff
                player:AddItem(159, 5)   -- Refreshing Spring Water
                
                player:EquipItem(45, 3)
                player:EquipItem(39, 6)
                player:EquipItem(55, 7)
                player:EquipItem(35, 15)
            end
        end

        draftStateCache[guid] = true

        CreateLuaEvent(function()
            local p = GetPlayerByGUID(guid)
            if not p or not p:IsInWorld() then return end

            -- Remove default starting class spells so player starts classless (excluding any spells already drafted during the login race window)
            local spellsQ = CharDBQuery("SELECT spell FROM character_spell WHERE guid = " .. guid .. " AND spell NOT IN (SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid .. ")")
            if spellsQ then
                local spellsToRemove = {}
                repeat
                    local spellId = spellsQ:GetUInt32(0)
                    local spellCheck = WorldDBQuery("SELECT ClassMask FROM skilllineability_dbc WHERE Spell = " .. spellId)
                    if spellCheck and spellCheck:GetUInt32(0) > 0 then
                        table.insert(spellsToRemove, spellId)
                    end
                until not spellsQ:NextRow()

                for _, spellId in ipairs(spellsToRemove) do
                    p:RemoveSpell(spellId)
                end
            end

            -- Bypass the draft anti-cheat while the module itself teaches spells,
            -- or every grant below gets blocked and removed again.
            if type(SpellDraft_SetSystemLearning) == "function" then
                SpellDraft_SetSystemLearning(guid, true)
            end

            -- Grant all armor and weapon proficiencies
            local proficiencies = {
                -- Armor
                9078,   -- Cloth
                9077,   -- Leather
                8737,   -- Mail
                750,    -- Plate Mail
                -- Weapons
                196,    -- One-Handed Axes
                197,    -- Two-Handed Axes
                198,    -- One-Handed Maces
                199,    -- Two-Handed Maces
                201,    -- One-Handed Swords
                202,    -- Two-Handed Swords
                227,    -- Staves
                1180,   -- Daggers
                200,    -- Polearms
                15590,  -- Fist Weapons
                264,    -- Bows
                5011,   -- Crossbows
                266,    -- Guns
                2567,   -- Thrown
                5009,   -- Wands
                107,    -- Block (Shield use)
                75,     -- Auto Shot
                5019,   -- Shoot
                2764,   -- Throw
            }
            for _, spellId in ipairs(proficiencies) do
                if not p:HasSpell(spellId) then
                    p:LearnSpell(spellId)
                end
            end

            -- Ensure all racial active and passive abilities
            local race = p:GetRace()
            local racialSpells = {
                [1]  = { 59752, 20598, 20599, 20597, 20864 }, -- Human: Every Man for Himself, The Human Spirit, Diplomacy, Sword Spec, Mace Spec
                [2]  = { 20572, 20573, 20575, 20574 },         -- Orc: Blood Fury, Hardiness, Command, Axe Spec
                [3]  = { 20594, 20596, 20595, 2481, 59224 },   -- Dwarf: Stoneform, Frost Resistance, Gun Spec, Find Treasure, Mace Spec
                [4]  = { 58984, 20582, 20585, 20583 },         -- Night Elf: Shadowmeld, Quickness, Wisp Spirit, Nature Resistance
                [5]  = { 7744, 20577, 5227, 20579 },           -- Undead: Will of the Forsaken, Cannibalize, Underwater Breathing, Shadow Resistance
                [6]  = { 20549, 20550, 20552, 20551 },         -- Tauren: War Stomp, Endurance, Cultivation, Nature Resistance
                [7]  = { 20589, 20591, 20593, 20592 },         -- Gnome: Escape Artist, Expansive Mind, Engineering Spec, Arcane Resistance
                [8]  = { 26297, 20555, 20557, 20558, 26290, 58943 }, -- Troll: Berserking, Regeneration, Beast Slaying, Bow Spec, Throwing Spec, Da Voodoo Shuffle
                [10] = { 28730, 20554, 822 },                  -- Blood Elf: Arcane Torrent, Arcane Affinity, Magic Resistance
                [11] = { 59547, 28878, 28875, 28877 },         -- Draenei: Gift of the Naaru, Heroic Presence, Gemcutting, Shadow Resistance
            }
            local list = racialSpells[race]
            if list then
                for _, spellId in ipairs(list) do
                    local hasSpell = false
                    if DUPLICATE_RACIAL_GROUPS[spellId] then
                        hasSpell = HasAnySpell(p, DUPLICATE_RACIAL_GROUPS[spellId])
                    else
                        hasSpell = p:HasSpell(spellId)
                    end
                    if not hasSpell then
                        p:LearnSpell(spellId)
                    end
                end
            end

            if type(SpellDraft_SetSystemLearning) == "function" then
                SpellDraft_SetSystemLearning(guid, false)
            end

            -- Sync resource states
            ApplyDraftPowerTypes(p)
            StartDraftPowerTicker(p)

            -- Grant Tome of Talents
            p:AddItem(25462, 1)
            p:SendBroadcastMessage("You have been granted a |cff00ccffTome of Talents|r! Use it to draft your first passive talent.")
        end, 2000, 1)
    end
end


-- Apply draft state if needed
local function OnRebuildEvent(_, player)
    if IsBotPlayer(player) then return end
    if IsPlayerInDraft(player) then
        ApplyDraftPowerTypes(player)
        StartDraftPowerTicker(player)
    end
end
local function OnPlayerLogout(_, player)
    local guid = player:GetGUIDLow()
    if draftTickerGUIDs[guid] then
        RemoveEventById(draftTickerGUIDs[guid])
        draftTickerGUIDs[guid] = nil
    end


    draftStateCache[guid] = nil
end

local function OnLevelUp(event, player, oldLevel)
    if IsBotPlayer(player) then return end
    local newLevel = player:GetLevel()
    if newLevel == CONFIG.MAX_LEVEL then
        local factionGroup = player:GetTeam()  -- 0 = Alliance, 1 = Horde
        local locationMsg = (factionGroup == 1) and CHROMIE_LOCATION_HORDE or CHROMIE_LOCATION_ALLIANCE

        local fullMessage = "|cffffcc00You have reached level " .. CONFIG.MAX_LEVEL .. "!|r You can now access |cffff8800Prestige|r and |cff00ccffPrestige Draft Mode|r. " .. locationMsg
        player:SendAreaTriggerMessage(fullMessage)
    end

    -- Custom Talent Points progression
    if IsPlayerInDraft(player) then
        local diff = newLevel - oldLevel
        if diff > 0 then
            local guid = player:GetGUIDLow()
            -- Synchronous write so the SyncTalentPoints read below can't race it
            CharDBQuery("UPDATE prestige_stats SET talent_points = talent_points + " .. diff .. " WHERE player_id = " .. guid)
            if type(SyncDraftStats) == "function" then
                SyncDraftStats(player)
            end
        end
    end
end

local function OnGiveXP(event, player, amount, victim)
    if IsBotPlayer(player) then return end
    local guid = player:GetGUIDLow()
    local q = CharDBQuery("SELECT prestige_level FROM prestige_stats WHERE player_id = " .. guid)
    if q then
        local prestigeLevel = q:GetUInt32(0)
        if prestigeLevel >= 1 then
            return math.floor(amount * 1.5)
        end
    end
end

-- Register only valid events
RegisterPlayerEvent(4, OnPlayerLogout)
RegisterPlayerEvent(13, OnLevelUp)  -- 13 = PLAYER_EVENT_ON_LEVEL_CHANGE
RegisterPlayerEvent(3, EnsurePrestigeEntry)   -- On login
RegisterPlayerEvent(13, OnRebuildEvent)       -- On level change
RegisterPlayerEvent(28, OnRebuildEvent)       -- On map change
RegisterPlayerEvent(35, OnRebuildEvent)       -- On repop
RegisterPlayerEvent(36, OnRebuildEvent)       -- On resurrect
RegisterPlayerEvent(12, OnGiveXP)            -- PLAYER_EVENT_ON_GIVE_XP


