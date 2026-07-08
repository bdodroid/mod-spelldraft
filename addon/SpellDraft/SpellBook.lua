-- ============================================================================
-- SpellDraft Grimoire - Fully Custom Standalone Spellbook UI
-- ============================================================================

SpellDraft = SpellDraft or {}
local DEBUG = false

local FALLBACK_SPELLS = {
    [75] = { name = "Auto Shot", icon = "Interface\\Icons\\Ability_Marksmanship", subName = "" },
    [5019] = { name = "Shoot", icon = "Interface\\Icons\\Ability_ShootWand", subName = "" },
    [2764] = { name = "Throw", icon = "Interface\\Icons\\Ability_Throw", subName = "" },
    [6603] = { name = "Attack", icon = "Interface\\Icons\\INV_Sword_04", subName = "" }
}

-- Rarity Mapping Details
local RARITY_NAMES = {
    [0] = "Common",
    [1] = "Uncommon",
    [2] = "Rare",
    [3] = "Epic",
    [4] = "Legendary",
    [5] = "Broken"
}

-- Rarity color formatting
local RARITY_COLORS = {
    [0] = "|cffb0b0b0", -- Grey
    [1] = "|cff1eff00", -- Green
    [2] = "|cff0070dd", -- Blue
    [3] = "|cffa335ee", -- Purple
    [4] = "|cffff8000", -- Orange
    [5] = "|cffe74c3c"  -- Red (Broken)
}

-- Rarity RGB values for borders
local RARITY_RGB = {
    [0] = { r = 0.6, g = 0.6, b = 0.6 },  -- Common (Grey)
    [1] = { r = 0.12, g = 1.0, b = 0.0 }, -- Uncommon (Green)
    [2] = { r = 0.0, g = 0.44, b = 0.87 }, -- Rare (Blue)
    [3] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic (Purple)
    [4] = { r = 1.0, g = 0.5, b = 0.0 },  -- Legendary (Orange)
    [5] = { r = 0.9, g = 0.3, b = 0.2 }   -- Broken (Red)
}

-- Highest valid draft rarity. Anything above this (e.g. the DB default of 99)
-- is an uncategorized, non-draftable spell and is hidden from the Grimoire.
local MAX_DRAFT_RARITY = 5

-- Class Coordinates mapping (standard WoW client coords for UI-CharacterCreate-Classes)
local CLASS_ICON_TCOORDS = {
    ["WARRIOR"]       = {0, 0.25, 0, 0.25},
    ["MAGE"]          = {0.25, 0.5, 0, 0.25},
    ["ROGUE"]         = {0.5, 0.75, 0, 0.25},
    ["DRUID"]         = {0.75, 1, 0, 0.25},
    ["HUNTER"]        = {0, 0.25, 0.25, 0.5},
    ["SHAMAN"]        = {0.25, 0.5, 0.25, 0.5},
    ["PRIEST"]         = {0.5, 0.75, 0.25, 0.5},
    ["WARLOCK"]        = {0.75, 1, 0.25, 0.5},
    ["PALADIN"]        = {0, 0.25, 0.5, 0.75},
    ["DEATHKNIGHT"]    = {0.25, 0.5, 0.5, 0.75},
}

