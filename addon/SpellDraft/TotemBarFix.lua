local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
frame:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")

-- Force Blizzard's UI manager to always support and display shapeshift/stance bars for all classes
SHOW_PARENT_SHAPESHIFT = true

-- Force Blizzard's UI manager to always support and display Shaman totem bars for all classes
HasMultiCastActionBar = function()
    return true
end

local function AdjustTotemBar()
    if not MultiCastActionBarFrame then return end
    
    if not MultiCastActionBarFrame:IsShown() then
        MultiCastActionBarFrame:Show()
    end
    
    MultiCastActionBarFrame:ClearAllPoints()
    
    local numForms = GetNumShapeshiftForms() or 0
    if numForms > 0 and ShapeshiftBarFrame then
        -- Stack above Shapeshift / Stance bar
        MultiCastActionBarFrame:SetPoint("BOTTOMLEFT", ShapeshiftBarFrame, "TOPLEFT", 0, 4)
    elseif MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then
        -- Position above BottomLeft Action Bar
        MultiCastActionBarFrame:SetPoint("BOTTOMLEFT", MainMenuBar, "TOPLEFT", 30, 53)
    else
        -- Position above main action bar
        MultiCastActionBarFrame:SetPoint("BOTTOMLEFT", MainMenuBar, "TOPLEFT", 30, 14)
    end
end

local function DelayedAdjust(self, elapsed)
    self:SetScript("OnUpdate", nil)
    AdjustTotemBar()
end

frame:SetScript("OnEvent", function(self, event, ...)
    self:SetScript("OnUpdate", DelayedAdjust)
end)

-- Hook Blizzard's manager to override positioning after any layout changes
hooksecurecall("UIParent_ManageFramePositions", AdjustTotemBar)

if ShapeshiftBarFrame then
    ShapeshiftBarFrame:HookScript("OnShow", AdjustTotemBar)
    ShapeshiftBarFrame:HookScript("OnHide", AdjustTotemBar)
end

if MultiCastActionBarFrame then
    MultiCastActionBarFrame:HookScript("OnShow", AdjustTotemBar)
end
