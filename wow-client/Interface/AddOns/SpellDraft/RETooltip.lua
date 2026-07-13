-- RETooltip.lua — renders Mystic Enchants (Random Enchantments) on item tooltips.
--
-- Item links carry no usable per-instance id in 3.3.5 (uniqueId is 0 for
-- regular items), so the server identifies enchanted items BY POSITION.
-- spelldraft_re.lua pushes "SpellDraftRE" addon messages whenever the
-- inventory changes:
--     RESET                                          wipe the map
--     POS;<key>;<spellId>;<quality>;<name>;<tooltip> one enchanted item
-- where <key> is "inv:<1-19>" (equipped), "bag:0:<1-16>" (backpack) or
-- "bag:<1-4>:<1-36>" (side bags) — matching GameTooltip's SetInventoryItem /
-- SetBagItem arguments.
--
-- The enchant's effect text is resolved client-side from its aura spell (so
-- numbers are always accurate); the server tooltip string is a fallback.

local QUALITY_COLOR = {
    [2] = "|cff1eff00",
    [3] = "|cff0070dd",
    [4] = "|cffa335ee",
    [5] = "|cffff8000",
    [6] = "|cffe6cc80",
}

local cache = {}  -- [positionKey] = { spell, quality, name, tooltip }

-- Hidden tooltip used to read a spell's description text.
local scanTip = CreateFrame("GameTooltip", "SpellDraftREScanTip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetSpellDescription(spellId)
    scanTip:ClearLines()
    scanTip:SetHyperlink("spell:" .. spellId)
    local lines = {}
    for i = 2, scanTip:NumLines() do
        local fs = _G["SpellDraftREScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        -- Skip rank/cast-time metadata rows; keep the description body.
        if text and #text > 20 then
            lines[#lines + 1] = text
        end
    end
    if #lines > 0 then
        return table.concat(lines, " ")
    end
    return nil
end

local function AppendEnchantLines(tooltip, data)
    local color = QUALITY_COLOR[data.quality] or "|cff1eff00"
    tooltip:AddLine(" ")
    tooltip:AddLine(color .. "Mystic Enchant: " .. data.name .. "|r")
    local desc = nil
    if data.spell and data.spell > 0 then
        desc = GetSpellDescription(data.spell)
    end
    desc = desc or data.tooltip
    if desc and desc ~= "" then
        tooltip:AddLine(desc, 0.9, 0.9, 0.9, true)
    end
    tooltip:Show()
end

hooksecurefunc(GameTooltip, "SetInventoryItem", function(self, unit, slot)
    if unit ~= "player" then return end
    local data = cache["inv:" .. slot]
    if data then
        AppendEnchantLines(self, data)
    end
end)

hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
    local data = cache["bag:" .. bag .. ":" .. slot]
    if data then
        AppendEnchantLines(self, data)
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, prefix, message)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Ask the server for a fresh map (covers /reload, which wipes us
        -- without any server-side inventory change to trigger a push).
        SendChatMessage("SDRE_SYNC", "WHISPER", nil, UnitName("player"))
        return
    end
    if prefix ~= "SpellDraftRE" then return end

    if message == "RESET" then
        wipe(cache)
        return
    end

    local key, spellId, quality, name, tooltipText =
        message:match("^POS;([^;]+);(%d+);(%d+);([^;]+);(.*)$")
    if not key then return end

    cache[key] = {
        spell = tonumber(spellId),
        quality = tonumber(quality),
        name = name,
        tooltip = tooltipText,
    }
end)
