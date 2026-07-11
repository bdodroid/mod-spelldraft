local function UpdateAmmoSlotVisibility()
    -- Dynamically resolve frames at runtime to prevent initialization race conditions
    local ammoSlot = CharacterAmmoSlot9 or CharacterAmmoSlot
    local rangedSlot = CharacterRangedSlot9 or CharacterRangedSlot

    if not ammoSlot then return end

    if UnitHasRelicSlot("player") then
        local rangedID = GetInventoryItemID("player", 18) -- 18 is the Ranged/Relic inventory slot
        local showAmmo = false

        if rangedID then
            local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(rangedID)
            if itemEquipLoc == "INVTYPE_RANGED" then
                showAmmo = true
            end
        end

        -- Save the desired visibility state so the Hide hook can access it
        ammoSlot.shouldBeShown = showAmmo

        if showAmmo then
            -- Prevent recursion when setting properties
            ammoSlot.settingProperties = true

            -- Reparent to PaperDollFrame so it automatically hides when switching tabs
            ammoSlot:SetParent(PaperDollFrame)
            
            -- Force TOOLTIP strata to bypass clipping masks
            ammoSlot:SetFrameStrata("TOOLTIP")
            ammoSlot:SetFrameLevel(100)
            
            ammoSlot:ClearAllPoints()
            -- Anchor to the right of rangedSlot with a 15px offset to match Hunter alignment
            ammoSlot:SetPoint("LEFT", rangedSlot, "RIGHT", 15, 0)
            ammoSlot:Show()

            ammoSlot.settingProperties = false

            -- Force an update on the button state and texture
            if PaperDollItemSlotButton_Update then
                PaperDollItemSlotButton_Update(ammoSlot)
            end
        else
            ammoSlot.settingProperties = true
            ammoSlot:Hide()
            ammoSlot.settingProperties = false
        end
    end
end

-- Hook when the character pane is shown
hooksecurefunc("PaperDollFrame_OnShow", UpdateAmmoSlotVisibility)

-- Hook when the individual slot buttons are updated
hooksecurefunc("PaperDollItemSlotButton_Update", function(self)
    if self:GetID() == 18 then
        UpdateAmmoSlotVisibility()
    end
end)

-- Listen to events for maximum safety (caching / inventory changes)
local frame = CreateFrame("Frame")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "GET_ITEM_INFO_RECEIVED" or (event == "UNIT_INVENTORY_CHANGED" and unit == "player") then
        UpdateAmmoSlotVisibility()
    end
end)

-- Intercept and prevent overwrites by native UI code
local function SetupAntiHideHook()
    local ammoSlot = CharacterAmmoSlot9 or CharacterAmmoSlot
    if not ammoSlot then return end

    if not ammoSlot.antiHideHooked then
        ammoSlot.antiHideHooked = true
        
        hooksecurefunc(ammoSlot, "Hide", function(self)
            -- If our own code is calling Hide, let it happen
            if self.settingProperties then return end
            
            -- If native UI tries to hide the slot, but we want it shown, override and show it
            if self.shouldBeShown then
                self.settingProperties = true
                self:Show()
                self.settingProperties = false
            end
        end)
    end
end

-- Setup hook immediately and also on player entering world to be safe
SetupAntiHideHook()
local setupFrame = CreateFrame("Frame")
setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
setupFrame:SetScript("OnEvent", SetupAntiHideHook)
