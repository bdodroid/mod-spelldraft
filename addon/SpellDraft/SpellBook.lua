-- ============================================================================
-- SpellDraft Grimoire - Fully Custom Standalone Spellbook UI
-- ============================================================================

SpellDraft = SpellDraft or {}
local DEBUG = false

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

local talentRows = {}
local talentsFrameCreated = false

local function CreateTalentsPanel()
    if talentsFrameCreated then return end
    
    SpellDraftTalentsFrame = CreateFrame("Frame", "SpellDraftTalentsFrame", SpellDraftBookFrame)
    SpellDraftTalentsFrame:SetSize(340, 395)
    SpellDraftTalentsFrame:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 22, -45)
    SpellDraftTalentsFrame:Hide()
    
    -- Stats Panel
    local statsFrame = CreateFrame("Frame", "SpellDraftStatsFrame", SpellDraftTalentsFrame)
    statsFrame:SetSize(330, 48)
    statsFrame:SetPoint("TOPLEFT", SpellDraftTalentsFrame, "TOPLEFT", 0, 0)
    
    local statsBg = statsFrame:CreateTexture(nil, "BACKGROUND")
    statsBg:SetAllPoints()
    statsBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    statsBg:SetVertexColor(0.1, 0.1, 0.1, 0.5)
    
    local statsBorder = CreateFrame("Frame", nil, statsFrame)
    statsBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    statsBorder:SetAllPoints()
    statsBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)

    prestigeText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    prestigeText:SetPoint("LEFT", statsFrame, "LEFT", 10, 0)
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
    
    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "SpellDraftTalentsScrollFrame", SpellDraftTalentsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(315, 305)
    scrollFrame:SetPoint("TOPLEFT", SpellDraftTalentsFrame, "TOPLEFT", 0, -55)
    
    local scrollChild = CreateFrame("Frame", "SpellDraftTalentsScrollChild", scrollFrame)
    scrollChild:SetSize(310, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Keep references
    SpellDraftTalentsScrollChild = scrollChild
    talentsFrameCreated = true
end

function SpellDraft.UpdateStatsDisplay()
    if not prestigeText then return end
    
    local prestige = SpellDraft.GetPlayerPrestige and SpellDraft.GetPlayerPrestige() or 0
    local rerolls = SpellDraft.RerollsLeft or 0
    local bans = SpellDraft.BansLeft or 0
    local drafts = SpellDraft.DraftsLeft or 0
    
    if prestige > 0 then
        prestigeText:SetText("|cffffd100Prestige:|r " .. prestige)
    else
        prestigeText:SetText("|cffb0b0b0Prestige:|r None")
    end
    
    rerollsText:SetText("|cff1eff00Rerolls:|r " .. rerolls)
    bansText:SetText("|cffe74c3cBans:|r " .. bans)
    
    if drafts > 0 then
        draftsText:SetText("|cff0070ddDrafts:|r " .. drafts)
    else
        draftsText:SetText("|cffb0b0b0Drafts:|r Done")
    end
end

function SpellDraft.RefreshTalentsList()
    if not SpellDraftBookFrame or not SpellDraftTalentsFrame or not SpellDraftTalentsFrame:IsShown() then return end
    
    -- Hide all existing rows first
    for _, row in ipairs(talentRows) do
        row:Hide()
    end
    
    -- Compile list of known passive talents using SpellDraft.DraftedTalents
    local sortedTalents = {}
    if SpellDraft.DraftedTalents and SpellDraftData then
        for _, id in ipairs(SpellDraft.DraftedTalents) do
            local m = SpellDraftData[id]
            if m then
                table.insert(sortedTalents, {
                    spellId = id,
                    name = m.name or "Unknown Talent",
                    rarity = m.rarity or 0,
                    class = m.class or "GENERAL"
                })
            else
                -- Fallback if not in metadata but known
                local name = GetSpellInfo(id)
                if name then
                    table.insert(sortedTalents, {
                        spellId = id,
                        name = name,
                        rarity = 0,
                        class = "GENERAL"
                    })
                end
            end
        end
    end
    
    -- Sort by rarity, then name
    table.sort(sortedTalents, function(a, b)
        if a.rarity ~= b.rarity then
            return a.rarity < b.rarity
        else
            return a.name < b.name
        end
    end)
    
    -- Render each talent row
    local yOffset = 0
    for i, talent in ipairs(sortedTalents) do
        local row = talentRows[i]
        if not row then
            row = CreateFrame("Button", nil, SpellDraftTalentsScrollChild)
            row:SetSize(300, 50)
            
            -- Dark background card with hover effect
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
            row.bg = bg
            
            local border = CreateFrame("Frame", nil, row)
            border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            border:SetAllPoints()
            border:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            row.border = border
            
            -- Icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(40, 40)
            icon:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.icon = icon
            
            -- Icon Border
            local iconBorder = CreateFrame("Frame", nil, row)
            iconBorder:SetBackdrop({
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                edgeSize = 8,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            iconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
            iconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
            row.iconBorder = iconBorder
            
            -- Name Text
            local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            nameText:SetPoint("TOPLEFT", icon, "RIGHT", 10, -5)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText
            
            -- Subtext (Rarity + Category)
            local subText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            subText:SetPoint("BOTTOMLEFT", icon, "RIGHT", 10, 5)
            subText:SetJustifyH("LEFT")
            row.subText = subText
            
            -- Tooltip behavior
            row:SetScript("OnEnter", function(self)
                self.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("spell:" .. self.spellId)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
                GameTooltip:Hide()
            end)
            
            talentRows[i] = row
        end
        
        row.spellId = talent.spellId
        
        -- Get icon and subtext rank
        local _, subName, iconTexture = GetSpellInfo(talent.spellId)
        row.icon:SetTexture(iconTexture)
        
        -- Name & Rarity colors (racials carry rarity 5 only to stay out of the draft pool)
        local rName = RARITY_NAMES[talent.rarity] or "Common"
        local rColor = RARITY_COLORS[talent.rarity] or "|cffb0b0b0"
        local isRacialTalent = talent.rarity == 5 and (subName or ""):find("Racial") ~= nil
        if isRacialTalent then
            rColor = "|cffffd100"
        end

        row.nameText:SetText(rColor .. talent.name .. "|r")
        
        local categoryText = talent.class or "GENERAL"
        if subName and subName ~= "" then
            row.subText:SetText(subName .. " | " .. categoryText)
        else
            row.subText:SetText(categoryText)
        end
        
        -- Color icon border based on rarity (gold for innate racials)
        local rRgb = isRacialTalent and { r = 1, g = 0.82, b = 0.1 } or RARITY_RGB[talent.rarity]
        if rRgb then
            row.iconBorder:SetBackdropBorderColor(rRgb.r, rRgb.g, rRgb.b, 0.9)
            row.border:SetBackdropBorderColor(rRgb.r, rRgb.g, rRgb.b, 0.5)
        else
            row.iconBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
            row.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        end
        
        row:SetPoint("TOPLEFT", SpellDraftTalentsScrollChild, "TOPLEFT", 5, -yOffset)
        row:Show()
        
        yOffset = yOffset + 55
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

local GRIMOIRE_PANELS = {
    { text = "Grimoire", action = function() SpellDraft.ShowGrimoirePanel() end },
    { text = "Talents",  action = function() SpellDraft.ShowTalentsPanel() end },
}

local function CreateBottomTab(id, panelInfo)
    local tabName = "SpellDraftBookFrameTab" .. id
    local tab = _G[tabName]

    if not tab then
        tab = CreateFrame("Button", tabName, SpellDraftBookFrame, "CharacterFrameTabButtonTemplate")
    end

    tab:SetID(id)
    tab:SetText(panelInfo.text)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)

    if id == 1 then
        tab:ClearAllPoints()
        tab:SetPoint("CENTER", SpellDraftBookFrame, "BOTTOMLEFT", 60, -15)
    else
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", _G["SpellDraftBookFrameTab" .. (id - 1)], "RIGHT", -15, 0)
    end

    tab:SetScript("OnClick", function(self)
        local tabId = self:GetID()
        SpellDraftBookFrame.selectedTab = tabId
        PanelTemplates_UpdateTabs(SpellDraftBookFrame)
        if panelInfo.action then
            panelInfo.action()
        end
    end)
    return tab
end

local function SetupBottomTabs()
    SpellDraftBookFrame.numTabs = #GRIMOIRE_PANELS

    for id, panelInfo in ipairs(GRIMOIRE_PANELS) do
        local tab = CreateBottomTab(id, panelInfo)
        PanelTemplates_TabResize(tab, 0)
        tab:Show()
    end

    SpellDraftBookFrame.selectedTab = 1
    PanelTemplates_UpdateTabs(SpellDraftBookFrame)
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
    grimoireTitleText:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 22, -18)
    grimoireTitleText:SetText("Passive Talents")
    
    -- Title Text (Right Page)
    local talentsTitleText = SpellDraftBookFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    talentsTitleText:SetPoint("TOPLEFT", SpellDraftBookFrame, "TOPLEFT", 385, -18)
    talentsTitleText:SetText("Active Spells")
    
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
        local y = -52 - row * 56
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