-- Class Tabs Configuration
local tabClasses = {
    { value = "ALL",          text = "All Classes",  icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { value = "WARRIOR",      text = "Warrior",      isClass = true },
    { value = "PALADIN",      text = "Paladin",      isClass = true },
    { value = "HUNTER",       text = "Hunter",       isClass = true },
    { value = "ROGUE",        text = "Rogue",        isClass = true },
    { value = "PRIEST",       text = "Priest",       isClass = true },
    { value = "DEATHKNIGHT",  text = "Death Knight", isClass = true },
    { value = "SHAMAN",       text = "Shaman",       isClass = true },
    { value = "MAGE",         text = "Mage",         isClass = true },
    { value = "WARLOCK",      text = "Warlock",      isClass = true },
    { value = "DRUID",        text = "Druid",        isClass = true },
    { value = "GENERAL",      text = "General/Misc", icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
}

-- Custom Grimoire Window Frame
local SpellDraftBookFrame
local currentPage = 1
local activeClass = "ALL"
local filteredSpells = {}
local buttons = {}
local tabs = {}

local searchBox
local pageText
local prevPageBtn
local nextPageBtn
local SpellDraftTalentsFrame
local SpellDraftTalentsScrollChild
local grimoireTitleText
local prestigeText
local rerollsText
local bansText
local draftsText

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

-- 3.3.5-safe lock texture: SetTexture returns nil for missing files, so try
-- known-good paths in order and keep the first one that loads.
local function ApplyLockTexture(tex)
    if tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK") then
        tex:SetTexCoord(0, 0.71875, 0, 0.875)
        return
    end
    tex:SetTexCoord(0, 1, 0, 1)
    if not tex:SetTexture("Interface\\Buttons\\LockButton-Locked-Up") then
        tex:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
    end
end

-- Shifted tier gating: Tier 0 unlocks at level 1, Tier N at level N*5
local function GetTalentReqLevel(talent)
    if talent.row and talent.row > 0 then
        return talent.row * 5
    end
    return 1
end

-- ----------------------------------------------------------------------------
-- Scanner, Rank Consolidation, and Refresh Logic (WotLK 3.3.5a Compatible)
-- ----------------------------------------------------------------------------

local SpellDraftDataByName = nil

local function GetSpellMetadata(spellId, spellName)
    if not SpellDraftData then return nil end
    
    -- 1. Direct lookup by ID
    local meta = SpellDraftData[spellId]
    if meta then return meta end
    
    -- 2. Build name cache on demand if not already built
    if not SpellDraftDataByName then
        SpellDraftDataByName = {}
        for id, m in pairs(SpellDraftData) do
            if m.name then
                local existing = SpellDraftDataByName[m.name]
                if not existing or (m.rarity and m.rarity <= MAX_DRAFT_RARITY and (not existing.rarity or existing.rarity > MAX_DRAFT_RARITY)) then
                    SpellDraftDataByName[m.name] = m
                end
            end
        end
    end
    
    -- 3. Fallback to name-based lookup (e.g. for higher ranks of spells)
    return SpellDraftDataByName[spellName]
end

local pendingRefresh = false

function SpellDraft.RefreshSpellBook()
    if not SpellDraftBookFrame or not SpellDraftBookFrame:IsShown() then return end
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    
    -- 1. Scan player's native spellbook
    local spellNames = {}
    local numTabs = GetNumSpellTabs()
    
    for i = 1, numTabs do
        local tabName, texture, offset, numSlots = GetSpellTabInfo(i)
        
        for j = 1, numSlots do
            local index = offset + j
            
            -- WotLK API: Safe scan using GetSpellLink and parsing spellId from link (GetSpellBookItemInfo is Cata+)
            local success, err = pcall(function()
                local spellName, spellSubName = GetSpellName(index, "spell")
                local link = GetSpellLink(index, "spell")
                
                if link then
                    local spellId = tonumber(link:match("spell:(%d+)"))
                    if spellId then
                        local metadata = GetSpellMetadata(spellId, spellName)

                        -- Only surface actual draft spells (rarity 0-5). Rarity 99 is the
                        -- DB default for uncategorized/non-draftable spells - skip those.
                        if metadata and metadata.rarity and metadata.rarity <= MAX_DRAFT_RARITY then
                            -- Keep only the highest rank learned for this spell name
                            local existing = spellNames[spellName]
                            if not existing or existing.spellId < spellId then
                                spellNames[spellName] = {
                                    spellId = spellId,
                                    slot = index, -- spellbook slot index, required by PickupSpell in 3.3.5a
                                    name = spellName,
                                    subtext = spellSubName,
                                    rarity = metadata.rarity,
                                    class = metadata.class
                                }
                            end
                        end
                    end
                end
            end)
            
            if not success and DEBUG then print("[SpellDraftBook] Error scanning slot " .. tostring(index) .. ": " .. tostring(err)) end
        end
    end
    
    -- 2. Compile list of unique spells
    local compiledList = {}
    for name, info in pairs(spellNames) do
        table.insert(compiledList, info)
    end
    
    -- 3. Filter by active criteria (Search text, Class tab)
    filteredSpells = {}
    local searchPattern = string.lower(searchBox:GetText() or "")
    
    for _, info in ipairs(compiledList) do
        local matchesClass = (activeClass == "ALL" or info.class == activeClass)
        local matchesSearch = (searchPattern == "" or string.find(string.lower(info.name), searchPattern, 1, true))
        
        if matchesClass and matchesSearch then
            table.insert(filteredSpells, info)
        end
    end
    
    -- Sort by rarity (starting with Common: 0), then alphabetically by name
    table.sort(filteredSpells, function(a, b)
        if a.rarity ~= b.rarity then
            return a.rarity < b.rarity
        else
            return a.name < b.name
        end
    end)
    
    -- 4. Set paging details
    local totalSpells = #filteredSpells
    local totalPages = math.max(1, math.ceil(totalSpells / 12))
    if currentPage > totalPages then
        currentPage = totalPages
    end
    
    pageText:SetText("Page " .. currentPage .. " of " .. totalPages)
    
    -- Prev / Next button status
    if currentPage == 1 then
        prevPageBtn:Disable()
    else
        prevPageBtn:Enable()
    end
    if currentPage == totalPages then
        nextPageBtn:Disable()
    else
        nextPageBtn:Enable()
    end
    
    -- 5. Draw the 12 buttons
    local startIdx = (currentPage - 1) * 12 + 1
    for i = 1, 12 do
        local idx = startIdx + (i - 1)
        local btn = buttons[i]
        
        if idx <= totalSpells then
            local spell = filteredSpells[idx]
            btn.spellId = spell.spellId
            btn.slot = spell.slot -- spellbook slot for drag-to-actionbar
            btn.name:SetText(spell.name)
            
            -- Display rank and colored rarity name.
            -- Racial abilities carry rarity 5 ("Broken") purely to keep them out of
            -- the draft pool (they are auto-granted) — label them as innate instead.
            local rName = RARITY_NAMES[spell.rarity] or "Common"
            local rColor = RARITY_COLORS[spell.rarity] or "|cffb0b0b0"
            local rankText = spell.subtext or ""
            local isRacial = spell.rarity == 5 and rankText:find("Racial") ~= nil

            if isRacial then
                btn.subtext:SetText("|cffffd100" .. rankText .. " | Innate|r")
            elseif rankText ~= "" then
                btn.subtext:SetText(rankText .. " | " .. rColor .. rName .. "|r")
            else
                btn.subtext:SetText(rColor .. rName .. "|r")
            end
            
            -- WotLK API: Get texture from GetSpellInfo
            local _, _, iconTexture = GetSpellInfo(spell.spellId)
            iconTexture = iconTexture or (FALLBACK_SPELLS[spell.spellId] and FALLBACK_SPELLS[spell.spellId].icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
            btn.icon:SetTexture(iconTexture)
            
            -- Color native ActionButton-Border based on spell rarity (gold for innate racials)
            local color = isRacial and { r = 1, g = 0.82, b = 0.1 } or RARITY_RGB[spell.rarity]
            if color then
                btn.border:SetVertexColor(color.r, color.g, color.b)
                btn.border:Show()
            else
                btn.border:Hide()
            end
            
            -- Configure secure button attributes for combat casting support
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", spell.name)
            
            btn:Show()
        else
            btn.spellId = nil
            btn.slot = nil
            btn:SetAttribute("type", nil)
            btn:SetAttribute("spell", nil)
            btn.border:Hide()
            btn:Hide()
        end
    end
end

-- ----------------------------------------------------------------------------
-- Bottom Tabs - Independent Grimoire panels (Grimoire, Talents)
-- ----------------------------------------------------------------------------

local specFrames = {}
local talentsFrameCreated = false
local talentDBInitialized = false
local LocalizedNameToSpellId = {}
local TalentsByClassAndSpec = {}
local currentRanks = {}

-- The specs list in order of classes
local CLASS_ORDER = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
local CLASS_SPECS = {
    WARRIOR = {"Arms", "Fury", "Protection"},
    PALADIN = {"Holy", "Protection", "Retribution"},
    HUNTER = {"Beast Mastery", "Marksmanship", "Survival"},
    ROGUE = {"Assassination", "Combat", "Subtlety"},
    PRIEST = {"Discipline", "Holy", "Shadow"},
    DEATHKNIGHT = {"Blood", "Frost", "Unholy"},
    SHAMAN = {"Elemental", "Enhancement", "Restoration"},
    MAGE = {"Arcane", "Fire", "Frost"},
    WARLOCK = {"Affliction", "Demonology", "Destruction"},
    DRUID = {"Balance", "Feral Combat", "Restoration"}
}

-- Hex colors for classes
local CLASS_COLORS = {
    WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST = "FFFFFF", DEATHKNIGHT = "C41F3B", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", DRUID = "FF7D0A"
}

local function InitializeTalentDB()
    if talentDBInitialized then return end
    if not SpellDraftTalentDB then return end
    
    for spellId, info in pairs(SpellDraftTalentDB) do
        local name = GetSpellInfo(spellId)
        if name then
            LocalizedNameToSpellId[name] = spellId
            info.name = name
        else
            info.name = "Unknown Talent " .. spellId
        end
        
        -- Group by class and spec
        local c = info.class
        local s = info.spec
        if not TalentsByClassAndSpec[c] then
            TalentsByClassAndSpec[c] = {}
        end
        if not TalentsByClassAndSpec[c][s] then
            TalentsByClassAndSpec[c][s] = {}
        end
        
        info.firstRankSpellId = spellId
        table.insert(TalentsByClassAndSpec[c][s], info)
    end
    talentDBInitialized = true
end

local function RecalculateTalentRanks()
    InitializeTalentDB()
    if not SpellDraftTalentDB then return end
    
    -- Clear current ranks
    for spellId in pairs(SpellDraftTalentDB) do
        currentRanks[spellId] = 0
    end
    
    -- Derive ranks from player's synced talents via the generated rank map
    -- (talent names collide across classes, e.g. Rogue/Warrior "Deflection",
    -- so name lookups are only a fallback). The server sends the highest
    -- known rank per talent.
    if SpellDraft.DraftedTalents then
        for _, spellId in ipairs(SpellDraft.DraftedTalents) do
            local firstRankSpellId, rankNum
            local mapped = SpellDraftTalentRankMap and SpellDraftTalentRankMap[spellId]
            if mapped then
                firstRankSpellId, rankNum = mapped[1], mapped[2]
            else
                local name, rankText = GetSpellInfo(spellId)
                if name then
                    firstRankSpellId = LocalizedNameToSpellId[name]
                    rankNum = tonumber(rankText and rankText:match("%d+")) or 1
                end
            end
            if firstRankSpellId and rankNum and rankNum > (currentRanks[firstRankSpellId] or 0) then
                currentRanks[firstRankSpellId] = rankNum
            end
        end
    end
end

local function GetKnownSpellId(talent)
    if not SpellDraft.DraftedTalents then return talent.firstRankSpellId end
    local bestSpellId = talent.firstRankSpellId
    local bestRank = 0
    for _, sid in ipairs(SpellDraft.DraftedTalents) do
        local mapped = SpellDraftTalentRankMap and SpellDraftTalentRankMap[sid]
        if mapped then
            if mapped[1] == talent.firstRankSpellId and mapped[2] > bestRank then
                bestSpellId, bestRank = sid, mapped[2]
            end
        elseif bestRank == 0 then
            local name = GetSpellInfo(sid)
            if name == talent.name then
                bestSpellId = sid
            end
        end
    end
    return bestSpellId
end

local function CreateTalentsPanel()
    if talentsFrameCreated then return end
    
    SpellDraftTalentsFrame = CreateFrame("Frame", "SpellDraftTalentsFrame", SpellDraftBookFrame)
    SpellDraftTalentsFrame:SetSize(340, 362)
    SpellDraftTalentsFrame:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 22, -58)
    SpellDraftTalentsFrame:Hide()

    -- Talent Points Text Label
    local pointsText = SpellDraftTalentsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pointsText:SetPoint("TOPLEFT", SpellDraftTalentsFrame, "TOPLEFT", 10, -3)
    SpellDraftTalentsFrame.talentPointsText = pointsText
    
    -- Scroll Frame (Adjust height to 305 to fit the bottom legend)
    local scrollFrame = CreateFrame("ScrollFrame", "SpellDraftTalentsScrollFrame", SpellDraftTalentsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(315, 305)
    scrollFrame:SetPoint("TOPLEFT", SpellDraftTalentsFrame, "TOPLEFT", 0, -22)
    
    local scrollChild = CreateFrame("Frame", "SpellDraftTalentsScrollChild", scrollFrame)
    scrollChild:SetSize(310, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    SpellDraftTalentsScrollChild = scrollChild

    -- Lock icon for bottom footnote
    local lockIcon = SpellDraftTalentsFrame:CreateTexture(nil, "ARTWORK")
    lockIcon:SetSize(14, 14)
    lockIcon:SetPoint("BOTTOMLEFT", SpellDraftTalentsFrame, "BOTTOMLEFT", 10, 16)
    ApplyLockTexture(lockIcon)
    
    -- Footnote Legend Text
    local legendText = SpellDraftTalentsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    legendText:SetPoint("LEFT", lockIcon, "RIGHT", 4, 0)
    legendText:SetText("|cffbbbbbbLocked talents require Tome of Talents.|r")
    
    -- Respec Instructions Help Text
    local respecHelpText = SpellDraftTalentsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    respecHelpText:SetPoint("BOTTOMLEFT", SpellDraftTalentsFrame, "BOTTOMLEFT", 10, 2)
    respecHelpText:SetText("|cff888888Talk to Nibbs the Imp to reset talents (Free).|r")
    
    talentsFrameCreated = true
end

function SpellDraft.UpdateStatsDisplay()
    if not prestigeText then return end
    
    local prestige = SpellDraft.GetPlayerPrestige and SpellDraft.GetPlayerPrestige() or 0
    local rerolls = SpellDraft.RerollsLeft or 0
    local bans = SpellDraft.BansLeft or 0
    local points = SpellDraft.TalentPoints or 0
    
    if prestige > 0 then
        prestigeText:SetText("|cffffd100Prestige:|r " .. prestige)
    else
        prestigeText:SetText("|cffb0b0b0Prestige:|r None")
    end
    
    rerollsText:SetText("|cff1eff00Rerolls:|r " .. rerolls)
    bansText:SetText("|cffe74c3cBans:|r " .. bans)
    
    if draftsText then
        draftsText:Hide()
    end
    
    if SpellDraftTalentsFrame and SpellDraftTalentsFrame.talentPointsText then
        SpellDraftTalentsFrame.talentPointsText:SetText("|cffffcc00Talent Points: " .. points .. "|r")
    end
end

local function GetOrCreateSpecFrame(index)
    local f = specFrames[index]
    if not f then
        f = CreateFrame("Frame", nil, SpellDraftTalentsScrollChild)
        f:SetSize(310, 616)
        
        -- Header background banner (sleek dark grey panel)
        local headerBg = f:CreateTexture(nil, "BACKGROUND")
        headerBg:SetSize(310, 24)
        headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        headerBg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
        f.headerBg = headerBg
        
        -- Header bottom highlight line
        local headerBorder = f:CreateTexture(nil, "BORDER")
        headerBorder:SetSize(310, 1)
        headerBorder:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT", 0, 0)
        headerBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
        headerBorder:SetVertexColor(0.3, 0.3, 0.3, 0.8)
        f.headerBorder = headerBorder
        
        -- Header text
        local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("CENTER", headerBg, "CENTER", 0, 0)
        f.title = title
        
        f.buttons = {}
        f.linePool = {}
        f.arrowPool = {}
        specFrames[index] = f
    end
    f:ClearAllPoints()
    f:Show()
    f.lineIndex = 0
    f.arrowIndex = 0
    return f
end

local function GetOrCreateTalentButton(specFrame, btnIndex)
    local btn = specFrame.buttons[btnIndex]
    if not btn then
        btn = CreateFrame("Button", nil, specFrame)
        btn:SetSize(32, 32)
        
        -- Dark border outline (peeks out 1px)
        local border = btn:CreateTexture(nil, "BORDER")
        border:SetSize(34, 34)
        border:SetPoint("CENTER", btn, "CENTER", 0, 0)
        border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground") -- solid white
        btn.border = border
        
        -- Dark backing behind icon
        local iconBg = btn:CreateTexture(nil, "BACKGROUND")
        iconBg:SetSize(32, 32)
        iconBg:SetPoint("CENTER", btn, "CENTER", 0, 0)
        iconBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        iconBg:SetVertexColor(0, 0, 0, 0.9)
        btn.iconBg = iconBg
        
        -- Icon texture
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(30, 30)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.icon = icon
        
        -- Rank text frame (so it renders on top of icon)
        local rankFrame = CreateFrame("Frame", nil, btn)
        rankFrame:SetAllPoints()

        local rankText = rankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rankText:SetPoint("CENTER", btn, "BOTTOMRIGHT", -4, 2)
        btn.rankText = rankText

        -- Black plate behind the rank text so it stays readable over any border
        local rankBg = rankFrame:CreateTexture(nil, "ARTWORK")
        rankBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        rankBg:SetVertexColor(0, 0, 0, 0.85)
        rankBg:SetPoint("TOPLEFT", rankText, "TOPLEFT", -3, 1)
        rankBg:SetPoint("BOTTOMRIGHT", rankText, "BOTTOMRIGHT", 3, -1)
        btn.rankBg = rankBg

        -- Lock overlay texture
        local lockOverlay = btn:CreateTexture(nil, "OVERLAY")
        lockOverlay:SetSize(16, 16)
        lockOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
        ApplyLockTexture(lockOverlay)
        lockOverlay:Hide()
        btn.lockOverlay = lockOverlay
        
        -- Highlight texture on hover
        local highlight = btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        if highlight then
            highlight:SetAllPoints(icon)
        end
        
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local spellId = GetKnownSpellId(self.talent)
            GameTooltip:SetHyperlink("spell:" .. spellId)
            
            local talent = self.talent
            if talent.locked then
                GameTooltip:AddLine("|cffbbbbbb[Locked: Requires Tome of Talents]|r")
            else
                local reqLevel = GetTalentReqLevel(talent)
                if UnitLevel("player") < reqLevel then
                    GameTooltip:AddLine("|cffff2020Requires level " .. reqLevel .. "|r")
                end
            end

            if talent.prereqSpellId > 0 then
                local prereq = SpellDraftTalentDB[talent.prereqSpellId]
                if prereq and (currentRanks[talent.prereqSpellId] or 0) < prereq.maxRank then
                    GameTooltip:AddLine("\nRequires " .. prereq.maxRank .. " points in " .. (prereq.name or "prerequisite") .. ".", 1, 0, 0)
                end
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        btn:SetScript("OnClick", function(self)
            local talent = self.talent
            if not talent then return end
            
            if talent.locked then
                UIErrorsFrame:AddMessage("This talent is locked and can only be acquired from a Tome of Talents.", 1.0, 0.1, 0.1, 1.0, 10)
                return
            end

            local reqLevel = GetTalentReqLevel(talent)
            if UnitLevel("player") < reqLevel then
                UIErrorsFrame:AddMessage("This talent requires level " .. reqLevel .. ".", 1.0, 0.1, 0.1, 1.0, 10)
                return
            end

            local currentPoints = SpellDraft.TalentPoints or 0
            if currentPoints <= 0 then
                UIErrorsFrame:AddMessage("You do not have any Talent Points.", 1.0, 0.1, 0.1, 1.0, 10)
                return
            end
            
            -- Send buy message to player's own name (addon whisper protocol)
            SendChatMessage("SC_BUY_TALENT:" .. talent.firstRankSpellId, "WHISPER", nil, UnitName("player"))
        end)
        
        specFrame.buttons[btnIndex] = btn
    end
    btn:ClearAllPoints()
    btn:Show()
    return btn
end

local function DrawPrereqLine(parentButton, childButton, specFrame, isMet)
    local r1, c1 = parentButton.row, parentButton.col
    local r2, c2 = childButton.row, childButton.col
    local color = isMet and {1.0, 0.82, 0.0, 0.8} or {0.25, 0.25, 0.25, 0.6}
    
    local function CreateLineTexture(sf)
        sf.lineIndex = sf.lineIndex + 1
        local line = sf.linePool[sf.lineIndex]
        if not line then
            line = sf:CreateTexture(nil, "BACKGROUND")
            line:SetTexture("Interface\\Buttons\\WHITE8x8")
            sf.linePool[sf.lineIndex] = line
        end
        line:ClearAllPoints()
        line:Show()
        return line
    end
    
    if c1 == c2 then
        local line = CreateLineTexture(specFrame)
        line:SetWidth(4)
        line:SetVertexColor(unpack(color))
        line:SetPoint("TOP", parentButton, "BOTTOM", 0, 0)
        line:SetPoint("BOTTOM", childButton, "TOP", 0, 10)
    elseif r1 == r2 then
        local line = CreateLineTexture(specFrame)
        line:SetHeight(4)
        line:SetVertexColor(unpack(color))
        if c1 < c2 then
            line:SetPoint("LEFT", parentButton, "RIGHT", 0, 0)
            line:SetPoint("RIGHT", childButton, "LEFT", -8, 0)
        else
            line:SetPoint("RIGHT", parentButton, "LEFT", 0, 0)
            line:SetPoint("LEFT", childButton, "RIGHT", 8, 0)
        end
    else
        local line1 = CreateLineTexture(specFrame)
        line1:SetWidth(4)
        line1:SetVertexColor(unpack(color))
        line1:SetPoint("TOP", parentButton, "BOTTOM", 0, 0)
        line1:SetHeight(10)
        
        local line2 = CreateLineTexture(specFrame)
        line2:SetHeight(4)
        line2:SetVertexColor(unpack(color))
        line2:SetPoint("TOP", line1, "BOTTOM", 0, 2)
        if c1 < c2 then
            line2:SetPoint("LEFT", line1, "CENTER", -2, -10)
            line2:SetWidth((c2 - c1) * 68 + 4)
        else
            line2:SetPoint("RIGHT", line1, "CENTER", 2, -10)
            line2:SetWidth((c1 - c2) * 68 + 4)
        end
        
        local line3 = CreateLineTexture(specFrame)
        line3:SetWidth(4)
        line3:SetVertexColor(unpack(color))
        if c1 < c2 then
            line3:SetPoint("TOP", line2, "RIGHT", -4, 2)
        else
            line3:SetPoint("TOP", line2, "LEFT", 4, 2)
        end
        line3:SetPoint("BOTTOM", childButton, "TOP", 0, 10)
    end
end

local function DrawArrow(childButton, specFrame, isMet)
    specFrame.arrowIndex = specFrame.arrowIndex + 1
    local arrow = specFrame.arrowPool[specFrame.arrowIndex]
    if not arrow then
        arrow = specFrame:CreateTexture(nil, "ARTWORK")
        arrow:SetSize(16, 16)
        specFrame.arrowPool[specFrame.arrowIndex] = arrow
    end
    arrow:ClearAllPoints()
    arrow:SetTexture(isMet and "Interface\\TalentFrame\\TalentFrame-Arrow-True" or "Interface\\TalentFrame\\TalentFrame-Arrow-False")
    
    local prereqId = childButton.talent.prereqSpellId
    local prereq = prereqId and prereqId > 0 and SpellDraftTalentDB[prereqId]
    local r1 = prereq and prereq.row or 0
    local c1 = prereq and prereq.col or 0
    local r2, c2 = childButton.row, childButton.col
    
    if r1 == r2 then
        if c1 < c2 then
            arrow:SetTexCoord(0.5, 1.0, 0, 0.5) -- Pointing right
            arrow:SetPoint("RIGHT", childButton, "LEFT", 2, 0)
        else
            arrow:SetTexCoord(1.0, 0.5, 0, 0.5) -- Pointing left
            arrow:SetPoint("LEFT", childButton, "RIGHT", -2, 0)
        end
    else
        arrow:SetTexCoord(0, 0.5, 0, 0.5) -- Pointing down
        arrow:SetPoint("BOTTOM", childButton, "TOP", 0, -2)
    end
    arrow:Show()
end

local buttonsByPos = {}

function SpellDraft.RefreshTalentsList()
    if not SpellDraftBookFrame or not SpellDraftTalentsFrame or not SpellDraftTalentsFrame:IsShown() then return end
    
    RecalculateTalentRanks()
    if not SpellDraftTalentDB then return end
    
    local specsToRender = {}
    if activeClass == "ALL" then
        for _, classVal in ipairs(CLASS_ORDER) do
            local classSpecs = CLASS_SPECS[classVal]
            if classSpecs then
                for _, specName in ipairs(classSpecs) do
                    table.insert(specsToRender, { class = classVal, spec = specName })
                end
            end
        end
    elseif activeClass ~= "GENERAL" then
        local classSpecs = CLASS_SPECS[activeClass]
        if classSpecs then
            for _, specName in ipairs(classSpecs) do
                table.insert(specsToRender, { class = activeClass, spec = specName })
            end
        end
    end
    
    local yOffset = 0
    for index, specInfo in ipairs(specsToRender) do
        local specFrame = GetOrCreateSpecFrame(index)
        specFrame:SetPoint("TOPLEFT", SpellDraftTalentsScrollChild, "TOPLEFT", 0, -yOffset)
        
        local classColor = CLASS_COLORS[specInfo.class] or "FFFFFF"
        specFrame.title:SetText(specInfo.spec .. " |cff" .. classColor .. "(" .. specInfo.class .. ")|r")
        
        local specTalents = TalentsByClassAndSpec[specInfo.class] and TalentsByClassAndSpec[specInfo.class][specInfo.spec]
        for k in pairs(buttonsByPos) do buttonsByPos[k] = nil end
        
        local btnIndex = 0
        if specTalents then
            for _, dt in ipairs(specTalents) do
                btnIndex = btnIndex + 1
                local btn = GetOrCreateTalentButton(specFrame, btnIndex)
                btn.talent = dt
                btn.row = dt.row
                btn.col = dt.col
                
                dt.locked = LOCKED_TALENTS[dt.firstRankSpellId] or false
                if dt.locked then
                    btn.lockOverlay:Show()
                else
                    btn.lockOverlay:Hide()
                end
                
                local x = dt.col * 68 + 20
                local y = -(dt.row * 52 + 10 + 24)
                btn:SetPoint("TOPLEFT", specFrame, "TOPLEFT", x, y)
                
                local _, _, iconTexture = GetSpellInfo(dt.firstRankSpellId)
                btn.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
                
                local rank = currentRanks[dt.firstRankSpellId] or 0
                local maxRank = dt.maxRank
                local isMet = true
                if dt.prereqSpellId > 0 then
                    local prereq = SpellDraftTalentDB[dt.prereqSpellId]
                    if prereq then
                        isMet = (currentRanks[dt.prereqSpellId] or 0) >= prereq.maxRank
                    end
                end
                
                local selectable = isMet and not dt.locked
                    and UnitLevel("player") >= GetTalentReqLevel(dt)

                if rank == maxRank then
                    btn.icon:SetDesaturated(false)
                    btn.border:SetVertexColor(1.0, 0.82, 0.0, 1.0)
                    btn.rankText:SetText("|cffffd100" .. rank .. "/" .. maxRank .. "|r")
                elseif rank > 0 then
                    btn.icon:SetDesaturated(false)
                    btn.border:SetVertexColor(0.12, 1.0, 0.12, 1.0)
                    btn.rankText:SetText("|cff00ff00" .. rank .. "/" .. maxRank .. "|r")
                elseif selectable then
                    -- Purchasable right now with talent points: full color
                    btn.icon:SetDesaturated(false)
                    btn.border:SetVertexColor(0.9, 0.9, 0.9, 1.0)
                    btn.rankText:SetText("|cffffffff0/" .. maxRank .. "|r")
                else
                    -- Locked, level-gated, or prereq unmet: greyed out
                    btn.icon:SetDesaturated(true)
                    btn.border:SetVertexColor(0.35, 0.35, 0.35, 0.8)
                    btn.rankText:SetText("|cff8080800/" .. maxRank .. "|r")
                end
                
                buttonsByPos[dt.row .. "_" .. dt.col] = btn
            end
        end
        
        for b = btnIndex + 1, #specFrame.buttons do
            specFrame.buttons[b]:Hide()
        end
        
        if specTalents then
            for _, dt in ipairs(specTalents) do
                if dt.prereqSpellId > 0 then
                    local prereq = SpellDraftTalentDB[dt.prereqSpellId]
                    if prereq then
                        local parentBtn = buttonsByPos[prereq.row .. "_" .. prereq.col]
                        local childBtn = buttonsByPos[dt.row .. "_" .. dt.col]
                        if parentBtn and childBtn then
                            local isMet = (currentRanks[dt.prereqSpellId] or 0) >= prereq.maxRank
                            DrawPrereqLine(parentBtn, childBtn, specFrame, isMet)
                            DrawArrow(childBtn, specFrame, isMet)
                        end
                    end
                end
            end
        end
        
        for l = specFrame.lineIndex + 1, #specFrame.linePool do
            specFrame.linePool[l]:Hide()
        end
        for a = specFrame.arrowIndex + 1, #specFrame.arrowPool do
            specFrame.arrowPool[a]:Hide()
        end
        
        yOffset = yOffset + 616
    end
    
    for f = #specsToRender + 1, #specFrames do
        specFrames[f]:Hide()
    end
    
    SpellDraftTalentsScrollChild:SetHeight(math.max(1, yOffset))
end

function SpellDraft.ShowGrimoirePanel()
    searchBox:Show()
    prevPageBtn:Show()
    nextPageBtn:Show()
    pageText:Show()
    for _, btn in ipairs(buttons) do
        btn:Show()
    end
    for _, tab in ipairs(tabs) do
        tab:Show()
    end
    SpellDraft.RefreshSpellBook()
end

function SpellDraft.ShowTalentsPanel()
    if not SpellDraftTalentsFrame then
        CreateTalentsPanel()
    end
    SpellDraftTalentsFrame:Show()
    SpellDraft.RefreshTalentsList()
end



-- ----------------------------------------------------------------------------
-- Initialization on PLAYER_LOGIN
-- ----------------------------------------------------------------------------
local function InitializeGrimoire()
    -- 1. Create Standalone Window Frame (strata set to HIGH to ensure it renders on top)
    SpellDraftBookFrame = CreateFrame("Frame", "SpellDraftBookFrame", UIParent)
    SpellDraftBookFrame:SetSize(740, 450)
    SpellDraftBookFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    SpellDraftBookFrame:SetFrameStrata("HIGH")
    SpellDraftBookFrame:Hide()
    
    -- Allow window dragging
    SpellDraftBookFrame:SetMovable(true)
    SpellDraftBookFrame:EnableMouse(true)
    SpellDraftBookFrame:RegisterForDrag("LeftButton")
    SpellDraftBookFrame:SetScript("OnDragStart", SpellDraftBookFrame.StartMoving)
    SpellDraftBookFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        if point then
            SpellDraftDB = SpellDraftDB or {}
            SpellDraftDB.BookFramePoint = {
                point = point,
                relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs
            }
        end
    end)
    
    -- Escape Key support
    tinsert(UISpecialFrames, "SpellDraftBookFrame")
    
    -- 2. Draw Book Backdrop (solid black + dialog border)
    SpellDraftBookFrame:SetBackdrop({
        bgFile = nil,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Solid black background texture replacing the custom image
    local grimBg = SpellDraftBookFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    grimBg:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 11, -12)
    grimBg:SetPoint("BOTTOMRIGHT", SpellDraftBookFrame, "BOTTOMRIGHT", -12, 11)
    grimBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    grimBg:SetVertexColor(0.08, 0.08, 0.08, 0.95)
    
    -- Center Divider Line
    local divider = SpellDraftBookFrame:CreateTexture(nil, "ARTWORK")
    divider:SetSize(2, 400)
    divider:SetPoint("CENTER", SpellDraftBookFrame, "CENTER", 0, -10)
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.2, 0.2, 0.2, 0.4)

    -- Close Button
    local closeBtn = CreateFrame("Button", "SpellDraftBookFrameCloseButton", SpellDraftBookFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", SpellDraftBookFrame, "TOPRIGHT", -15, -12)
    closeBtn:SetScript("OnClick", function()
        SpellDraftBookFrame:Hide()
    end)
    
    -- Title Text (Left Page)
    grimoireTitleText = SpellDraftBookFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    grimoireTitleText:SetPoint("TOP", SpellDraftBookFrame, "TOPLEFT", 192, -35)
    grimoireTitleText:SetText("Talents")
    
    -- Title Text (Right Page)
    local talentsTitleText = SpellDraftBookFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    talentsTitleText:SetPoint("TOP", SpellDraftBookFrame, "TOPLEFT", 555, -35)
    talentsTitleText:SetText("Abilities")
    
    -- Stats Panel (relocated to the top bar)
    local statsFrame = CreateFrame("Frame", "SpellDraftStatsFrame", SpellDraftBookFrame)
    statsFrame:SetSize(350, 24)
    statsFrame:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 115, -14)
    
    prestigeText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    prestigeText:SetPoint("LEFT", statsFrame, "LEFT", 0, 0)
    prestigeText:SetJustifyH("LEFT")

    rerollsText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    rerollsText:SetPoint("LEFT", statsFrame, "LEFT", 95, 0)
    rerollsText:SetJustifyH("LEFT")

    bansText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bansText:SetPoint("LEFT", statsFrame, "LEFT", 175, 0)
    bansText:SetJustifyH("LEFT")

    draftsText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    draftsText:SetPoint("LEFT", statsFrame, "LEFT", 250, 0)
    draftsText:SetJustifyH("LEFT")
    
    -- 3. Expanded Search Box (Tucked next to the right header)
    searchBox = CreateFrame("EditBox", "SpellDraftBookSearchBox", SpellDraftBookFrame, "InputBoxTemplate")
    searchBox:SetSize(170, 20)
    searchBox:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 538, -15)
    searchBox:SetAutoFocus(false)
    
    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
    searchPlaceholder:SetText("Search spells...")
    
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == "" then
            searchPlaceholder:Show()
        else
            searchPlaceholder:Hide()
        end
        currentPage = 1
        SpellDraft.RefreshSpellBook()
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- 5. Prev/Next Page Controls (Shifted to Right Page)
    prevPageBtn = CreateFrame("Button", "SpellDraftBookPrevPageButton", SpellDraftBookFrame)
    prevPageBtn:SetSize(32, 32)
    prevPageBtn:SetPoint("BOTTOMLEFT", SpellDraftBookFrame, "BOTTOMLEFT", 465, 16)
    prevPageBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevPageBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevPageBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    prevPageBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    prevPageBtn:SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            SpellDraft.RefreshSpellBook()
            PlaySound("igSpellBookPageTurn")
        end
    end)
    
    pageText = SpellDraftBookFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pageText:SetPoint("LEFT", prevPageBtn, "RIGHT", 15, 0)
    pageText:SetText("Page 1 of 1")

    nextPageBtn = CreateFrame("Button", "SpellDraftBookNextPageButton", SpellDraftBookFrame)
    nextPageBtn:SetSize(32, 32)
    nextPageBtn:SetPoint("LEFT", pageText, "RIGHT", 15, 0)
    nextPageBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextPageBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextPageBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    nextPageBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    nextPageBtn:SetScript("OnClick", function()
        local totalSpells = #filteredSpells
        local totalPages = math.max(1, math.ceil(totalSpells / 12))
        if currentPage < totalPages then
            currentPage = currentPage + 1
            SpellDraft.RefreshSpellBook()
            PlaySound("igSpellBookPageTurn")
        end
    end)
    
    -- 6. Create Standalone Custom Spell Slots Grid (Shifted to Right Page)
    for i = 1, 12 do
        local btn = CreateFrame("Button", "SpellDraftBookSpellButton" .. i, SpellDraftBookFrame, "SecureActionButtonTemplate")
        btn:SetSize(160, 44)

        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = 385 + col * 174
        local y = -58 - row * 56
        btn:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", x, y)

        -- Colored rarity frame: a solid square that peeks out ~2px around the icon.
        local border = btn:CreateTexture(nil, "BORDER")
        border:SetSize(42, 42)
        border:SetPoint("LEFT", btn, "LEFT", 0, 0)
        border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground") -- solid white
        border:Hide()
        btn.border = border

        -- Dark slot backing behind the icon
        local slotBg = btn:CreateTexture(nil, "BACKGROUND")
        slotBg:SetSize(42, 42)
        slotBg:SetPoint("CENTER", border, "CENTER", 0, 0)
        slotBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        slotBg:SetVertexColor(0, 0, 0, 0.9)

        -- Spell Icon (trimmed to hide the default icon border, centered on the frame)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("CENTER", border, "CENTER", 0, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.icon = icon

        -- Spell Name
        local name = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        name:SetPoint("TOPLEFT", border, "TOPRIGHT", 8, 0)
        name:SetJustifyH("LEFT")
        name:SetWidth(108)
        btn.name = name

        -- Rank & Rarity Text
        local subtext = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        subtext:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        subtext:SetJustifyH("LEFT")
        subtext:SetWidth(108)
        btn.subtext = subtext

        -- Hover highlight over the icon
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(icon)
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
        
        -- Interactive mouse actions
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        btn:SetScript("OnEnter", function(self)
            if self.spellId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellId)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        -- Action Bar Drag-and-Drop.
        -- In 3.3.5a PickupSpell takes the spellbook slot index + bookType, NOT the
        -- game spell ID. Passing the spell ID picks up nothing (out-of-range slot).
        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function(self)
            if InCombatLockdown() then return end
            if self.slot then
                -- pcall guards against edge cases (e.g. slot invalidated by relearn)
                pcall(PickupSpell, self.slot, "spell")
            end
        end)
        
        buttons[i] = btn
    end
    
    -- 7. Create Custom Class Tabs (Right Side of Entire Book - spaced out more)
    for i, classInfo in ipairs(tabClasses) do
        local tab = CreateFrame("CheckButton", "SpellDraftBookTab" .. i, SpellDraftBookFrame)
        tab:SetSize(32, 32)
        tab:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPRIGHT", -3, -30 - (i - 1) * 34)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(64, 64)
        bg:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
        bg:SetTexture("Interface\\Spellbook\\Spellbook-SkillLineTab")
        tab.bg = bg

        tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        local checkedTex = tab:GetCheckedTexture()
        if checkedTex then
            checkedTex:SetBlendMode("ADD")
        end

        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
        if classInfo.isClass then
            icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
            local coords = CLASS_ICON_TCOORDS[classInfo.value]
            if coords then
                icon:SetTexCoord(unpack(coords))
            end
        else
            icon:SetTexture(classInfo.icon)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        tab.icon = icon
        
        tab:SetScript("OnClick", function(self)
            activeClass = classInfo.value
            for j, t in ipairs(tabs) do
                t:SetChecked(j == i)
            end
            currentPage = 1
            SpellDraft.RefreshSpellBook()
            if SpellDraft.RefreshTalentsList then
                SpellDraft.RefreshTalentsList()
            end
            PlaySound("igAbilitiesOpen")
        end)
        
        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(classInfo.text)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        tabs[i] = tab
    end
    tabs[1]:SetChecked(true)
    
    -- 8. Setup Refresh Hooks
    SpellDraftBookFrame:SetScript("OnShow", function()
        SpellDraft.ShowGrimoirePanel()
        SpellDraft.ShowTalentsPanel()
        if SpellDraft.UpdateStatsDisplay then
            SpellDraft.UpdateStatsDisplay()
        end
    end)
    
    SpellDraftBookFrame:SetScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        activeClass = "ALL"
        for i, t in ipairs(tabs) do
            t:SetChecked(i == 1)
        end
        currentPage = 1
    end)

    -- Refresh spell list when spellbook changes while Grimoire is open
    SpellDraftBookFrame:RegisterEvent("SPELLS_CHANGED")
    SpellDraftBookFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
    SpellDraftBookFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    SpellDraftBookFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingRefresh then
                pendingRefresh = false
                SpellDraft.RefreshSpellBook()
            end
        else
            if not self:IsShown() then return end
            SpellDraft.RefreshSpellBook()
            if SpellDraft.UpdateStatsDisplay then
                SpellDraft.UpdateStatsDisplay()
            end
        end
    end)

    -- Restore position if saved
    if SpellDraftDB and SpellDraftDB.BookFramePoint then
        pcall(function()
            local p = SpellDraftDB.BookFramePoint
            SpellDraftBookFrame:ClearAllPoints()
            SpellDraftBookFrame:SetPoint(p.point, _G[p.relativeTo] or UIParent, p.relativePoint, p.xOfs, p.yOfs)
        end)
    end
