local scriptPath = debug.getinfo(1).source:sub(2)
local parentPath = scriptPath:match("(.+[/\\])") or ""
local rootPath = parentPath:match("(.+[/\\])[^/\\]+[/\\]$") or parentPath
math.randomseed(os.time())
math.random(); math.random(); math.random() -- Warm up generator
dofile(rootPath .. "spelldraft_config.lua")

local lastMsgTimes = {}

-- Playerbots must never enter the draft/prestige system.
-- IsBot() requires mod-ale with playerbots support; fall back to "not a bot" if absent.
local function IsBotPlayer(player)
    return player.IsBot ~= nil and player:IsBot()
end

local activeTalentDrafts = {}

local function SendDraftChoices(player, spells)
    local guid = player:GetGUIDLow()
    local isTalent = (activeTalentDrafts and activeTalentDrafts[guid]) and "1" or "0"
    player:SendAddonMessage("SpellChoiceIsTalent", isTalent, 0, player)

    player:SendAddonMessage("SpellChoice", table.concat(spells, ","), 0, player)
    local rarityParts = {}
    if #spells > 0 then
        local q = WorldDBQuery("SELECT Id, Rarity FROM dbc_spells WHERE Id IN (" .. table.concat(spells, ",") .. ")")
        local rarityById = {}
        if q then
            repeat
                rarityById[q:GetUInt32(0)] = q:IsNull(1) and "-1" or tostring(q:GetUInt8(1))
            until not q:NextRow()
        end
        for _, id in ipairs(spells) do
            table.insert(rarityParts, rarityById[id] or "-1")
        end
    end
    player:SendAddonMessage("SpellChoiceRarities", table.concat(rarityParts, ","), 0, player)
end


local DRAFT_MODE_SPELLS = CONFIG.DRAFT_MODE_SPELLS

local function GetExpectedDraftsFormula(class, level)
    if class == 6 then
        return math.max(5, 5 + (level - 55) * 3)
    else
        return DRAFT_MODE_SPELLS + (level - 1)
    end
end
local INCLUDE_RARITY_5 = CONFIG.INCLUDE_RARITY_5
local REROLLS_PER_LEVELUP = CONFIG.REROLLS_PER_LEVELUP
local POOL_AMOUNT = CONFIG.POOL_AMOUNT
local RARITY_DISTRIBUTION = CONFIG.RARITY_DISTRIBUTION
local protectedSpellIds = { 
  -- Riding Training
  [54197]=true, [33388]=true, [33391]=true, [34090]=true, [34091]= true,
   -- Alchemy
  [2259]=true, [3101]=true, [3464]=true, [11611]=true, [28596]=true, [51304]=true,
  -- Herbalism
  [2366]=true, [2368]=true, [3570]=true, [11993]=true, [28695]=true, [50300]=true,
  -- Herbalism Extras
  [2383]=true, [32605]=true,
  -- Enchanting
  [7411]=true, [7412]=true, [7413]=true, [13920]=true, [28029]=true, [51313]=true,
  -- Enchanting Extras
  [13262]=true,
  -- Blacksmithing
  [2018]=true, [3100]=true, [3538]=true, [9785]=true, [29844]=true, [51300]=true,
  -- Inscription
  [45357]=true, [45358]=true, [45359]=true, [45360]=true, [45361]=true, [45363]=true,
  --Inscription Extras
  [55005]=true,
  -- Engineering
  [4036]=true, [4037]=true, [4038]=true, [12656]=true, [30350]=true, [49383]=true, [51306]=true,
  -- Skinning
  [8163]=true, [8167]=true, [8168]=true, [10768]=true, [13697]=true, [32678]=true, [50305]=true, [52158]=true,
  -- Tailoring
  [3908]=true, [3909]=true, [3910]=true, [12180]=true, [26790]=true, [51309]=true,
  -- Leatherworking
  [2108]=true, [3104]=true, [3811]=true, [10662]=true, [32549]=true, [51302]=true,
  -- Jewelcrafting
  [25229]=true, [25230]=true, [28894]=true, [28895]=true, [28897]=true, [51311]=true,
  -- Cooking
  [2550]=true, [3102]=true, [3413]=true, [18260]=true, [33359]=true, [51296]=true,
  -- Cooking Extras
  [818]=true,
  -- First Aid
  [3273]=true, [3274]=true, [7924]=true, [10846]=true, [27028]=true, [45544]=true,
  -- Fishing
  [7620]=true, [7732]=true, [7731]=true, [18248]=true, [33095]=true, [51294]=true,
  -- Fishing Extras
  [7738]=true,
}
-- Tracks which players are actively “drafting” a spell (so we don’t block those)
local draftingPlayers = {}

-- Lets other module scripts (prestige.lua grant loops) bypass the OnLearnSpell
-- anti-cheat while the SYSTEM teaches spells (proficiencies, racials, starter kits).
-- Without this, module-granted spells get blocked and removed 250ms later.
function SpellDraft_SetSystemLearning(guid, active)
    draftingPlayers[guid] = active or nil
end
activeTalentDrafts = {}
local talentChains = {}
local SyncDraftedTalents
local BeginDraftLoop
local blacklistedSpellIds = {
    [20184] = true, -- Judgement of Justice (Trigger)
    [20185] = true, -- Judgement of Light (Trigger)
    [20187] = true, -- Judgement of Righteousness (Trigger)
    [20425] = true, -- Judgement of Command (Trigger)
    [20467] = true, -- Judgement of Command (Trigger)
    [27285] = true, -- Seed of Corruption (Detonation Trigger)
    [47833] = true, -- Seed of Corruption (Detonation Trigger Rank 2)
    [47834] = true, -- Seed of Corruption (Detonation Trigger Rank 3)
    [55166] = true, -- Tidal Force (Trigger)
    [34919] = true, -- Vampiric Touch (Dispel Damage Trigger)
    [42234] = true, -- Volley (Damage Trigger Rank 1)
    [42243] = true, -- Volley (Damage Trigger Rank 2)
    [42244] = true, -- Volley (Damage Trigger Rank 3)
    [42245] = true, -- Volley (Damage Trigger Rank 4)
    [42651] = true, -- Army of the Dead (Ghoul Spawn Trigger)
    [47666] = true, -- Penance (Damage Trigger)
    [47750] = true, -- Penance (Heal Trigger)
    [25912] = true, -- Holy Shock (Damage Trigger)
    [25914] = true, -- Holy Shock (Heal Trigger)
    [13797] = true, -- Immolation Trap (Periodic Trigger)
    [42231] = true, -- Hurricane (Damage Trigger)
}

local talentIdToChain = {}
local LOCKED_TALENTS = {
    -- DEATHKNIGHT (21)
    [61154] = true, [49028] = true, [55050] = true, [49016] = true, [49005] = true, [48982] = true, [55233] = true, [49189] = true,
    [49796] = true, [49143] = true, [49184] = true, [49203] = true, [49039] = true, [51271] = true, [51052] = true, [49222] = true,
    [49158] = true, [63560] = true, [49146] = true, [55090] = true, [49206] = true,
    -- DRUID (14)
    [33831] = true, [5570] = true, [24858] = true, [48505] = true, [50516] = true, [50334] = true, [49377] = true, [33917] = true,
    [37116] = true, [61336] = true, [17116] = true, [18562] = true, [65139] = true, [48438] = true,
    -- HUNTER (13)
    [53270] = true, [19574] = true, [19577] = true, [19434] = true, [53209] = true, [23989] = true, [34490] = true, [19506] = true,
    [3674] = true, [19306] = true, [53301] = true, [19503] = true, [19386] = true,
    -- MAGE (16)
    [44425] = true, [12042] = true, [54646] = true, [12043] = true, [31589] = true, [11113] = true, [11129] = true, [31661] = true,
    [64353] = true, [44457] = true, [11366] = true, [11958] = true, [44572] = true, [11426] = true, [12472] = true, [31687] = true,
    -- PALADIN (14)
    [31821] = true, [53563] = true, [20216] = true, [31842] = true, [20473] = true, [31935] = true, [20911] = true, [64205] = true,
    [53595] = true, [20925] = true, [35395] = true, [53385] = true, [20066] = true, [20375] = true,
    -- PRIEST (15)
    [14751] = true, [33206] = true, [47540] = true, [10060] = true, [34861] = true, [19236] = true, [47788] = true, [724] = true,
    [47585] = true, [15407] = true, [64044] = true, [15473] = true, [15487] = true, [15286] = true, [34914] = true,
    -- ROGUE (13)
    [14177] = true, [51662] = true, [1329] = true, [13750] = true, [13877] = true, [51690] = true, [14251] = true, [14278] = true,
    [16511] = true, [14183] = true, [14185] = true, [51713] = true, [36554] = true,
    -- SHAMAN (15)
    [16166] = true, [51490] = true, [30706] = true, [30798] = true, [51533] = true, [60103] = true, [30823] = true, [16268] = true,
    [17364] = true, [51886] = true, [974] = true, [16190] = true, [16188] = true, [61295] = true, [55198] = true,
    -- WARLOCK (13)
    [18223] = true, [18220] = true, [48181] = true, [30108] = true, [47193] = true, [18708] = true, [59672] = true, [19028] = true,
    [30146] = true, [50796] = true, [17962] = true, [17877] = true, [30283] = true,
    -- WARRIOR (13)
    [46924] = true, [12294] = true, [12328] = true, [23881] = true, [12292] = true, [60970] = true, [12323] = true, [46917] = true,
    [12809] = true, [20243] = true, [12975] = true, [46968] = true, [50720] = true,
}

