SpellDraft = SpellDraft or {}

local shopFrame
local selectedIndex = nil
local tokensText
local detailPanel
local buyBtn
local currentPage = 1
local currentTab = "DRAFTS"
local filteredItems = {}
local tabButtons = {}

local shopItems = {
    -- Drafts
    { id = 4427, category = "DRAFTS", name = "Scroll of Reroll", cost = 1, icon = "Interface\\Icons\\INV_Scroll_05", desc = "Consuming this scroll grants you +1 Draft Reroll." },
    { id = 1078, category = "DRAFTS", name = "Scroll of Ban", cost = 1, icon = "Interface\\Icons\\INV_Scroll_08", desc = "Consuming this scroll grants you +1 Draft Ban." },
    { id = 13149, category = "DRAFTS", name = "Lost Grimoire", cost = 2, icon = "Interface\\Icons\\INV_Misc_Book_11", desc = "Consuming this grimoire triggers an immediate bonus spell draft." },
    { id = 25462, category = "DRAFTS", name = "Tome of Talents", cost = 2, icon = "Interface\\Icons\\INV_Misc_Book_10", desc = "Consuming this grimoire triggers a passive class talent draft." },
    
    -- Heirlooms
    { id = 42943, category = "HEIRLOOMS", name = "Bloodied Arcanite Reaper", cost = 3, icon = "Interface\\Icons\\INV_Axe_09", desc = "Heirloom 2H Axe. Scales with level and increases experience gained." },
    { id = 42945, category = "HEIRLOOMS", name = "Dal'Rend's Sacred Charge", cost = 3, icon = "Interface\\Icons\\INV_Sword_27", desc = "Heirloom 1H Sword. Scales with level and increases experience gained." },
    { id = 42946, category = "HEIRLOOMS", name = "Charmed Ancient Bone Bow", cost = 3, icon = "Interface\\Icons\\INV_Weapon_Bow_07", desc = "Heirloom Bow. Scales with level and increases experience gained." },
    { id = 42944, category = "HEIRLOOMS", name = "Balanced Heartseeker", cost = 3, icon = "Interface\\Icons\\INV_Sword_48", desc = "Heirloom Dagger. Scales with level and increases experience gained." },
    { id = 42947, category = "HEIRLOOMS", name = "Headmaster's Charge", cost = 3, icon = "Interface\\Icons\\INV_Staff_12", desc = "Heirloom Staff. Scales with level and increases experience gained." },
    { id = 44100, category = "HEIRLOOMS", name = "Lightforge Spaulders", cost = 3, icon = "Interface\\Icons\\INV_Shoulder_Plate_01", desc = "Heirloom Plate Shoulders. Scales with level and grants +10% XP bonus." },
    { id = 48685, category = "HEIRLOOMS", name = "Breastplate of Valor", cost = 3, icon = "Interface\\Icons\\INV_Chest_Plate04", desc = "Heirloom Plate Chest. Scales with level and grants +10% XP bonus." },
    { id = 42952, category = "HEIRLOOMS", name = "Shadowcraft Spaulders", cost = 3, icon = "Interface\\Icons\\INV_Shoulder_Leather_06", desc = "Heirloom Leather Shoulders. Scales with level and grants +10% XP bonus." },
    { id = 48689, category = "HEIRLOOMS", name = "Shadowcraft Tunic", cost = 3, icon = "Interface\\Icons\\INV_Chest_Leather_08", desc = "Heirloom Leather Chest. Scales with level and grants +10% XP bonus." },
    { id = 48691, category = "HEIRLOOMS", name = "Tattered Dreadmist Robe", cost = 3, icon = "Interface\\Icons\\INV_Chest_Cloth_21", desc = "Heirloom Cloth Chest. Scales with level and grants +10% XP bonus." },
    { id = 42951, category = "HEIRLOOMS", name = "Pauldrons of Elements", cost = 3, icon = "Interface\\Icons\\INV_Shoulder_Mail_02", desc = "Heirloom Mail Shoulders. Scales with level and grants +10% XP bonus." },
    { id = 48683, category = "HEIRLOOMS", name = "Vest of Elements", cost = 3, icon = "Interface\\Icons\\INV_Chest_Mail_03", desc = "Heirloom Mail Chest. Scales with level and grants +10% XP bonus." },
    { id = 42991, category = "HEIRLOOMS", name = "Swift Hand of Justice", cost = 3, icon = "Interface\\Icons\\INV_Jewelry_TrinketPvP_01", desc = "Heirloom Trinket. Scales with level and restores health upon defeating enemies." },
    { id = 42992, category = "HEIRLOOMS", name = "Eye of the Beast", cost = 3, icon = "Interface\\Icons\\INV_Jewelry_TrinketPvP_02", desc = "Heirloom Trinket. Scales with level and restores mana upon defeating enemies." },

    -- Mounts
    { id = 33809, category = "MOUNTS", name = "Amani War Bear", cost = 5, icon = "Interface\\Icons\\Ability_Mount_AmaniBear", desc = "Teaches you how to summon the rare Amani War Bear mount." },
    { id = 49283, category = "MOUNTS", name = "Spectral Tiger", cost = 5, icon = "Interface\\Icons\\Ability_Mount_SpectralTiger", desc = "Teaches you how to summon the legendary Spectral Tiger mount." },
    { id = 32458, category = "MOUNTS", name = "Ashes of Al'ar", cost = 5, icon = "Interface\\Icons\\Ability_Mount_PhoenixMount_01", desc = "Teaches you how to summon the flying Ashes of Al'ar mount." },
    { id = 45693, category = "MOUNTS", name = "Mimiron's Head", cost = 5, icon = "Interface\\Icons\\INV_Misc_Key_14", desc = "Teaches you how to summon the unique Mimiron's Head flying mount." },
    { id = 50818, category = "MOUNTS", name = "Invincible's Reins", cost = 5, icon = "Interface\\Icons\\Ability_Mount_Charger", desc = "Teaches you how to summon the Lich King's personal mount, Invincible." },
    { id = 30609, category = "MOUNTS", name = "Swift Nether Drake", cost = 5, icon = "Interface\\Icons\\Ability_Mount_NetherdrakeElaborate", desc = "Teaches you how to summon the Swift Gladiator Nether Drake." },
    { id = 46708, category = "MOUNTS", name = "Deadly Glad Frost Wyrm", cost = 5, icon = "Interface\\Icons\\Ability_Mount_Razorscale", desc = "Teaches you how to summon the Deadly Gladiator's Frost Wyrm." },

    -- Pets
    { id = 13584, category = "PETS", name = "Diablo Stone", cost = 3, icon = "Interface\\Icons\\INV_Misc_Gem_Stone_02", desc = "Summons a Mini Diablo companion vanity pet." },
    { id = 13582, category = "PETS", name = "Zergling Leash", cost = 3, icon = "Interface\\Icons\\INV_Misc_Leash_01", desc = "Summons a Zergling companion vanity pet." },
    { id = 13583, category = "PETS", name = "Panda Collar", cost = 3, icon = "Interface\\Icons\\INV_Misc_Collar_01", desc = "Summons a Panda Cub companion vanity pet." },
    { id = 30360, category = "PETS", name = "Lurky's Egg", cost = 3, icon = "Interface\\Icons\\INV_Egg_03", desc = "Summons Lurky the Netherwhelp companion vanity pet." },

    -- Cosmetics
    { id = 1973, category = "COSMETICS", name = "Orb of Deception", cost = 4, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_02", desc = "Transform into a member of the opposite faction." },
    { id = 35275, category = "COSMETICS", name = "Orb of the Sin'dorei", cost = 4, icon = "Interface\\Icons\\INV_Misc_Orb_02", desc = "Transform into a Blood Elf for 5 minutes." },
    { id = 37254, category = "COSMETICS", name = "Super Simian Sphere", cost = 5, icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem", desc = "Surround yourself in a purple bubble and transform into a gorilla." },
    { id = 43499, category = "COSMETICS", name = "Iron Boot Flask", cost = 4, icon = "Interface\\Icons\\INV_Potion_104", desc = "Transform into an Iron Dwarf." },
    { id = 33079, category = "COSMETICS", name = "Murloc Costume", cost = 4, icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01", desc = "Transform into a Murloc." },
    { id = 46780, category = "COSMETICS", name = "Ogre Pinata", cost = 3, icon = "Interface\\Icons\\INV_Misc_Toy_10", desc = "Places an Ogre Pinata that can be beaten for bubblegum." },
    { id = 34480, category = "COSMETICS", name = "Romantic Picnic Basket", cost = 3, icon = "Interface\\Icons\\INV_Misc_Food_54", desc = "Sets up a romantic picnic basket complete with a parasol." }
}

-- Setup Confirm Dialog
StaticPopupDialogs["CONFIRM_PRESTIGE_PURCHASE"] = {
    text = "Are you sure you want to purchase %s for %d Prestige Tokens?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        SendChatMessage("SC_BUY_SHOP:" .. data.id, "WHISPER", nil, UnitName("player"))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function FilterItems()
    filteredItems = {}
    for _, item in ipairs(shopItems) do
        if item.category == currentTab then
            table.insert(filteredItems, item)
        end
    end
end

local function UpdateTabVisuals()
    local categories = { "DRAFTS", "HEIRLOOMS", "MOUNTS", "PETS", "COSMETICS" }
    for i, btn in ipairs(tabButtons) do
        if categories[i] == currentTab then
            btn:LockHighlight()
            btn.text:SetTextColor(1, 0.82, 0)
        else
            btn:UnlockHighlight()
            btn.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end
end

function SpellDraft.SelectShopItem(filteredIndex)
    selectedIndex = filteredIndex
    if not shopFrame then return end

    -- Update row backgrounds
    for i, row in ipairs(shopFrame.rows) do
        local absIndex = (currentPage - 1) * 4 + i
        if selectedIndex and absIndex == selectedIndex then
            row.bg:SetVertexColor(0.3, 0.3, 0.1, 0.8) -- Selected color
        else
            row.bg:SetVertexColor(0.15, 0.15, 0.15, 0.6)
        end
    end

    if not selectedIndex or not filteredItems[selectedIndex] then
        detailPanel.name:SetText("")
        detailPanel.desc:SetText("Select an item from the list above to view details.")
        buyBtn:Hide()
    else
        local item = filteredItems[selectedIndex]
        detailPanel.name:SetText(item.name)
        detailPanel.desc:SetText(item.desc)
        buyBtn:Show()

        local tokens = SpellDraft.PrestigeTokens or 0
        if tokens >= item.cost then
            buyBtn:Enable()
        else
            buyBtn:Disable()
        end
    end
end

function SpellDraft.RefreshPrestigeShopList()
    if not shopFrame then return end
    FilterItems()
    
    local totalItems = #filteredItems
    local totalPages = math.max(1, math.ceil(totalItems / 4))
    
    if currentPage > totalPages then
        currentPage = totalPages
    end
    
    -- Update page text and buttons
    shopFrame.pageText:SetText(string.format("Page %d of %d", currentPage, totalPages))
    
    if currentPage > 1 then
        shopFrame.prevBtn:Enable()
    else
        shopFrame.prevBtn:Disable()
    end
    
    if currentPage < totalPages then
        shopFrame.nextBtn:Enable()
    else
        shopFrame.nextBtn:Disable()
    end
    
    -- Populate row frames
    for i = 1, 4 do
        local row = shopFrame.rows[i]
        local itemIndex = (currentPage - 1) * 4 + i
        local item = filteredItems[itemIndex]
        
        if item then
            local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.id)
            if texture then
                row.icon:SetTexture(texture)
            else
                row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            end
            row.nameText:SetText(item.name)
            row.costText:SetText("Cost: " .. item.cost .. " Prestige Token" .. (item.cost > 1 and "s" or ""))
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Update Selection
    SpellDraft.SelectShopItem(selectedIndex)
    UpdateTabVisuals()
end

function SpellDraft.InitializePrestigeShop()
    if shopFrame then return end

    shopFrame = CreateFrame("Frame", "SpellDraftPrestigeShopFrame", UIParent)
    shopFrame:SetSize(400, 420)
    shopFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    shopFrame:SetFrameStrata("HIGH")
    shopFrame:SetFrameLevel(20)
    shopFrame:Hide()

    -- Draggable
    shopFrame:SetMovable(true)
    shopFrame:EnableMouse(true)
    shopFrame:RegisterForDrag("LeftButton")
    shopFrame:SetScript("OnDragStart", shopFrame.StartMoving)
    shopFrame:SetScript("OnDragStop", shopFrame.StopMovingOrSizing)

    -- Escape close
    tinsert(UISpecialFrames, "SpellDraftPrestigeShopFrame")

    -- Backdrop
    shopFrame:SetBackdrop({
        bgFile = nil,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false,
        edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    local bg = shopFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", shopFrame, "TOPLEFT", 8, -8)
    bg:SetPoint("BOTTOMRIGHT", shopFrame, "BOTTOMRIGHT", -8, 8)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.08, 0.08, 0.98)

    -- Title
    local title = shopFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", shopFrame, "TOP", 0, -18)
    title:SetText("Prestige Shop")

    -- Tokens display
    tokensText = shopFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tokensText:SetPoint("TOPLEFT", shopFrame, "TOPLEFT", 20, -18)
    tokensText:SetText("Tokens: 0")

    -- Close Button
    local closeBtn = CreateFrame("Button", "SpellDraftPrestigeShopCloseButton", shopFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", shopFrame, "TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
        shopFrame:Hide()
    end)

    -- Tab buttons
    local categories = { "DRAFTS", "HEIRLOOMS", "MOUNTS", "PETS", "COSMETICS" }
    local tabNames = { "Drafts", "Heirlooms", "Mounts", "Pets", "Cosmetic" }
    
    for i = 1, 5 do
        local btn = CreateFrame("Button", "SpellDraftPrestigeShopTab" .. i, shopFrame)
        btn:SetSize(70, 20)
        if i == 1 then
            btn:SetPoint("TOPLEFT", shopFrame, "TOPLEFT", 20, -40)
        else
            btn:SetPoint("LEFT", tabButtons[i-1], "RIGHT", 2, 0)
        end
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints(btn)
        btnBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        btnBg:SetVertexColor(0.12, 0.12, 0.12, 0.8)
        
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        
        local btnText = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btnText:SetText(tabNames[i])
        btn.text = btnText
        
        btn:SetScript("OnClick", function()
            currentTab = categories[i]
            currentPage = 1
            selectedIndex = nil
            SpellDraft.RefreshPrestigeShopList()
        end)
        
        tabButtons[i] = btn
    end

    -- List container
    local listContainer = CreateFrame("Frame", "SpellDraftPrestigeShopList", shopFrame)
    listContainer:SetSize(360, 210)
    listContainer:SetPoint("TOPLEFT", shopFrame, "TOPLEFT", 20, -65)

    -- Item Rows (Static 4 rows)
    local rows = {}
    for i = 1, 4 do
        local row = CreateFrame("Button", "SpellDraftPrestigeShopRow" .. i, listContainer)
        row:SetSize(360, 48)
        row:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -(i-1)*52)

        -- Background
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        rowBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        rowBg:SetVertexColor(0.15, 0.15, 0.15, 0.6)
        row.bg = rowBg

        -- Highlight
        row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.icon = icon

        -- Name
        local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        nameText:SetPoint("LEFT", icon, "RIGHT", 10, 8)
        row.nameText = nameText

        -- Cost
        local costText = row:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
        costText:SetPoint("LEFT", icon, "RIGHT", 10, -8)
        row.costText = costText

        row:SetScript("OnClick", function()
            local absIndex = (currentPage - 1) * 4 + i
            SpellDraft.SelectShopItem(absIndex)
        end)

        row:SetScript("OnEnter", function(self)
            local itemIndex = (currentPage - 1) * 4 + i
            local item = filteredItems[itemIndex]
            if item then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. item.id)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        rows[i] = row
    end
    shopFrame.rows = rows

    -- Pagination controls at the bottom of the list container
    local prevBtn = CreateFrame("Button", "SpellDraftPrestigeShopPrevButton", listContainer, "UIPanelButtonTemplate")
    prevBtn:SetSize(32, 20)
    prevBtn:SetPoint("BOTTOMLEFT", listContainer, "BOTTOMLEFT", 10, -10)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            SpellDraft.RefreshPrestigeShopList()
        end
    end)
    shopFrame.prevBtn = prevBtn

    local nextBtn = CreateFrame("Button", "SpellDraftPrestigeShopNextButton", listContainer, "UIPanelButtonTemplate")
    nextBtn:SetSize(32, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -10, -10)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function()
        local totalItems = #filteredItems
        local totalPages = math.max(1, math.ceil(totalItems / 4))
        if currentPage < totalPages then
            currentPage = currentPage + 1
            SpellDraft.RefreshPrestigeShopList()
        end
    end)
    shopFrame.nextBtn = nextBtn

    local pageText = listContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pageText:SetPoint("BOTTOM", listContainer, "BOTTOM", 0, -8)
    shopFrame.pageText = pageText

    -- Detail / Buy Panel
    detailPanel = CreateFrame("Frame", "SpellDraftPrestigeShopDetailPanel", shopFrame)
    detailPanel:SetSize(360, 85)
    detailPanel:SetPoint("BOTTOM", shopFrame, "BOTTOM", 0, 15)

    local dpBg = detailPanel:CreateTexture(nil, "BACKGROUND")
    dpBg:SetAllPoints(detailPanel)
    dpBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    dpBg:SetVertexColor(0.04, 0.04, 0.04, 0.8)

    local detailName = detailPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detailName:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
    detailPanel.name = detailName

    local detailDesc = detailPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailDesc:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -28)
    detailDesc:SetWidth(240)
    detailDesc:SetJustifyH("LEFT")
    detailDesc:SetJustifyV("TOP")
    detailPanel.desc = detailDesc

    buyBtn = CreateFrame("Button", "SpellDraftPrestigeShopBuyButton", detailPanel, "UIPanelButtonTemplate")
    buyBtn:SetSize(90, 24)
    buyBtn:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -10, 10)
    buyBtn:SetText("Buy")
    buyBtn:SetScript("OnClick", function()
        if not selectedIndex or not filteredItems[selectedIndex] then return end
        local item = filteredItems[selectedIndex]
        local dialog = StaticPopup_Show("CONFIRM_PRESTIGE_PURCHASE", item.name, item.cost)
        if dialog then
            dialog.data = item
        end
    end)

    -- Query all items to populate local cache immediately
    for _, item in ipairs(shopItems) do
        GetItemInfo(item.id)
    end

    -- Event listener to refresh textures when item info is received
    local cacheFrame = CreateFrame("Frame", "SpellDraftPrestigeShopCacheFrame", shopFrame)
    cacheFrame:RegisterEvent("GET_ITEM_INFO_SEND")
    cacheFrame:SetScript("OnEvent", function(self, event, ...)
        if shopFrame and shopFrame:IsShown() then
            SpellDraft.RefreshPrestigeShopList()
        end
    end)

    -- OnUpdate ticker to refresh if any texture is not loaded yet (since WotLK doesn't fire an event when cache completes)
    local updateTimer = 0
    shopFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= 0.5 then
            updateTimer = 0
            local needsRefresh = false
            for i = 1, 4 do
                local row = shopFrame.rows[i]
                if row and row:IsShown() then
                    local itemIndex = (currentPage - 1) * 4 + i
                    local item = filteredItems[itemIndex]
                    if item then
                        local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.id)
                        if not texture then
                            needsRefresh = true
                            break
                        end
                    end
                end
            end
            if needsRefresh then
                SpellDraft.RefreshPrestigeShopList()
            end
        end
    end)

    SpellDraft.RefreshPrestigeShopList()
    SpellDraft.SelectShopItem(nil)
    SpellDraft.UpdatePrestigeShopTokens()
end

function SpellDraft.UpdatePrestigeShopTokens()
    local tokens = SpellDraft.PrestigeTokens or 0
    if tokensText then
        tokensText:SetText("Tokens: |cff00ff00" .. tokens .. "|r")
    end
    if selectedIndex then
        SpellDraft.SelectShopItem(selectedIndex)
    end
end

function SpellDraft.TogglePrestigeShop()
    SpellDraft.InitializePrestigeShop()
    if shopFrame:IsShown() then
        shopFrame:Hide()
    else
        shopFrame:Show()
        currentPage = 1
        currentTab = "DRAFTS"
        selectedIndex = nil
        SpellDraft.RefreshPrestigeShopList()
        SpellDraft.SelectShopItem(nil)
        SpellDraft.UpdatePrestigeShopTokens()
    end
end