end

-- ----------------------------------------------------------------------------
-- Microbar Launcher Button
-- ----------------------------------------------------------------------------

local openButton

local function EnsureSavedVariables()
    SpellDraftDB = SpellDraftDB or {}
    SpellDraftDB.openButton = SpellDraftDB.openButton or {}
end

local function PositionOpenButton(useDefault)
    if not openButton then return end
    EnsureSavedVariables()
    openButton:ClearAllPoints()
    
    local pos = SpellDraftDB.openButton
    if not useDefault and pos.point and pos.relativePoint and pos.x and pos.y then
        openButton:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        -- Default position: Anchor directly to the native WoW Spellbook MicroButton
        -- This guarantees it aligns perfectly across all resolutions and UI scales.
        if SpellbookMicroButton then
            openButton:SetPoint("TOPLEFT", SpellbookMicroButton, "TOPLEFT", 0, 0)
            openButton:SetPoint("BOTTOMRIGHT", SpellbookMicroButton, "BOTTOMRIGHT", 0, 0)
        else
            -- Fallback to your character Nix's calibrated coordinates
            openButton:SetPoint("BOTTOM", UIParent, "BOTTOM", 72.9, 61.6)
        end
    end
end

local function SaveOpenButtonPosition()
    if not openButton then return end
    EnsureSavedVariables()
    local point, _, relativePoint, x, y = openButton:GetPoint(1)
    SpellDraftDB.openButton.point = point
    SpellDraftDB.openButton.relativePoint = relativePoint
    SpellDraftDB.openButton.x = x
    SpellDraftDB.openButton.y = y