local function LoadTalentChains()
    local query = WorldDBQuery([[
        SELECT ID, TierID, SpellRank_1, SpellRank_2, SpellRank_3, SpellRank_4,
               SpellRank_5, SpellRank_6, SpellRank_7, SpellRank_8, SpellRank_9,
               PrereqTalent_1, PrereqRank_1, PrereqTalent_2, PrereqRank_2, PrereqTalent_3, PrereqRank_3
          FROM talent_dbc
    ]])
    if not query then return end
    local count = 0
    repeat
        local talentId = query:GetInt32(0)
        local tierId = query:GetInt32(1)
        local ranks = {}
        for i = 2, 10 do
            local spellId = query:GetInt32(i)
            if spellId > 0 then
                table.insert(ranks, spellId)
            end
        end
        
        if #ranks > 0 then
            count = count + 1
            local prereqs = {}
            for k = 11, 15, 2 do
                local pTalent = query:GetInt32(k)
                local pRank = query:GetInt32(k+1)
                if pTalent > 0 then
                    table.insert(prereqs, { prereqTalentId = pTalent, reqRank = pRank + 1 })
                end
            end
            
            local chain = { talentId = talentId, tierId = tierId, ranks = ranks, prereqs = prereqs }
            talentIdToChain[talentId] = chain
            
            for rankIndex, spellId in ipairs(ranks) do
                talentChains[spellId] = {
                    talentId = talentId,
                    tierId = tierId,
                    rankIndex = rankIndex,
                    ranks = ranks,
                    chain = chain
                }
            end
        end
    until not query:NextRow()

    print("[SpellChoice] Loaded " .. tostring(count) .. " talent chains from talent_dbc.")
end

local function GetEligibleTalentsPool(player, level)
    local guid = player:GetGUIDLow()
    local queryLevel = math.max(level, 20)
    
    -- 1. Get player's currently known/drafted spells
    local knownSpells = {}
    local knownQ = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid)
    if knownQ then
        repeat
            knownSpells[knownQ:GetUInt32(0)] = true
        until not knownQ:NextRow()
    end
    local memSpells = player:GetSpells()
    for _, sid in ipairs(memSpells) do
        knownSpells[sid] = true
    end
    
    -- 2. For each talent chain, find the highest rank the player knows
    local knownTalentRanks = {}
    for spellId, info in pairs(talentChains) do
        if knownSpells[spellId] then
            local talentId = info.talentId
            local rankIndex = info.rankIndex
            knownTalentRanks[talentId] = math.max(knownTalentRanks[talentId] or 0, rankIndex)
        end
    end
    
    -- 3. Determine next rank for every talent chain
    local nextRankSpells = {}
    local talentIdToSpellId = {}
    for spellId, info in pairs(talentChains) do
        local talentId = info.talentId
        if not talentIdToSpellId[talentId] then
            local highestRank = knownTalentRanks[talentId] or 0
            local nextRankIndex = highestRank + 1
            if nextRankIndex <= #info.ranks then
                local nextSpellId = info.ranks[nextRankIndex]
                nextRankSpells[nextSpellId] = true
                talentIdToSpellId[talentId] = nextSpellId
            end
        end
    end
    
    -- 4. Filter nextRankSpells by level requirements directly using their tier.
    -- The Tome pool is restricted to the locked actives/playstyle passives; all
    -- other (passive) talents are bought with custom Talent Points instead.
    local pool = {}
    for spellId, _ in pairs(nextRankSpells) do
        local info = talentChains[spellId]
        if info and LOCKED_TALENTS[info.ranks[1]] then
            local reqLevel = 10 + info.tierId * 5
            if reqLevel <= queryLevel then
                if not blacklistedSpellIds[spellId] and not knownSpells[spellId] then
                    table.insert(pool, spellId)
                end
            end
        end
    end
    
    return pool
end

-- Tracks which spells were just blocked from a trainer, so UpgradeKnownSpells will skip exactly those
local justBlockedSpells = {}
local lastSpellChoiceSent = {}

-- Holds the full valid pool per player
local fullSpellPools = {}
-- Holds the current 3 choices shown to player

local currentDraftChoices = {}-- List of exact spell IDs to exclude
-- Utility: shuffle and select N random spells
local function GetRandomSpells(num, guid, excludeSet)
    local bannedSet = {}
    local q = CharDBQuery("SELECT spell_id FROM draft_bans WHERE player_id = " .. guid)
    if q then
        repeat
            bannedSet[q:GetUInt32(0)] = true
        until not q:NextRow()
    end

    local copy = {}
    for _, id in ipairs(fullSpellPools[guid] or {}) do
        if not bannedSet[id] and not (excludeSet and excludeSet[id]) then
            table.insert(copy, id)
        end
    end

    -- Shuffle and return
    for i = #copy, 2, -1 do
        local j = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end

    local result = {}
    local seen = {}
    for i = 1, #copy do
        local id = copy[i]
        if not seen[id] then
            table.insert(result, id)
            seen[id] = true
        end
        if #result >= num then break end
    end


    return result
end
local function LoadSpellsFromDB(guid)
    local banned = {}
    local banQ = CharDBQuery("SELECT spell_id FROM draft_bans WHERE player_id = " .. guid)
    if banQ then
        repeat
            banned[banQ:GetUInt32(0)] = true
        until not banQ:NextRow()
    end

    local res = CharDBQuery("SELECT offered_spell_1, offered_spell_2, offered_spell_3 FROM prestige_stats WHERE player_id = " .. guid)
    if not res then return nil end

    local spells = {}
    for i = 0, 2 do
        local id = res:GetUInt32(i)
        if id and id > 0 and not banned[id] then
            table.insert(spells, id)
        end
    end

    -- Replace banned slots with new picks from pool
    if #spells < 3 then
        local needed = 3 - #spells
        local fill = GetRandomSpells(needed, guid)
        for _, id in ipairs(fill) do
            table.insert(spells, id)
        end

        -- Update DB with cleaned set
        CharDBExecute(string.format("UPDATE prestige_stats SET offered_spell_1 = %d, offered_spell_2 = %d, offered_spell_3 = %d WHERE player_id = %d",
            spells[1] or 0, spells[2] or 0, spells[3] or 0, guid))


    end

    currentDraftChoices[guid] = spells
    return spells
end


local function CheckAndRestorePendingDraft(player)
    local guid = player:GetGUIDLow()
    local res = CharDBQuery("SELECT offered_spell_1, offered_spell_2, offered_spell_3 FROM prestige_stats WHERE player_id = " .. guid)
    if not res then return false end

    local s1 = res:GetUInt32(0)
    if s1 > 0 then
        local spells = {s1, res:GetUInt32(1), res:GetUInt32(2)}
        local isTalent = true
        local count = 0
        for _, id in ipairs(spells) do
            if id > 0 then
                count = count + 1
                local inChains = (talentChains and talentChains[id]) ~= nil
                if not inChains then
                    isTalent = false
                end
            end
        end
        if count == 0 then isTalent = false end

        if isTalent then
            activeTalentDrafts[guid] = true
        else
            activeTalentDrafts[guid] = nil
        end
        currentDraftChoices[guid] = spells

        player:SendAddonMessage("SpellChoiceStatus", "prestiged", 0, player)

        SendDraftChoices(player, spells)
        return true
    end
    return false
end


local function SaveSpellsToDB(guid, spells)
    local s1 = spells[1] or 0
    local s2 = spells[2] or 0
    local s3 = spells[3] or 0
    CharDBExecute(string.format([[
        UPDATE prestige_stats
        SET offered_spell_1 = %d, offered_spell_2 = %d, offered_spell_3 = %d
        WHERE player_id = %d
    ]], s1, s2, s3, guid))
end


-- Utility: check if spell ID is blacklisted
local function isBlacklistedSpellId(spellId)
    return blacklistedSpellIds[spellId] == true
end

