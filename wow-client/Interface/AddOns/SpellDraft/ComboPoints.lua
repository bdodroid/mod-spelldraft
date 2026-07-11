local _, class = UnitClass("player")
if class ~= "ROGUE" and class ~= "DRUID" then
    -- Override GetComboPoints to return our custom combo points
    local original_GetComboPoints = GetComboPoints
    local currentCP = 0

    GetComboPoints = function(unit, target)
        if unit == "player" and target == "target" then
            return currentCP
        end
        return original_GetComboPoints(unit, target)
    end

    -- Override the standard Blizzard ComboFrame event script to prevent it from hiding itself on other classes
    ComboFrame:SetScript("OnEvent", function(self, event)
        ComboFrame_Update(self)
    end)

    -- Listen for target changes and addon messages from the server
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            if RegisterAddonMessagePrefix then
                RegisterAddonMessagePrefix("SpellDraftCP")
            end
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, message = ...
            if prefix == "SpellDraftCP" then
                currentCP = tonumber(message) or 0
                ComboFrame_Update(ComboFrame)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            currentCP = 0
            ComboFrame_Update(ComboFrame)
        end
    end)
end