end

local function ResetOpenButtonPosition()
    EnsureSavedVariables()
    SpellDraftDB.openButton = {}
    PositionOpenButton(true)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpellDraft]|r Button position reset.")
end

local function CreateOpenButton()
    if openButton then return end
    
    openButton = CreateFrame("Button", "SpellDraftMicroButton", UIParent)
    openButton:SetSize(32, 64) -- Match physical TGA dimensions
    openButton:SetFrameStrata("HIGH")
    openButton:SetFrameLevel(10)
    openButton:SetMovable(true)
    openButton:EnableMouse(true)
    openButton:SetClampedToScreen(true)
    openButton:RegisterForDrag("LeftButton")
    
    -- Set custom textures
    openButton:SetNormalTexture("Interface\\AddOns\\SpellDraft\\Textures\\grimoire_btn_up")
    openButton:SetPushedTexture("Interface\\AddOns\\SpellDraft\\Textures\\grimoire_btn_down")
    
    openButton:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight")
    local highlight = openButton:GetHighlightTexture()
    if highlight then
        highlight:SetBlendMode("ADD")
    end
    
    PositionOpenButton(false)
    openButton:Show()
    
    openButton:SetScript("OnClick", function()
        if not SpellDraftBookFrame then return end
        if SpellDraftBookFrame:IsShown() then
            SpellDraftBookFrame:Hide()
        else
            SpellDraftBookFrame:Show()
        end
    end)
    
    openButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    openButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveOpenButtonPosition()
    end)
    
    openButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("SpellDraft Grimoire")
        GameTooltip:AddLine("Click to toggle spellbook.", 1, 1, 1)
        GameTooltip:AddLine("Drag with Left Click to reposition.", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    openButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ----------------------------------------------------------------------------
-- Slash Command: /spelldraft
-- ----------------------------------------------------------------------------

SLASH_SPELLDRAFT1 = "/spelldraft"
SlashCmdList["SPELLDRAFT"] = function(msg)
    if not SpellDraftBookFrame then DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[SpellDraft]|r Grimoire not initialized yet.") return end
    
    msg = string.lower(msg or "")
    if msg == "reset button" or msg == "resetbutton" or msg == "button reset" then
        ResetOpenButtonPosition()
        return
    end

    if SpellDraftBookFrame:IsShown() then
        SpellDraftBookFrame:Hide()
    else
        SpellDraftBookFrame:Show()
    end
end

-- ----------------------------------------------------------------------------
-- Event Frame for PLAYER_LOGIN initialization
-- ----------------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeGrimoire()
        CreateOpenButton()
    end
end)