-- Main loader function with randomization and filtering
local function LoadValidSpellChoices(player, maxLevel)
    local guid = player:GetGUIDLow()
    local pool = {}
    -- Fetch all banned spell *names* to exclude all ranks
    local bannedNames = {}
    local banIds = {}
    local banQ = CharDBQuery("SELECT spell_id FROM draft_bans WHERE player_id = " .. guid)
    if banQ then
        repeat
            table.insert(banIds, banQ:GetUInt32(0))
        until not banQ:NextRow()
    end
    if #banIds > 0 then
        for offset = 1, #banIds, 500 do
            local chunk = {}
            for i = offset, math.min(offset + 499, #banIds) do
                table.insert(chunk, banIds[i])
            end
            local nameQ = WorldDBQuery("SELECT Name_Lang_enUS FROM dbc_spells WHERE Id IN (" .. table.concat(chunk, ",") .. ")")
            if nameQ then
                repeat
                    if not nameQ:IsNull(0) then
                        bannedNames[nameQ:GetString(0)] = true
                    end
                until not nameQ:NextRow()
            end
        end
    end
    fullSpellPools[guid] = pool

    -- Step 1: Load known spells
    local knownSpellIds = {}
    local knownSpellNames = {}
    local rawKnownIds = {}
    local knownQuery = CharDBQuery("SELECT spell FROM character_spell WHERE guid = " .. player:GetGUIDLow())
    if knownQuery then
        repeat
            local sid = knownQuery:GetUInt32(0)
            knownSpellIds[sid] = true
            table.insert(rawKnownIds, sid)
        until not knownQuery:NextRow()
    end
    if #rawKnownIds > 0 then
        for offset = 1, #rawKnownIds, 500 do
            local chunk = {}
            for i = offset, math.min(offset + 499, #rawKnownIds) do
                table.insert(chunk, rawKnownIds[i])
            end
            local nameQ = WorldDBQuery("SELECT Name_Lang_enUS FROM dbc_spells WHERE Id IN (" .. table.concat(chunk, ",") .. ")")
            if nameQ then
                repeat
                    if not nameQ:IsNull(0) then
                        knownSpellNames[nameQ:GetString(0)] = true
                    end
                until not nameQ:NextRow()
            end
        end
    end

    -- Step 1b: Load drafted spells
    local draftedSpellIds = {}
    local rawDraftedIds = {}
    local draftedQuery = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. player:GetGUIDLow())
    if draftedQuery then
        repeat
            local sid = draftedQuery:GetUInt32(0)
            draftedSpellIds[sid] = true
            table.insert(rawDraftedIds, sid)
        until not draftedQuery:NextRow()
    end
    if #rawDraftedIds > 0 then
        for offset = 1, #rawDraftedIds, 500 do
            local chunk = {}
            for i = offset, math.min(offset + 499, #rawDraftedIds) do
                table.insert(chunk, rawDraftedIds[i])
            end
            local nameQ = WorldDBQuery("SELECT Name_Lang_enUS FROM dbc_spells WHERE Id IN (" .. table.concat(chunk, ",") .. ")")
            if nameQ then
                repeat
                    if not nameQ:IsNull(0) then
                        knownSpellNames[nameQ:GetString(0)] = true
                    end
                until not nameQ:NextRow()
            end
        end
    end

    local queryLevel = math.max(maxLevel, 20)
    -- Step 2: Query spells from DBC
    local query = WorldDBQuery([[
        SELECT s.Id, s.Effect_1, s.Effect_2, s.Effect_3,
               s.Description_Lang_enUS, s.SpellLevel, s.MaxLevel,
               s.DurationIndex, s.Category, s.Name_Lang_enUS, s.SpellIconID,
               s.Rarity
          FROM dbc_spells s
          JOIN dbc_skilllineability sla ON s.Id = sla.Spell
          JOIN dbc_skillline sl ON sla.SkillLine = sl.ID
            AND sl.CategoryID IN (6, 7, 8, 9, 11)
         WHERE s.SpellLevel <= ]] .. queryLevel .. [[
           AND (s.Attributes & 0x00000040) = 0
           AND s.Id NOT IN (
               SELECT spell_id FROM spell_ranks WHERE spell_id != first_spell_id
           )
    ]])

    if not query then

        return
    end

    -- Step 3: Filter & bucket by rarity
    local categorized = { [0]={}, [1]={}, [2]={}, [3]={}, [4]={}, [5]={} }
    local totalChecked, totalAccepted = 0, 0

    repeat
        totalChecked = totalChecked + 1

        local spellId = query:GetUInt32(0)
        local spellName = query:GetString(9)
        if not knownSpellIds[spellId] and not draftedSpellIds[spellId] and not knownSpellNames[spellName] then
            local rarity = query:GetUInt8(11)
            if (rarity ~= 5 or INCLUDE_RARITY_5) and (rarity >= 0 and rarity <= 5) then
                local spell = {
                    spellId = spellId,
                    effect1 = query:GetUInt32(1),
                    effect2 = query:GetUInt32(2),
                    effect3 = query:GetUInt32(3),
                    desc    = query:GetString(4),
                    name    = query:GetString(9),
                    iconId  = query:GetUInt32(10)
                }

                if not isBlacklistedSpellId(spellId)
                   and not talentChains[spellId] -- EXCLUDE TALENTS FROM NORMAL ACTIVE DRAFTS
                   and spell.desc ~= ''
                   and spell.name ~= ''
                   and spell.iconId > 1
                   and not bannedNames[spell.name]
                then
                    -- Prerequisite check: class-locked spells (e.g. DK rune-cost)
                    local classReq = CONFIG.CLASS_LOCKED_SPELLS[spellId]
                    if classReq and player:GetClass() ~= classReq then
                        -- Player's class doesn't match, skip this spell
                    -- Prerequisite check: requires a previously-drafted spell
                    elseif CONFIG.SPELL_PREREQUISITES[spellId] then
                        local prereq = CONFIG.SPELL_PREREQUISITES[spellId]
                        local satisfied = false
                        if type(prereq) == "table" then
                            for _, reqId in ipairs(prereq) do
                                if knownSpellIds[reqId] then
                                    satisfied = true
                                    break
                                end
                            end
                        else
                            satisfied = knownSpellIds[prereq] == true
                        end
                        if satisfied then
                            table.insert(categorized[rarity], spellId)
                            totalAccepted = totalAccepted + 1
                        end
                    else
                        table.insert(categorized[rarity], spellId)
                        totalAccepted = totalAccepted + 1
                    end
                end
            end
        end
    until not query:NextRow()


    -- Step 4: Shuffle buckets and pick N from each
    local draftedRarityCount = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0 }
    for rarity = 0, 4 do
        local bucket = categorized[rarity]
        for i = #bucket, 2, -1 do
            local j = math.random(i)
            bucket[i], bucket[j] = bucket[j], bucket[i]
        end
        local target = math.floor((RARITY_DISTRIBUTION[rarity] or 0) * POOL_AMOUNT)
        local added = 0
        for i = 1, #bucket do
            local id = bucket[i]
            if not knownSpellIds[id] then
                table.insert(pool, id)
                draftedRarityCount[rarity] = (draftedRarityCount[rarity] or 0) + 1
                added = added + 1
                if added >= target then break end
            end
        end
    end

    -- Optionally add Broken (5) spells last if allowed
    if INCLUDE_RARITY_5 then
        local bucket = categorized[5]
        for i = #bucket, 2, -1 do
            local j = math.random(i)
            bucket[i], bucket[j] = bucket[j], bucket[i]
        end
        for _, id in ipairs(bucket) do
            if #pool >= POOL_AMOUNT then break end
            table.insert(pool, id)
            draftedRarityCount[5] = (draftedRarityCount[5] or 0) + 1
        end
    end

end

-- Utility: check if table contains value
local function tableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end
-- Prevent players in Draft Mode from learning new spells (via trainer or other means)

local function OnLearnSpell(event, player, spellId)
    if IsBotPlayer(player) then return end
    local guid = player:GetGUIDLow()

    -- Allow GMs to learn spells for testing
    if player:IsGM() then
        return
    end

    -- If this LearnSpell was triggered by our draft system, allow it immediately:
    if draftingPlayers[guid] then
        return
    end

    -- Allow already drafted spells (prevents anti-cheat from deleting them on login/load)
    local dq = CharDBQuery("SELECT 1 FROM drafted_spells WHERE player_guid = " .. guid .. " AND spell_id = " .. spellId)
    if dq then
        return
    end

    --  Check if the player is in Draft Mode
    local res = CharDBQuery("SELECT draft_state FROM prestige_stats WHERE player_id = " .. guid)
    if res and res:GetUInt32(0) == 1 then
        -- Allow protected spells through
        if protectedSpellIds[spellId] then
            return
        end
        -- Allow any spell whose rarity is 99 (our “requires‑reagent” marker)
        do
            local rq = WorldDBQuery("SELECT rarity FROM dbc_spells WHERE Id = " .. spellId)
            if rq and rq:GetUInt32(0) == 99 then
                return
            end
        end
        -- Block all other spells
        player:SendBroadcastMessage("You cannot learn new spells while in Draft Mode.")

        --  Delay the removal slightly
        CreateLuaEvent(function()
            local p = GetPlayerByGUID(guid)
            if not p then return end

            p:RemoveSpell(spellId)
        end, 250, 1)

        -- Track it in justBlockedSpells
        justBlockedSpells[guid] = justBlockedSpells[guid] or {}
        justBlockedSpells[guid][spellId] = true
    end
end


local function UpgradeKnownSpells(player)
    local level = player:GetLevel()
    local upgraded = 0

    local visitedRoot = {}
    local knownSpells = player:GetSpells()  -- Returns an array of { spellId, … }

    for _, spellId in ipairs(knownSpells) do
        local rootQ = WorldDBQuery(
            "SELECT first_spell_id FROM spell_ranks WHERE spell_id = " .. spellId .. " LIMIT 1"
        )
        local firstSpellId = (rootQ and rootQ:GetUInt32(0)) or spellId

        if not visitedRoot[firstSpellId] then
            visitedRoot[firstSpellId] = true

            local rankQuery = WorldDBQuery([[
                SELECT sr.spell_id, ds.SpellLevel
                  FROM spell_ranks sr
                  JOIN dbc_spells ds ON sr.spell_id = ds.Id
                 WHERE sr.first_spell_id = ]] .. firstSpellId .. [[
                   ORDER BY ds.SpellLevel ASC
            ]])

            if rankQuery then
                repeat
                    local candidateId = rankQuery:GetUInt32(0)
                    local candidateLvl = rankQuery:GetUInt32(1)

                    if candidateLvl <= level and not player:HasSpell(candidateId) then
                        local guid = player:GetGUIDLow()
                        if not (justBlockedSpells[guid] and justBlockedSpells[guid][candidateId]) then
                            CharDBExecute(
                                "INSERT IGNORE INTO drafted_spells (player_guid, spell_id) VALUES (" .. guid .. ", " .. candidateId .. ")"
                            )

                            draftingPlayers[guid] = true
                            player:LearnSpell(candidateId)
                            player:CastSpell(player,24312,true)
                            player:RemoveAura(24312)
                            draftingPlayers[guid] = nil

                            upgraded = upgraded + 1
                        else
                            justBlockedSpells[guid][candidateId] = nil
                        end
                    end
                until not rankQuery:NextRow()
            end
        end
    end
end





-- Event: Player level-up
local function OnLevelUp(event, player, oldLevel)
    if IsBotPlayer(player) then return end
    -- 1) compute actual level gain
    local newLevel = player:GetLevel()
    local diff     = newLevel - oldLevel
    if diff <= 0 then
        return
    end

    local guid = player:GetGUIDLow()

    -- 2) block if player hasn't unlocked spell draft
    local stateQ = CharDBQuery(
        "SELECT draft_state FROM prestige_stats WHERE player_id = " .. guid
    )
    if not stateQ or stateQ:GetUInt32(0) < 1 then
        return
    end

    -- 3) Determine per-level reroll rate based on prestige level
    --    Prestige 0: 0 rerolls per level
    --    Prestige 1: PRESTIGE1_REROLLS_PER_LEVEL (1) per level
    --    Prestige 2+: +PRESTIGE_REROLL_SCALING (2) per prestige beyond 1
    local prestigeQ = CharDBQuery(
        "SELECT prestige_level, bonus_drafts FROM prestige_stats WHERE player_id = " .. guid
    )
    local prestigeLevel = 0
    local bonusDrafts = 0
    if prestigeQ then
        prestigeLevel = prestigeQ:GetUInt32(0)
        bonusDrafts = prestigeQ:GetUInt32(1)
    end

    local rerollsPerLevel
    if prestigeLevel <= 0 then
        rerollsPerLevel = CONFIG.REROLLS_PER_LEVELUP -- 0
    else
        rerollsPerLevel = CONFIG.PRESTIGE1_REROLLS_PER_LEVEL + CONFIG.PRESTIGE_REROLL_SCALING * (prestigeLevel - 1)
    end

    local rerollsToAdd = diff * rerollsPerLevel
    CharDBExecute(string.format([[
        INSERT INTO prestige_stats
          (player_id, draft_state, rerolls)
        VALUES
          (%d, 1, %d)
        ON DUPLICATE KEY UPDATE
          rerolls               = rerolls + %d;
    ]], guid,
       rerollsToAdd,
       rerollsToAdd
    ))

    -- 4) SNAP total_expected_drafts exactly based on class
    local expectedTarget = GetExpectedDraftsFormula(player:GetClass(), newLevel)
    local expectedTotal = expectedTarget + bonusDrafts
    CharDBExecute(string.format(
        "UPDATE prestige_stats SET total_expected_drafts = %d WHERE player_id = %d;",
        expectedTotal, guid
    ))

    -- 5) delay UI update by 250ms so DB writes can settle
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p or not p:IsInWorld() then return end

        -- send updated rerolls
        local rerollQ = CharDBQuery(
          "SELECT rerolls FROM prestige_stats WHERE player_id = " .. guid
        )
        if rerollQ then
            p:SendAddonMessage(
              "SpellChoiceRerolls",
              tostring(rerollQ:GetUInt32(0)),
              0, p
            )
        end

        -- send updated drafts remaining
        local draftQ = CharDBQuery(string.format([[
          SELECT successful_drafts, total_expected_drafts
          FROM prestige_stats
          WHERE player_id = %d
        ]], guid))
        if draftQ then
            local successful = draftQ:GetUInt32(0)
            local expected   = draftQ:GetUInt32(1)
            local remaining  = math.max(0, expected - successful)
            p:SendAddonMessage(
              "SpellChoiceDrafts",
              tostring(remaining),
              0, p
            )
        end
    end, 250, 1)

    -- 6) generate or resend spell choices
    local existing = LoadSpellsFromDB(guid)
    if not existing or existing[1] == 0 then
        -- generate new draft
        LoadValidSpellChoices(player, newLevel)

        local spells = GetRandomSpells(3, guid)
        currentDraftChoices[guid] = spells
        SaveSpellsToDB(guid, spells)

        SendDraftChoices(player, spells)
    else
        -- resend existing draft
        currentDraftChoices[guid] = existing
        SendDraftChoices(player, existing)
    end
