SpellDraft = SpellDraft or {}
local After = SpellDraft.After

local prestigeLevels = {}


if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix("PRESTIGE")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        After(2, SpellDraft.UpdateCharacterPrestigeLine)

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == "PRESTIGE" then
            local name, level = strsplit(":", message)
            local prestige = tonumber(level)
            if prestige and prestige > 0 then
                prestigeLevels[name] = prestige
                if name == UnitName("player") then
                    After(0.2, SpellDraft.UpdateCharacterPrestigeLine)
                end
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        After(2, SpellDraft.UpdateCharacterPrestigeLine)
    end
end)

-- Tooltip display
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if unit and UnitIsPlayer(unit) then
        local name = UnitName(unit)
        local prestige = prestigeLevels[name]
        if prestige and prestige > 0 then
            self:AddLine("Prestige Level: " .. prestige, 1, 0.82, 0)
            self:Show()
        end
    end
end)

-- Target frame update
hooksecurefunc("TargetFrame_Update", function()
    if UnitIsPlayer("target") then
        local name = UnitName("target")
        local prestige = prestigeLevels[name]
        if prestige and prestige > 0 then
            TargetFrame.name:SetText(name .. " [P" .. prestige .. "]")
        end
    end
end)

-- Character frame update
local prestigeFontString

function SpellDraft.UpdateCharacterPrestigeLine()
    local name = UnitName("player")
    local prestige = prestigeLevels[name]

    if not CharacterLevelText then
        return
    end

    if not prestigeFontString then
        prestigeFontString = CharacterModelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        prestigeFontString:SetPoint("LEFT", CharacterLevelText, "RIGHT", 32, 0)
        prestigeFontString:SetTextColor(1, 0.82, 0)
    end

    if prestige and prestige > 0 then
        prestigeFontString:SetText("Prestige: " .. prestige)
        prestigeFontString:Show()
    else
        prestigeFontString:SetText("")
        prestigeFontString:Hide()
    end
end

-- Handled by login/addon messages directly

-- When character frame is opened, retry until CharacterLevelText is available
CharacterFrame:HookScript("OnShow", function()
    local function TryUpdate()
        if CharacterLevelText then
            SpellDraft.UpdateCharacterPrestigeLine()
        else
            After(0.5, TryUpdate)
        end
    end
    TryUpdate()
end)