-- ----------------------------------------------------------------------------
-- Tooltip Enhancement: Show spell resource costs for mismatched power types
-- When a Warrior drafts Shadow Bolt, the client hides the "420 Mana" cost
-- because the player's primary power type is Rage. This hook adds it back.
-- Works globally: action bars, native spellbook, Grimoire, anywhere.
-- ----------------------------------------------------------------------------

local POWER_TYPE_INFO = {
    [0] = { name = "Mana",        r = 0.00, g = 0.00, b = 1.00 },
    [1] = { name = "Rage",        r = 1.00, g = 0.00, b = 0.00 },
    [2] = { name = "Focus",       r = 1.00, g = 0.50, b = 0.25 },
    [3] = { name = "Energy",      r = 1.00, g = 1.00, b = 0.00 },
    [6] = { name = "Runic Power", r = 0.00, g = 0.82, b = 1.00 },
}

GameTooltip:HookScript("OnTooltipSetSpell", function(self)
    local name, id = self:GetSpell()
    if not id then return end

    local _, _, _, cost, _, powerType = GetSpellInfo(id)
    if not cost or cost == 0 then return end

    local playerPowerType = UnitPowerType("player")
    if powerType == playerPowerType then return end -- client already shows it

    local info = POWER_TYPE_INFO[powerType]
    if not info then return end

    self:AddLine(cost .. " " .. info.name, info.r, info.g, info.b)
    self:Show() -- refresh to render the added line
end)