end


-- Event: Player sends whisper to addon
local function OnAddonWhisper(event, player, msg, msgType, lang, receiver)
    if IsBotPlayer(player) then return end
    msg = msg:gsub("%s+$", "")

    -- Only process protocol whispers starting with "SC"
    if msg:sub(1, 2) ~= "SC" then return end

    local guid = player:GetGUIDLow()

    -- Rate limit: allow at most 5 SC_* messages per second per player (guid)
    local now = os.time()
    local limit = lastMsgTimes[guid]
    if not limit or limit.windowStart ~= now then
        lastMsgTimes[guid] = { count = 1, windowStart = now }
    else
        if limit.count >= 5 then
            -- Silent drop
            return false
        end
        limit.count = limit.count + 1
    end

    local buySpellId = tonumber(msg:match("^SC_BUY_TALENT:(%d+)"))
    if buySpellId then
        HandleBuyTalent(player, buySpellId)
        return false
    end

    -- Handle SC_CHECK (client re-checks prestige)    
    if msg == "SC_CHECK" then
        SyncDraftedTalents(player)
        CheckAndRestorePendingDraft(player)
        local result = CharDBQuery("SELECT draft_state, rerolls FROM prestige_stats WHERE player_id = " .. guid)
        if not result then
            local startDrafts = GetExpectedDraftsFormula(player:GetClass(), player:GetLevel())
            CharDBQuery(string.format([[
                INSERT IGNORE INTO prestige_stats 
                (player_id, prestige_level, draft_state, stored_class, total_expected_drafts, rerolls, bans) 
                VALUES (%d, 0, 1, %d, %d, %d, %d)
            ]], guid, player:GetClass(), startDrafts, CONFIG.DRAFT_MODE_REROLLS, CONFIG.DRAFT_BANS_START))
            result = CharDBQuery("SELECT draft_state, rerolls FROM prestige_stats WHERE player_id = " .. guid)
        end
        if result then
            local draftState = result:GetUInt32(0)
            local rerolls = result:GetUInt32(1)

            local status = draftState == 1 and "prestiged" or "not_prestiged"

            local drafts = CharDBQuery("SELECT total_expected_drafts FROM prestige_stats WHERE player_id = " .. player:GetGUIDLow())
            
            local playerGuid = player:GetGUIDLow()
            local query = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. playerGuid)
            local bansQ = CharDBQuery("SELECT bans FROM prestige_stats WHERE player_id = " .. guid)
            if bansQ then
              local bansRemaining = bansQ:GetUInt32(0)
              player:SendAddonMessage("SpellChoiceBansLeft", tostring(bansRemaining), 0, player)
            end
            if query then
                local totalExpected = query:GetUInt32(0)
                local successful = query:GetUInt32(1)
                local totalDrafts = totalExpected - successful
                if totalDrafts < 0 then totalDrafts = 0 end -- safety clamp
                player:SendAddonMessage("SpellChoiceDrafts", tostring(totalDrafts), 0, player)
            end
            player:SendAddonMessage("SpellChoiceStatus", status, 0, player)

            -- NEW: Send reroll count too
            player:SendAddonMessage("SpellChoiceRerolls", tostring(rerolls), 0, player)

            -- RESTORE DRAFT UI AFTER RELOAD: Send spell choices back
            if draftState == 1 then
                if not fullSpellPools[guid] or #fullSpellPools[guid] == 0 then
                    LoadValidSpellChoices(player, player:GetLevel())
                end
                if currentDraftChoices[guid] and #currentDraftChoices[guid] > 0 then
                    SendDraftChoices(player, currentDraftChoices[guid])
                else
                    local totalExpected = query and query:GetUInt32(0) or 0
                    local successful = query and query:GetUInt32(1) or 0
                    if successful < totalExpected then
                        local spells = LoadSpellsFromDB(guid)
                        if spells and spells[1] > 0 then
                            currentDraftChoices[guid] = spells
                            SendDraftChoices(player, spells)
                        elseif query then
                            if successful < totalExpected then
                                BeginDraftLoop(player, guid, rerolls, successful, totalExpected)
                            end
                        end
                    end
                end
            end
        end
        return false
    end
    if msg == "SC_REPLACE_BANNED" then
        local guid = player:GetGUIDLow()
        local current = LoadSpellsFromDB(guid)
        local replaced = false
        local bansQ = CharDBQuery("SELECT bans FROM prestige_stats WHERE player_id = " .. guid)
        if bansQ then
          local bansRemaining = bansQ:GetUInt32(0)
          player:SendAddonMessage("SpellChoiceBansLeft", tostring(bansRemaining), 0, player)
        end
        if current then
        LoadValidSpellChoices(player, player:GetLevel())

        local newChoices = {}
        local excludeSet = {}
        local bannedIDs = {}

        -- Phase 1: Collect all unbanned spells first
        for _, id in ipairs(current) do
            local isBanned = CharDBQuery("SELECT 1 FROM draft_bans WHERE player_id = " .. guid .. " AND spell_id = " .. id)
            if isBanned then
                table.insert(bannedIDs, id)
            else
                table.insert(newChoices, id)
                excludeSet[id] = true
            end
        end

        -- Optional: fetch all banned spells into a set for safety check
        local bannedSet = {}
        local banQ = CharDBQuery("SELECT spell_id FROM draft_bans WHERE player_id = " .. guid)
        if banQ then
            repeat
                bannedSet[banQ:GetUInt32(0)] = true
            until not banQ:NextRow()
        end

        local replaced = false

        -- Phase 2: Replace each banned spell
        for _, _ in ipairs(bannedIDs) do
            local newList = GetRandomSpells(1, guid, excludeSet)
            local new = newList and newList[1]
            if new and not bannedSet[new] then
                table.insert(newChoices, new)
                excludeSet[new] = true
                replaced = true
            end
        end


            currentDraftChoices[guid] = newChoices
            SaveSpellsToDB(guid, newChoices)

            SendDraftChoices(player, newChoices)

        end

        return false
    end

    -- Handle SC_REROLL
    if msg == "SC_REROLL" then
        if activeTalentDrafts[guid] then
            player:SendBroadcastMessage("You cannot reroll a Tome of Talents draft.")
            return false
        end
        local result = CharDBQuery("SELECT draft_state, rerolls FROM prestige_stats WHERE player_id = " .. guid)
        local updatedQ = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. guid)
        if updatedQ then
            local totalExpected = updatedQ:GetUInt32(0)
            local successful = updatedQ:GetUInt32(1)
            local remaining = math.max(0, totalExpected - successful)
            player:SendAddonMessage("SpellChoiceDrafts", tostring(remaining), 0, player)
        end
        if not result or result:GetUInt32(0) < 1 then
            player:SendBroadcastMessage("You are not prestiged.")
            return false
        end

        local rerolls = result:GetUInt32(1)
        if rerolls <= 0 then
            player:SendBroadcastMessage("No rerolls remaining.")
            return false
        end

        -- Reduce reroll count and update
        CharDBExecute("UPDATE prestige_stats SET rerolls = rerolls - 1 WHERE player_id = " .. guid)

        local spells = GetRandomSpells(3, guid)
        currentDraftChoices[guid] = spells
        SaveSpellsToDB(guid, spells)
        SendDraftChoices(player, spells)
        local rerolls = result:GetUInt32(1) - 1
        player:SendAddonMessage("SpellChoiceRerolls", tostring(rerolls), 0, player)
        return false
    end
    -- Handle SC_BAN:<spellId>
    local banSpellId = tonumber(msg:match("^SC_BAN:(%d+)"))
    if banSpellId then
        if activeTalentDrafts[guid] then
            player:SendBroadcastMessage("You cannot ban spells during a Tome of Talents draft.")
            return false
        end
        if not currentDraftChoices[guid] or not tableContains(currentDraftChoices[guid], banSpellId) then
            player:SendAddonMessage("SpellChoiceBanDenied", "invalid", 0, player)
            return false
        end
        local bansQ = CharDBQuery("SELECT bans FROM prestige_stats WHERE player_id = " .. guid)
        if not bansQ then return false end

        local bansLeft = bansQ:GetUInt32(0)

        if bansLeft <= 0 then
            player:SendAddonMessage("SpellChoiceBanDenied", "0", 0, player)
            return false
        end

        -- Subtract ban, insert ban into DB
        CharDBExecute("UPDATE prestige_stats SET bans = bans - 1 WHERE player_id = " .. guid)
        CharDBExecute("INSERT IGNORE INTO draft_bans (player_id, spell_id) VALUES (" .. guid .. ", " .. banSpellId .. ")")

        -- Remove from global pool
        local removed = false
        for i = #(fullSpellPools[guid] or {}), 1, -1 do
            if fullSpellPools[guid][i] == banSpellId then
                table.remove(fullSpellPools[guid], i)
                removed = true
                break
            end
        end

        -- Also remove from player's 3 draft picks (if they match)
        if currentDraftChoices[guid] then
            for i = #currentDraftChoices[guid], 1, -1 do
                if currentDraftChoices[guid][i] == banSpellId then
                    table.remove(currentDraftChoices[guid], i)
                    break
                end
            end
        end

        player:SendAddonMessage("SpellChoiceBanAccepted", tostring(banSpellId), 0, player)
        local updated = CharDBQuery("SELECT bans FROM prestige_stats WHERE player_id = " .. guid)
        if updated then
          local left = updated:GetUInt32(0)
          player:SendAddonMessage("SpellChoiceBansLeft", tostring(left), 0, player)
        end

        return false
    end


    local spellId = tonumber(msg:match("^SC:(%d+)"))
    if not spellId then return end

    local level = player:GetLevel()
    local result = CharDBQuery("SELECT draft_state, total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. guid)
    local draftState = result and result:GetUInt32(0) or 0
    local isPrestiged = draftState == 1
    local expected = result and result:GetUInt32(1) or 0
    local successful = result and result:GetUInt32(2) or 0

    if not isPrestiged then
        player:SendBroadcastMessage("You are not prestiged.")
        return false
    end

    if player:HasSpell(spellId) then
        player:SendBroadcastMessage("You already know that spell. Rerolling...")

        local spells = GetRandomSpells(3, guid)
        currentDraftChoices[guid] = spells
        SendDraftChoices(player, spells)
        return false
    end

    local validChoices = currentDraftChoices[guid]
    if not validChoices or not tableContains(validChoices, spellId) then
        player:SendBroadcastMessage("Invalid spell selection.")
        return false
    end

    if activeTalentDrafts[guid] then
        draftingPlayers[guid] = true
        player:LearnSpell(spellId)
        draftingPlayers[guid] = nil
        activeTalentDrafts[guid] = nil
        player:CastSpell(player, 24312, true)
        player:RemoveAura(24312)
        
        -- Persist the talent in drafted_spells
        CharDBExecute("INSERT IGNORE INTO drafted_spells (player_guid, spell_id) VALUES (" .. guid .. ", " .. spellId .. ")")
        SyncDraftedTalents(player, spellId)
        
        -- If this is part of a talent chain, unlearn/delete previous ranks!
        local chainInfo = talentChains[spellId]
        if chainInfo then
            for rIndex = 1, chainInfo.rankIndex - 1 do
                local prevSpellId = chainInfo.ranks[rIndex]
                player:RemoveSpell(prevSpellId)
                CharDBExecute("DELETE FROM character_spell WHERE guid = " .. guid .. " AND spell = " .. prevSpellId)
                CharDBExecute("DELETE FROM drafted_spells WHERE player_guid = " .. guid .. " AND spell_id = " .. prevSpellId)
            end
        end
        
        -- Clear offered spells in DB
        CharDBExecute("UPDATE prestige_stats SET offered_spell_1 = 0, offered_spell_2 = 0, offered_spell_3 = 0 WHERE player_id = " .. guid)
        currentDraftChoices[guid] = nil
        
        -- Upgrade talent to level rank
        UpgradeKnownSpells(player)
        
        player:SendBroadcastMessage("|cff00ff00You have successfully drafted your talent!|r")
        player:SendAddonMessage("SpellChoiceClose", "", 0, player)
        return false
    end

    -- Increment successful drafts locally
    local newSuccessful = successful + 1
    CharDBExecute("UPDATE prestige_stats SET successful_drafts = " .. newSuccessful .. " WHERE player_id = " .. guid)
    local remaining = math.max(0, expected - newSuccessful)
    player:SendAddonMessage("SpellChoiceDrafts", tostring(remaining), 0, player)
    draftingPlayers[guid] = true
    player:LearnSpell(spellId)
    player:CastSpell(player,24312,true)
    player:RemoveAura(24312)

    -- Auto-grant Shaman totems if player drafts a totem spell
    local nameQuery = WorldDBQuery("SELECT Name_Lang_enUS FROM dbc_spells WHERE ID = " .. spellId)
    if nameQuery then
        local spellName = nameQuery:GetString(0)
        if string.find(spellName, "Totem") or string.find(spellName, "Call of the") then
            local totems = {5175, 5176, 5177, 5178}
            for _, itemId in ipairs(totems) do
                if not player:HasItem(itemId) then
                    player:AddItem(itemId, 1)
                end
            end
        end
    end

    -- Additional spell groups
    if spellId == 1515 then
        local extraSpells = {883, 2641, 6991, 982, 136}
        for _, sid in ipairs(extraSpells) do
            player:LearnSpell(sid)
            player:CastSpell(player,24312,true)
            player:RemoveAura(24312)
        end
    elseif spellId == 47241 then
        local extraSpells = {50581, 59671, 54785, 50589}
        for _, sid in ipairs(extraSpells) do
            player:LearnSpell(sid)
            player:CastSpell(player,24312,true)
            player:RemoveAura(24312)
        end
    elseif spellId == 9634 or spellId == 5487 then -- Bear Form / Dire Bear Form Starter Kit
        local extraSpells = {6807, 6795, 99} -- Maul, Growl, Demoralizing Roar (1062 is Entangling Roots R2, not Demo Roar!)
        for _, sid in ipairs(extraSpells) do
            player:LearnSpell(sid)
            player:CastSpell(player,24312,true)
            player:RemoveAura(24312)
        end
    elseif spellId == 768 then -- Cat Form Starter Kit
        local extraSpells = {1082, 5215} -- Claw, Prowl
        for _, sid in ipairs(extraSpells) do
            player:LearnSpell(sid)
            player:CastSpell(player,24312,true)
            player:RemoveAura(24312)
        end
    elseif spellId == 1784 then -- Rogue Stealth Starter Kit
        local extraSpells = {921, 11297} -- Pick Pocket, Sap
        for _, sid in ipairs(extraSpells) do
            player:LearnSpell(sid)
            player:CastSpell(player,24312,true)
            player:RemoveAura(24312)
        end
    elseif spellId == 2457 then -- Battle Stance Starter Kit
        player:LearnSpell(100) -- Charge
        player:CastSpell(player,24312,true)
        player:RemoveAura(24312)
    elseif spellId == 71 then -- Defensive Stance Starter Kit
        player:LearnSpell(355) -- Taunt
        player:CastSpell(player,24312,true)
        player:RemoveAura(24312)
    elseif spellId == 2458 then -- Berserker Stance Starter Kit
        player:LearnSpell(6552) -- Pummel
        player:CastSpell(player,24312,true)
        player:RemoveAura(24312)
    end
    draftingPlayers[guid] = nil
    for i = #(fullSpellPools[guid] or {}), 1, -1 do
        if fullSpellPools[guid][i] == spellId then
            table.remove(fullSpellPools[guid], i)
            break
        end
    end
    CharDBExecute(string.format([[
        UPDATE prestige_stats
        SET offered_spell_1 = 0, offered_spell_2 = 0, offered_spell_3 = 0
        WHERE player_id = %d
    ]], guid))
    CharDBExecute("INSERT IGNORE INTO drafted_spells (player_guid, spell_id) VALUES (" .. guid .. ", " .. spellId .. ")")
    UpgradeKnownSpells(player)

    currentDraftChoices[guid] = nil
    player:SendAddonMessage("SpellChoiceClose", "", 0, player)

    -- Check for additional pending drafts using local counters
    if newSuccessful < expected then
        LoadValidSpellChoices(player, player:GetLevel())
        local spells = GetRandomSpells(3, guid)
        currentDraftChoices[guid] = spells
        SaveSpellsToDB(guid, spells) 
        SendDraftChoices(player, spells)
    end

    return false
end


BeginDraftLoop = function(player, guid, rerolls, successful, expected)
    if not player or not player:IsInWorld() then return end
    if successful >= expected then return end

    -- Send status and rerolls again, just to be safe

    local playerGuid = player:GetGUIDLow()
    local query = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. playerGuid)
    if query then
        local totalExpected = query:GetUInt32(0)
        local successful = query:GetUInt32(1)
        local totalDrafts = totalExpected - successful
        if totalDrafts < 0 then totalDrafts = 0 end -- safety clamp
        player:SendAddonMessage("SpellChoiceDrafts", tostring(totalDrafts), 0, player)
    end

    player:SendAddonMessage("SpellChoiceStatus", "prestiged", 0, player)
    player:SendAddonMessage("SpellChoiceRerolls", tostring(rerolls), 0, player)

    -- First spell roll
    -- Load from DB or generate if missing
    local spells = LoadSpellsFromDB(guid)
    if not spells or spells[1] == 0 then
        spells = GetRandomSpells(3, guid)
        SaveSpellsToDB(guid, spells)
    end
    currentDraftChoices[guid] = spells
    SaveSpellsToDB(guid, spells) 
    SendDraftChoices(player, spells)
end

SyncDraftedTalents = function(player, extraSpellId)
    local guid = player:GetGUIDLow()
    local query = CharDBQuery(string.format([[
        SELECT spell_id FROM drafted_spells WHERE player_guid = %d
        UNION
        SELECT spell_id FROM manually_acquired_talents WHERE player_guid = %d
    ]], guid, guid))

    local excludeSpells = {}
    if extraSpellId then
        local chainInfo = talentChains[extraSpellId]
        if chainInfo then
            for rIndex = 1, chainInfo.rankIndex - 1 do
                excludeSpells[chainInfo.ranks[rIndex]] = true
            end
        end
    end

    local candidateSpells = {}
    local seen = {}
    if query then
        repeat
            local spellId = query:GetUInt32(0)
            seen[spellId] = true
            if not excludeSpells[spellId] then
                table.insert(candidateSpells, spellId)
            end
        until not query:NextRow()
    end

    local talents = {}
    local seenTalent = {}
    for _, id in ipairs(candidateSpells) do
        if talentChains[id] and not seenTalent[id] then
            table.insert(talents, id)
            seenTalent[id] = true
        end
    end

    if extraSpellId and not seen[extraSpellId] and not seenTalent[extraSpellId] then
        table.insert(talents, extraSpellId)
    end

    local data = table.concat(talents, ",")
    player:SendAddonMessage("SpellChoiceTalents", data, 0, player)
end


-- Player login hook
local function OnLogin(event, player)
    if IsBotPlayer(player) then return end
    -- REQUIRED for the addon protocol: the client sends SC_* commands as whispers to
    -- the player's own name. With acceptWhispers off (the default for new characters),
    -- the core rejects them with "No player named X is currently playing".
    player:SetAcceptWhispers(true)
    CONFIG.EnsurePlayerLanguage(player)
    SyncDraftedTalents(player)
    SyncTalentPoints(player)
    local guid = player:GetGUIDLow()

    -- Self-healing: restore any drafted spells that might have been accidentally removed/lost
    local draftedQ = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid)
    if draftedQ then
        SpellDraft_SetSystemLearning(guid, true)
        repeat
            local spellId = draftedQ:GetUInt32(0)
            if not player:HasSpell(spellId) then
                player:LearnSpell(spellId)
            end
        until not draftedQ:NextRow()
        SpellDraft_SetSystemLearning(guid, false)
    end

    local playerGuid = player:GetGUIDLow()


    local query = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. playerGuid)
    if query then
        local totalExpected = query:GetUInt32(0)
        local successful = query:GetUInt32(1)

        local totalDrafts = totalExpected - successful
        if totalDrafts < 0 then totalDrafts = 0 end

        player:SendAddonMessage("SpellChoiceDrafts", tostring(totalDrafts), 0, player)
    else

    end

    local result = CharDBQuery("SELECT draft_state, rerolls, successful_drafts, total_expected_drafts FROM prestige_stats WHERE player_id = " .. guid)

    if not result then
    local playerGuid = player:GetGUIDLow()
    local query = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. playerGuid)
    if query then
        local totalExpected = query:GetUInt32(0)
        local successful = query:GetUInt32(1)
        local totalDrafts = totalExpected - successful
        if totalDrafts < 0 then totalDrafts = 0 end -- safety clamp
        player:SendAddonMessage("SpellChoiceDrafts", tostring(totalDrafts), 0, player)
    end

        player:SendAddonMessage("SpellChoiceStatus", "not_prestiged", 0, player)
        player:SendAddonMessage("SpellChoiceRerolls", "0", 0, player)
        return
    end

    local draft = result:GetUInt32(0)
    local rerolls = result:GetUInt32(1)
    local successful = result:GetUInt32(2)
    local expected = result:GetUInt32(3)

    if draft == 1 then
        if not CheckAndRestorePendingDraft(player) then
            --Ensure spell list is loaded
            if not fullSpellPools[guid] or #fullSpellPools[guid] == 0 then
                LoadValidSpellChoices(player, player:GetLevel())-- or 80 if you want full list
            end

            -- Start draft loop
            BeginDraftLoop(player, guid, rerolls, successful, expected)
        end
    else
    -- Send current bans
    local bansQ = CharDBQuery("SELECT spell_id FROM draft_bans WHERE player_id = " .. guid)
    if bansQ then
        local banned = {}
        repeat
            table.insert(banned, bansQ:GetUInt32(0))
        until not bansQ:NextRow()

        if #banned > 0 then
            local data = table.concat(banned, ",")
            player:SendAddonMessage("SpellChoiceBans", data, 0, player)

        end
    end
    local playerGuid = player:GetGUIDLow()
    local query = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. playerGuid)
    if query then
        local totalExpected = query:GetUInt32(0)
        local successful = query:GetUInt32(1)
        local totalDrafts = totalExpected - successful
        if totalDrafts < 0 then totalDrafts = 0 end -- safety clamp
        player:SendAddonMessage("SpellChoiceDrafts", tostring(totalDrafts), 0, player)
    end

        player:SendAddonMessage("SpellChoiceStatus", "not_prestiged", 0, player)
        player:SendAddonMessage("SpellChoiceRerolls", "0", 0, player)
    end
end

local lastZoneDraft = {}

local function OnZoneChanged(event, player, newZone, newArea)
    if IsBotPlayer(player) then return end
    local guid = player:GetGUIDLow()
    if CheckAndRestorePendingDraft(player) then
        return
    end
    if currentDraftChoices[guid] and #currentDraftChoices[guid] == 3 then
      return
    end
    local now = os.time()
    if lastSpellChoiceSent[guid] and now - lastSpellChoiceSent[guid] < 10 then
        return
    end
    lastSpellChoiceSent[guid] = now

    local result = CharDBQuery("SELECT draft_state, successful_drafts, total_expected_drafts FROM prestige_stats WHERE player_id = " .. guid)
    if not result then return end

    local draftState = result:GetUInt8(0)
    if draftState ~= 1 then return end --not in draft mode, bail out

    local successful = result:GetUInt32(1)
    local expected = result:GetUInt32(2)

    if successful < expected then
        local now = os.time()
        if lastZoneDraft[guid] and now - lastZoneDraft[guid] < 5 then
            return
        end
        lastZoneDraft[guid] = now

        CreateLuaEvent(function()
            local p = GetPlayerByGUID(guid)
            if not p or not p:IsInWorld() then return end

            if not fullSpellPools[guid] or not currentDraftChoices[guid] then
                LoadValidSpellChoices(p, p:GetLevel())
            end

            local spells = currentDraftChoices[guid]
            if not spells or #spells ~= 3 then
                spells = LoadSpellsFromDB(guid)
                if not spells or spells[1] == 0 then
                    spells = GetRandomSpells(3, guid)
                    SaveSpellsToDB(guid, spells)
                end
                currentDraftChoices[guid] = spells
                SaveSpellsToDB(guid, spells)
            end

            SendDraftChoices(p, spells)
        end, 2000, 1)
    end
end








local function OnPlayerLogout(event, player)
    local guid = player:GetGUIDLow()
    justBlockedSpells[guid] = nil
    fullSpellPools[guid] = nil
    currentDraftChoices[guid] = nil
    lastSpellChoiceSent[guid] = nil
    lastZoneDraft[guid] = nil
    lastMsgTimes[guid] = nil
end

-- Register events
RegisterPlayerEvent(44, OnLearnSpell) -- EVENT_ON_LEARN_SPELL
RegisterPlayerEvent(13, OnLevelUp)       -- PLAYER_LEVEL_CHANGED
RegisterPlayerEvent(19, OnAddonWhisper) -- ON_WHISPER
RegisterPlayerEvent(3, OnLogin)
RegisterPlayerEvent(27, OnZoneChanged) -- EVENT_ON_UPDATE_ZONE
RegisterPlayerEvent(4, OnPlayerLogout) -- PLAYER_EVENT_ON_LOGOUT


-- ==========================================
-- DRAFT & REROLL CONSUMABLE ITEMS (PHASE 1)
-- ==========================================

-- Helper to check if player is in draft mode
local function IsPlayerPrestiged(player)
    if IsBotPlayer(player) then return false end
    local guid = player:GetGUIDLow()
    local q = CharDBQuery("SELECT draft_state FROM prestige_stats WHERE player_id = " .. guid)
    return q and q:GetUInt32(0) == 1
end

-- Scroll of Rerolls (4427)
RegisterItemEvent(4427, 2, function(event, player, item, target)
    if not IsPlayerPrestiged(player) then
        player:SendBroadcastMessage("You must be in Classless Draft Mode to use this scroll.")
        return false -- prevents default consumption/spell
    end
    if player:IsInCombat() then
        player:SendBroadcastMessage("You cannot use this scroll in combat.")
        return false
    end

    local guid = player:GetGUIDLow()
    
    -- Manually consume 1 scroll
    player:RemoveItem(4427, 1)
    
    CharDBExecute("UPDATE prestige_stats SET rerolls = rerolls + 1 WHERE player_id = " .. guid)
    
    -- Fetch new total and notify client
    local q = CharDBQuery("SELECT rerolls FROM prestige_stats WHERE player_id = " .. guid)
    if q then
        player:SendAddonMessage("SpellChoiceRerolls", tostring(q:GetUInt32(0)), 0, player)
    end
    
    player:SendBroadcastMessage("|cff00ff00Scroll of Reroll consumed. Gained +1 Draft Reroll!|r")
    player:CastSpell(player, 14752, true)
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p then p:RemoveAura(14752) end
    end, 100, 1)
    
    return false -- prevent default spell cast/consumption
end)

-- Scroll of Bans (1078)
RegisterItemEvent(1078, 2, function(event, player, item, target)
    if not IsPlayerPrestiged(player) then
        player:SendBroadcastMessage("You must be in Classless Draft Mode to use this scroll.")
        return false
    end
    if player:IsInCombat() then
        player:SendBroadcastMessage("You cannot use this scroll in combat.")
        return false
    end

    local guid = player:GetGUIDLow()
    
    -- Manually consume 1 scroll
    player:RemoveItem(1078, 1)
    
    CharDBExecute("UPDATE prestige_stats SET bans = bans + 1 WHERE player_id = " .. guid)
    
    -- Fetch new total and notify client
    local q = CharDBQuery("SELECT bans FROM prestige_stats WHERE player_id = " .. guid)
    if q then
        player:SendAddonMessage("SpellChoiceBansLeft", tostring(q:GetUInt32(0)), 0, player)
    end
    
    player:SendBroadcastMessage("|cff00ff00Scroll of Ban consumed. Gained +1 Draft Ban!|r")
    player:CastSpell(player, 14752, true)
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p then p:RemoveAura(14752) end
    end, 100, 1)
    
    return false
end)

-- Lost Grimoire (13149)
RegisterItemEvent(13149, 2, function(event, player, item, target)
    if not IsPlayerPrestiged(player) then
        player:SendBroadcastMessage("You must be in Classless Draft Mode to use this grimoire.")
        return false
    end
    if player:IsInCombat() then
        player:SendBroadcastMessage("You cannot use this grimoire in combat.")
        return false
    end

    local guid = player:GetGUIDLow()
    -- Check if player already has an active draft open in client/DB
    local draftCheck = CharDBQuery("SELECT offered_spell_1 FROM prestige_stats WHERE player_id = " .. guid)
    if draftCheck and draftCheck:GetUInt32(0) > 0 then
        player:SendBroadcastMessage("You already have a pending draft choice. Please complete it first.")
        return false
    end

    -- Manually consume 1 grimoire
    player:RemoveItem(13149, 1)

    -- Trigger a bonus draft: increment bonus_drafts by 1 and recompute total_expected_drafts
    local bonusDrafts = 0
    local qBonus = CharDBQuery("SELECT bonus_drafts FROM prestige_stats WHERE player_id = " .. guid)
    if qBonus then
        bonusDrafts = qBonus:GetUInt32(0)
    end
    bonusDrafts = bonusDrafts + 1

    local level = player:GetLevel()
    local expectedTarget
    if player:GetClass() == 6 then
        expectedTarget = math.max(5, 5 + (level - 55) * 3)
    else
        expectedTarget = DRAFT_MODE_SPELLS + (level - 1)
    end
    local expectedTotal = expectedTarget + bonusDrafts

    CharDBExecute(string.format(
        "UPDATE prestige_stats SET bonus_drafts = %d, total_expected_drafts = %d WHERE player_id = %d",
        bonusDrafts, expectedTotal, guid
    ))
    
    -- Load valid choices and roll
    LoadValidSpellChoices(player, player:GetLevel())
    local spells = GetRandomSpells(3, guid)
    currentDraftChoices[guid] = spells
    SaveSpellsToDB(guid, spells)
    
    -- Update client stats and open draft UI
    player:SendAddonMessage("SpellChoiceStatus", "prestiged", 0, player)
    
    local q = CharDBQuery("SELECT total_expected_drafts, successful_drafts FROM prestige_stats WHERE player_id = " .. guid)
    if q then
        local expected = q:GetUInt32(0)
        local successful = q:GetUInt32(1)
        local remaining = math.max(0, expected - successful)
        player:SendAddonMessage("SpellChoiceDrafts", tostring(remaining), 0, player)
    end
    
    SendDraftChoices(player, spells)
    
    player:SendBroadcastMessage("|cff00ff00Lost Grimoire consumed. A bonus draft has opened!|r")
    player:CastSpell(player, 14752, true)
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p then p:RemoveAura(14752) end
    end, 100, 1)
    
    return false
end)


-- Tome of Talents (25462)
RegisterItemEvent(25462, 2, function(event, player, item, target)
    if not IsPlayerPrestiged(player) then
        player:SendBroadcastMessage("You must be in Classless Draft Mode to use this tome.")
        return false
    end
    if player:IsInCombat() then
        player:SendBroadcastMessage("You cannot use this tome in combat.")
        return false
    end

    local guid = player:GetGUIDLow()
    -- Check if player already has an active draft open in client/DB
    local draftCheck = CharDBQuery("SELECT offered_spell_1 FROM prestige_stats WHERE player_id = " .. guid)
    if draftCheck and draftCheck:GetUInt32(0) > 0 then
        player:SendBroadcastMessage("You already have a pending draft choice. Please complete it first.")
        return false
    end

    -- Roll 3 random passive talent spells with progressive rank upgrades
    local level = player:GetLevel()
    local eligiblePool = GetEligibleTalentsPool(player, level)
    if #eligiblePool == 0 then
        player:SendBroadcastMessage("No passive talents available for your level.")
        return false
    end

    -- Query rarities for all eligible pool spells
    local raritiesMap = {}
    for offset = 1, #eligiblePool, 500 do
        local chunk = {}
        for i = offset, math.min(offset + 499, #eligiblePool) do
            table.insert(chunk, eligiblePool[i])
        end
        local q = WorldDBQuery("SELECT Id, Rarity FROM dbc_spells WHERE Id IN (" .. table.concat(chunk, ",") .. ")")
        if q then
            repeat
                raritiesMap[q:GetUInt32(0)] = q:GetUInt8(1)
            until not q:NextRow()
        end
    end

    -- Group the eligible pool by rarity
    local categorized = { [0]={}, [1]={}, [2]={}, [3]={}, [4]={} }
    for _, id in ipairs(eligiblePool) do
        local rarity = raritiesMap[id] or 0
        if categorized[rarity] then
            table.insert(categorized[rarity], id)
        end
    end

    local function RollRarity()
        local r = math.random()
        if r < 0.50 then return 0
        elseif r < 0.77 then return 1
        elseif r < 0.91 then return 2
        elseif r < 0.97 then return 3
        else return 4 end
    end

    local spells = {}
    for roll = 1, 3 do
        local targetRarity = RollRarity()
        local chosenRarity = nil
        
        if #categorized[targetRarity] > 0 then
            chosenRarity = targetRarity
        else
            -- Fallback: find any non-empty bucket starting from common
            for r = 0, 4 do
                if #categorized[r] > 0 then
                    chosenRarity = r
                    break
                end
            end
        end

        if chosenRarity then
            local bucket = categorized[chosenRarity]
            local idx = math.random(#bucket)
            table.insert(spells, bucket[idx])
            table.remove(bucket, idx) -- Prevent duplicates in the same draft roll
        end
    end

    if #spells == 0 then
        player:SendBroadcastMessage("No passive talents available for your level.")
        return false
    end

    -- Manually consume 1 tome
    player:RemoveItem(25462, 1)

    activeTalentDrafts[guid] = true
    currentDraftChoices[guid] = spells
    SaveSpellsToDB(guid, spells)

    player:SendAddonMessage("SpellChoiceStatus", "prestiged", 0, player)
    
    SendDraftChoices(player, spells)
    
    player:SendBroadcastMessage("|cff00ff00Tome of Talents consumed. A passive talent draft has opened!|r")
    player:CastSpell(player, 14752, true)
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p then p:RemoveAura(14752) end
    end, 100, 1)

    return false
end)


-- Execute talent chains loader
LoadTalentChains()

RegisterPlayerEvent(18, function(event, player, msg, type, lang)
    if msg == ".testpool" then
        local level = player:GetLevel()
        local pool = GetEligibleTalentsPool(player, level)
        player:SendBroadcastMessage("Eligible talents pool size: " .. #pool)
        
        local passives = 0
        local actives = 0
        
        for _, spellId in ipairs(pool) do
            local q = WorldDBQuery("SELECT Id FROM dbc_spells WHERE Id = " .. spellId)
            if q then
                actives = actives + 1
            else
                passives = passives + 1
            end
        end
        player:SendBroadcastMessage("Actives (in dbc_spells): " .. actives)
        player:SendBroadcastMessage("Passives (missing from dbc_spells): " .. passives)
        
        local passList = {}
        local actList = {}
        for _, spellId in ipairs(pool) do
            local name = GetSpellInfo(spellId) or ("Spell " .. spellId)
            local q = WorldDBQuery("SELECT Id FROM dbc_spells WHERE Id = " .. spellId)
            if q then
                if #actList < 10 then
                    table.insert(actList, name .. " (" .. spellId .. ")")
                end
            else
                if #passList < 10 then
                    table.insert(passList, name .. " (" .. spellId .. ")")
                end
            end
        end
        
        player:SendBroadcastMessage("Sample Actives:")
        for _, s in ipairs(actList) do
            player:SendBroadcastMessage("  - " .. s)
        end
        player:SendBroadcastMessage("Sample Passives:")
        for _, s in ipairs(passList) do
            player:SendBroadcastMessage("  - " .. s)
        end
        
        return false
    end
end)

function SyncTalentPoints(player)
    local guid = player:GetGUIDLow()
    local q = CharDBQuery("SELECT talent_points FROM prestige_stats WHERE player_id = " .. guid)
    if q then
        player:SendAddonMessage("SpellChoiceTalentPoints", tostring(q:GetUInt32(0)), 0, player)
    else
        player:SendAddonMessage("SpellChoiceTalentPoints", "0", 0, player)
    end
end

-- Resolve a spell's display name across mod-ale variants (GetSpellInfo returns
-- a SpellInfo object on this core, not a name string)
local function GetSpellNameSafe(spellId)
    if type(GetSpellName) == "function" then
        local ok, name = pcall(GetSpellName, spellId)
        if ok and type(name) == "string" then return name end
    end
    if type(GetSpellInfo) == "function" then
        local ok, info = pcall(GetSpellInfo, spellId)
        if ok then
            if type(info) == "string" then return info end
            if info and info.GetName then
                local ok2, name = pcall(info.GetName, info)
                if ok2 and type(name) == "string" then return name end
            end
        end
    end
    return "Spell " .. tostring(spellId)
end

-- Draft-state check (each Eluna file is its own chunk; core's helper is file-local)
local function IsPlayerInDraft(player)
    local query = CharDBQuery("SELECT draft_state FROM prestige_stats WHERE player_id = " .. player:GetGUIDLow())
    return (query and query:GetUInt32(0) == 1) or false
end

local function MeetsPrerequisites(player, chain)
    -- 1. Check Level requirement based on Shifted Tier Gating (A.1)
    local level = player:GetLevel()
    local reqLevel = 1
    if chain.tierId > 0 then
        reqLevel = chain.tierId * 5
    end
    if level < reqLevel then
        return false, "Requires level " .. reqLevel
    end
    
    -- 2. Check parent prerequisites
    for _, pre in ipairs(chain.prereqs) do
        local parentChain = talentIdToChain[pre.prereqTalentId]
        if parentChain then
            local parentRank = 0
            for rankIndex, spellId in ipairs(parentChain.ranks) do
                if player:HasSpell(spellId) then
                    parentRank = rankIndex
                end
            end
            if parentRank < pre.reqRank then
                local parentSpellName = GetSpellNameSafe(parentChain.ranks[1])
                return false, "Requires " .. pre.reqRank .. " ranks in " .. parentSpellName
            end
        end
    end
    
    return true
end

-- Global: referenced by OnAddonWhisper, which is compiled earlier in this file
function HandleBuyTalent(player, spellId)
    local guid = player:GetGUIDLow()
    if not IsPlayerInDraft(player) then
        player:SendBroadcastMessage("You are not in Draft Mode.")
        return
    end
    if player:IsInCombat() then
        player:SendBroadcastMessage("You cannot purchase talents in combat.")
        return
    end

    -- 1. Verify player has talent points
    local qPoints = CharDBQuery("SELECT talent_points FROM prestige_stats WHERE player_id = " .. guid)
    if not qPoints or qPoints:GetUInt32(0) <= 0 then
        player:SendBroadcastMessage("You have no custom Talent Points to spend.")
        return
    end
    local currentPoints = qPoints:GetUInt32(0)

    -- 2. Verify the spell is a valid talent and find its chain info
    local chainInfo = talentChains[spellId]
    if not chainInfo then
        player:SendBroadcastMessage("Invalid talent spell.")
        return
    end
    
    -- 3. Check if the talent is locked (active/playstyle)
    if LOCKED_TALENTS[spellId] or LOCKED_TALENTS[chainInfo.ranks[1]] then
        player:SendBroadcastMessage("This talent is locked and can only be acquired from a Tome of Talents.")
        return
    end

    -- 4. Get player's current rank of this talent
    local currentRankIndex = 0
    for rankIndex, rSpellId in ipairs(chainInfo.ranks) do
        if player:HasSpell(rSpellId) then
            currentRankIndex = rankIndex
        end
    end

    if currentRankIndex >= #chainInfo.ranks then
        player:SendBroadcastMessage("You have already mastered this talent.")
        return
    end

    -- 5. Check prerequisites
    local allowed, errMsg = MeetsPrerequisites(player, chainInfo.chain)
    if not allowed then
        player:SendBroadcastMessage("|cffff0000Cannot learn: " .. errMsg .. "|r")
        return
    end

    local nextRankIndex = currentRankIndex + 1
    local nextSpellId = chainInfo.ranks[nextRankIndex]

    -- 6. Deduct talent point and insert/update manually_acquired_talents.
    -- CharDBQuery is synchronous, so the SyncTalentPoints read below can't race it.
    CharDBQuery("UPDATE prestige_stats SET talent_points = talent_points - 1 WHERE player_id = " .. guid)
    
    if currentRankIndex > 0 then
        local prevSpellId = chainInfo.ranks[currentRankIndex]
        CharDBExecute(string.format("DELETE FROM manually_acquired_talents WHERE player_guid = %d AND spell_id = %d", guid, prevSpellId))
        
        draftingPlayers[guid] = true
        player:RemoveSpell(prevSpellId)
        draftingPlayers[guid] = nil
        CharDBExecute(string.format("DELETE FROM character_spell WHERE guid = %d AND spell = %d", guid, prevSpellId))
    end

    CharDBExecute(string.format("INSERT INTO manually_acquired_talents (player_guid, spell_id) VALUES (%d, %d)", guid, nextSpellId))
    
    -- Teach next rank to player
    draftingPlayers[guid] = true
    player:LearnSpell(nextSpellId)
    draftingPlayers[guid] = nil

    player:CastSpell(player, 24312, true)
    player:RemoveAura(24312)

    -- Sync stats and talents to client
    SyncTalentPoints(player)
    SyncDraftedTalents(player, nextSpellId)
    
    player:SendBroadcastMessage(string.format("|cff00ff00Learned %s (Rank %d)|r", GetSpellNameSafe(nextSpellId), nextRankIndex))
end

function ResetCustomTalents(player)
    local guid = player:GetGUIDLow()
    local q = CharDBQuery("SELECT spell_id FROM manually_acquired_talents WHERE player_guid = " .. guid)
    local refund_points = 0
    local manual_spells = {}
    
    if q then
        repeat
            table.insert(manual_spells, q:GetUInt32(0))
        until not q:NextRow()
    end
    
    -- Disable anti-cheat while we modify spells
    if type(SpellDraft_SetSystemLearning) == "function" then
        SpellDraft_SetSystemLearning(guid, true)
    end

    -- Clear native talent state FIRST: ResetTalents can strip known talent spells,
    -- so it must run before any drafted ranks are restored below.
    player:ResetTalents(true)
    player:SetFreeTalentPoints(0)

    for _, spellId in ipairs(manual_spells) do
        local chainInfo = talentChains[spellId]
        if chainInfo then
            local R_purchased = chainInfo.rankIndex

            -- Find if player drafted a rank in this chain
            local R_drafted = 0
            for rankIndex, rSpellId in ipairs(chainInfo.ranks) do
                local qD = CharDBQuery(string.format("SELECT 1 FROM drafted_spells WHERE player_guid = %d AND spell_id = %d", guid, rSpellId))
                if qD then
                    R_drafted = rankIndex
                end
            end

            local spent = R_purchased - R_drafted
            if spent > 0 then
                refund_points = refund_points + spent
            end

            -- Remove current manual spell
            draftingPlayers[guid] = true
            player:RemoveSpell(spellId)
            draftingPlayers[guid] = nil
            CharDBExecute(string.format("DELETE FROM character_spell WHERE guid = %d AND spell = %d", guid, spellId))
        end
    end

    -- Wipe manual talents table
    CharDBExecute("DELETE FROM manually_acquired_talents WHERE player_guid = " .. guid)

    -- Update talent points in DB (synchronous so the sync below reads fresh)
    CharDBQuery("UPDATE prestige_stats SET talent_points = talent_points + " .. refund_points .. " WHERE player_id = " .. guid)

    -- Restore every drafted spell the player is missing (drafted ranks that were
    -- superseded by purchases, plus anything ResetTalents stripped). Mirrors the
    -- on-login self-heal so draft rewards always survive the reset.
    local qDrafted = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid)
    if qDrafted then
        repeat
            local draftedSpellId = qDrafted:GetUInt32(0)
            if not player:HasSpell(draftedSpellId) then
                draftingPlayers[guid] = true
                player:LearnSpell(draftedSpellId)
                draftingPlayers[guid] = nil
            end
        until not qDrafted:NextRow()
    end

    -- Enable anti-cheat back
    if type(SpellDraft_SetSystemLearning) == "function" then
        SpellDraft_SetSystemLearning(guid, false)
    end
    
    -- Sync
    SyncTalentPoints(player)
    SyncDraftedTalents(player)
    
    return refund_points
end


