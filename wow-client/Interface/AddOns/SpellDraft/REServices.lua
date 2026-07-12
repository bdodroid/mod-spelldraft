-- REServices.lua — Nibbs' Mystic Enchant services window.
--
-- Opened by the server (OPENUI addon message) when choosing Nibbs' gossip
-- option. Two services:
--   Reroll/Imbue: drop an item in the slot, pay gold (any rarity) or a
--                 Prestige Token (guaranteed Epic+).
--   Transfer:     move an enchant from the left item to the right item for
--                 gold (cost scales with the enchant's rarity). The result
--                 display lights up with the newly enchanted item; the item
--                 itself stays in your bags.
--
-- Item instances are identified by position key ("inv:N" / "bag:B:S") plus
-- item entry id; the server re-validates both on every action.
-- Protocol documented in lua/SpellDraft/spelldraft_re.lua (server side).

local PREFIX = "SpellDraftRE"

local QUALITY_COLOR = {
    [2] = "|cff1eff00",
    [3] = "|cff0070dd",
    [4] = "|cffa335ee",
    [5] = "|cffff8000",
    [6] = "|cffe6cc80",
}

local function QColored(quality, text)
    return (QUALITY_COLOR[tonumber(quality)] or "|cffffffff") .. text .. "|r"
end

local function Gold(copper) return math.floor((tonumber(copper) or 0) / 10000) .. "g" end

local function SendServer(msg)
    SendChatMessage(msg, "WHISPER", nil, UnitName("player"))
end

-- ---------------------------------------------------------------------------
-- Track where the cursor item was picked up from (bag/slot or equipment).
-- ---------------------------------------------------------------------------
local lastPick = nil
hooksecurefunc("PickupContainerItem", function(bag, slot)
    lastPick = { kind = "bag", bag = bag, slot = slot }
end)
hooksecurefunc("PickupInventoryItem", function(slot)
    lastPick = { kind = "inv", slot = slot }
end)

-- ---------------------------------------------------------------------------
-- Main frame
-- ---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "SpellDraftREServices", UIParent)
frame:SetSize(380, 400)
frame:SetPoint("CENTER", -50, 40)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetFrameStrata("DIALOG")
-- Grimoire-style backdrop: dialog border over a near-black solid fill.
frame:SetBackdrop({
    bgFile = nil,
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = false, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
local frameBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
frameBg:SetPoint("TOPLEFT", 11, -12)
frameBg:SetPoint("BOTTOMRIGHT", -12, 11)
frameBg:SetTexture("Interface\\Buttons\\WHITE8x8")
frameBg:SetVertexColor(0.08, 0.08, 0.08, 0.95)
frame:Hide()
tinsert(UISpecialFrames, "SpellDraftREServices") -- close on Escape

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -16)
title:SetText("|cff9966ffNibbs' Mystic Enchants|r")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -7)

local tokenBalance = 0        -- from server BAL messages
local rerollQuoteTokens = nil -- token cost of the current reroll quote

-- ---------------------------------------------------------------------------
-- Item slot factory
-- ---------------------------------------------------------------------------
local function CreateItemSlot(name, parent, acceptDrops)
    local btn = CreateFrame("Button", name, parent, "ItemButtonTemplate")
    btn.key, btn.entry = nil, nil

    function btn:SetItem(pick, itemId)
        if pick.kind == "bag" then
            self.key = "bag:" .. pick.bag .. ":" .. pick.slot
        else
            self.key = "inv:" .. pick.slot
        end
        self.entry = itemId
        self.pick = pick
        SetItemButtonTexture(self, GetItemIcon(itemId))
        if self.onChanged then self.onChanged() end
    end

    function btn:ClearItem()
        self.key, self.entry, self.pick = nil, nil, nil
        SetItemButtonTexture(self, nil)
        if self.onChanged then self.onChanged() end
    end

    if acceptDrops then
        local function TakeCursor(self)
            if not CursorHasItem() then return end
            local kind, itemId = GetCursorInfo()
            if kind ~= "item" or not lastPick then return end
            ClearCursor()
            self:SetItem(lastPick, itemId)
        end
        btn:SetScript("OnReceiveDrag", TakeCursor)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, mouse)
            if mouse == "RightButton" then
                self:ClearItem()
            else
                TakeCursor(self)
            end
        end)
    else
        btn:RegisterForClicks("RightButtonUp")
        btn:SetScript("OnClick", function(self) self:ClearItem() end)
    end

    -- Dragging off any filled slot picks the real item back onto the cursor.
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if not self.pick then return end
        local pick = self.pick
        self:ClearItem()
        if pick.kind == "bag" then
            PickupContainerItem(pick.bag, pick.slot)
        else
            PickupInventoryItem(pick.slot)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if not self.pick then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.pick.kind == "bag" then
            GameTooltip:SetBagItem(self.pick.bag, self.pick.slot)
        else
            GameTooltip:SetInventoryItem("player", self.pick.slot)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

-- ---------------------------------------------------------------------------
-- Reroll / Imbue section
-- ---------------------------------------------------------------------------
local rerollHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rerollHeader:SetPoint("TOPLEFT", 18, -46)
rerollHeader:SetText("|cffffffffReroll / Imbue|r")

local rerollSlot = CreateItemSlot("SpellDraftRERerollSlot", frame, true)
rerollSlot:SetPoint("TOPLEFT", 24, -66)

local rerollStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rerollStatus:SetPoint("TOPLEFT", rerollSlot, "TOPRIGHT", 10, -2)
rerollStatus:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
rerollStatus:SetJustifyH("LEFT")
rerollStatus:SetText("Drag a green-or-better weapon or armor piece here.")

local goldRollBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
goldRollBtn:SetSize(150, 24)
goldRollBtn:SetPoint("TOPLEFT", 24, -116)
goldRollBtn:SetText("Reroll")
goldRollBtn:Disable()

local goldCostText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
goldCostText:SetPoint("TOP", goldRollBtn, "BOTTOM", 0, -3)
goldCostText:SetText("")

local tokenRollBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
tokenRollBtn:SetSize(180, 24)
tokenRollBtn:SetPoint("LEFT", goldRollBtn, "RIGHT", 8, 0)
tokenRollBtn:SetText("Reroll (Epic+)")
tokenRollBtn:Disable()

local tokenCostText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
tokenCostText:SetPoint("TOP", tokenRollBtn, "BOTTOM", 0, -3)
tokenCostText:SetText("")

local function UpdateTokenCostText()
    if not rerollQuoteTokens then
        tokenCostText:SetText("")
        return
    end
    local color = tokenBalance >= tonumber(rerollQuoteTokens) and "|cffe6cc80" or "|cffff4040"
    tokenCostText:SetText(color .. "Prestige Token: " .. rerollQuoteTokens .. "/" .. tokenBalance .. "|r")
end

-- ---------------------------------------------------------------------------
-- Transfer section
-- ---------------------------------------------------------------------------
local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
divider:SetPoint("TOPLEFT", 12, -156)
divider:SetPoint("TOPRIGHT", -12, -156)
divider:SetHeight(16)

local xferHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
xferHeader:SetPoint("TOPLEFT", 18, -176)
xferHeader:SetText("|cffffffffTransfer Enchant|r")

local srcLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
srcLabel:SetPoint("TOPLEFT", 40, -198)
srcLabel:SetText("Source")
local srcSlot = CreateItemSlot("SpellDraftRESrcSlot", frame, true)
srcSlot:SetPoint("TOPLEFT", 40, -212)

local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
arrow:SetPoint("LEFT", srcSlot, "RIGHT", 28, 0)
arrow:SetText("|cffffd700>>|r")

local dstLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dstLabel:SetPoint("TOPLEFT", 148, -198)
dstLabel:SetText("Destination")
local dstSlot = CreateItemSlot("SpellDraftREDstSlot", frame, true)
dstSlot:SetPoint("TOPLEFT", 148, -212)

local resultLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
resultLabel:SetPoint("TOPLEFT", 262, -198)
resultLabel:SetText("Result")
local resultSlot = CreateItemSlot("SpellDraftREResultSlot", frame, false)
resultSlot:SetPoint("TOPLEFT", 262, -212)
resultSlot:SetAlpha(0.35)

local xferInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
xferInfo:SetPoint("TOPLEFT", 24, -262)
xferInfo:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
xferInfo:SetJustifyH("LEFT")
xferInfo:SetHeight(42)
xferInfo:SetText("Place the enchanted item on the left and the target item on the right.")

local xferWarn = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
xferWarn:SetPoint("TOPLEFT", 24, -304)
xferWarn:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
xferWarn:SetJustifyH("LEFT")
xferWarn:SetText("")

local xferBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
xferBtn:SetSize(180, 26)
xferBtn:SetPoint("BOTTOM", 0, 22)
xferBtn:SetText("Transfer")
xferBtn:Disable()

-- ---------------------------------------------------------------------------
-- Quotes and actions
-- ---------------------------------------------------------------------------
local rerollQuote = nil   -- { gold, tokens, current }
local xferQuote = nil     -- { gold, srcName, dstName }

local function RequestRerollQuote()
    rerollQuote = nil
    rerollQuoteTokens = nil
    goldRollBtn:Disable()
    tokenRollBtn:Disable()
    goldRollBtn:SetText("Reroll")
    tokenRollBtn:SetText("Reroll (Epic+)")
    goldCostText:SetText("")
    UpdateTokenCostText()
    if rerollSlot.key then
        rerollStatus:SetText("Appraising...")
        SendServer("SDRE_QUOTE;R;" .. rerollSlot.key .. ";" .. rerollSlot.entry)
    else
        rerollStatus:SetText("Drag a green-or-better weapon or armor piece here.")
    end
end

local function RequestXferQuote()
    xferQuote = nil
    xferBtn:Disable()
    xferWarn:SetText("")
    resultSlot:ClearItem()
    resultSlot:SetAlpha(0.35)
    if srcSlot.key and dstSlot.key then
        xferInfo:SetText("Appraising...")
        SendServer("SDRE_QUOTE;T;" .. srcSlot.key .. ";" .. srcSlot.entry .. ";" .. dstSlot.key .. ";" .. dstSlot.entry)
    else
        xferInfo:SetText("Place the enchanted item on the left and the target item on the right.")
    end
end

rerollSlot.onChanged = RequestRerollQuote
srcSlot.onChanged = RequestXferQuote
dstSlot.onChanged = RequestXferQuote
resultSlot.onChanged = function()
    if not resultSlot.entry then
        resultSlot:SetAlpha(0.35)
    end
end

goldRollBtn:SetScript("OnClick", function()
    if rerollSlot.key then
        SendServer("SDRE_ROLL;G;" .. rerollSlot.key .. ";" .. rerollSlot.entry)
    end
end)
tokenRollBtn:SetScript("OnClick", function()
    if rerollSlot.key then
        SendServer("SDRE_ROLL;T;" .. rerollSlot.key .. ";" .. rerollSlot.entry)
    end
end)

local function DoTransfer()
    if srcSlot.key and dstSlot.key then
        SendServer("SDRE_XFER;" .. srcSlot.key .. ";" .. srcSlot.entry .. ";" .. dstSlot.key .. ";" .. dstSlot.entry)
    end
end

StaticPopupDialogs["SPELLDRAFT_RE_OVERWRITE"] = {
    text = "This will DESTROY %s on the destination item. Transfer anyway?",
    button1 = YES,
    button2 = NO,
    OnAccept = DoTransfer,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

xferBtn:SetScript("OnClick", function()
    if xferQuote and xferQuote.dstName ~= "" then
        StaticPopup_Show("SPELLDRAFT_RE_OVERWRITE", QColored(xferQuote.dstQuality, "[" .. xferQuote.dstName .. "]"))
    else
        DoTransfer()
    end
end)

-- ---------------------------------------------------------------------------
-- Server messages
-- ---------------------------------------------------------------------------
local function SplitMsg(message)
    local args = {}
    for part in message:gmatch("[^;]+") do
        args[#args + 1] = part
    end
    return args
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(self, event, prefix, message)
    if prefix ~= PREFIX then return end
    local a = SplitMsg(message)

    if a[1] == "OPENUI" then
        rerollSlot:ClearItem()
        srcSlot:ClearItem()
        dstSlot:ClearItem()
        resultSlot:ClearItem()
        resultSlot:SetAlpha(0.35)
        frame:Show()

    elseif a[1] == "BAL" then
        tokenBalance = tonumber(a[2]) or 0
        UpdateTokenCostText()

    elseif a[1] == "QUOTE" and a[2] == "R" then
        if a[3] == "ERR" then
            rerollStatus:SetText("|cffff4040" .. (a[4] or "Cannot service that item") .. "|r")
        elseif a[4] == "OK" then
            rerollQuote = { gold = a[5], tokens = a[6], quality = a[7], current = a[8] or "" }
            rerollQuoteTokens = rerollQuote.tokens
            local verb = rerollQuote.current ~= "" and "Reroll" or "Imbue"
            goldRollBtn:SetText(verb)
            tokenRollBtn:SetText(verb .. " (Epic+)")
            goldCostText:SetText("|cffffd700" .. Gold(rerollQuote.gold) .. "|r")
            UpdateTokenCostText()
            goldRollBtn:Enable()
            tokenRollBtn:Enable()
            if rerollQuote.current ~= "" then
                rerollStatus:SetText("Current: " .. QColored(rerollQuote.quality, rerollQuote.current))
            else
                rerollStatus:SetText("No Mystic Enchant on this item.")
            end
        end

    elseif a[1] == "QUOTE" and a[2] == "T" then
        if a[3] == "OK" then
            xferQuote = { gold = a[4], srcQuality = a[5], srcName = a[6] or "",
                          dstQuality = a[7], dstName = a[8] or "" }
            xferInfo:SetText("Transfer " .. QColored(xferQuote.srcQuality, "[" .. xferQuote.srcName .. "]")
                .. " for |cffffd700" .. Gold(xferQuote.gold) .. "|r")
            if xferQuote.dstName ~= "" then
                xferWarn:SetText("|cffff4040Warning: destination already has "
                    .. QColored(xferQuote.dstQuality, "[" .. xferQuote.dstName .. "]")
                    .. "|cffff4040 - it will be destroyed!|r")
            else
                xferWarn:SetText("")
            end
            xferBtn:Enable()
        else
            xferInfo:SetText("|cffff4040" .. (a[4] or "Cannot transfer") .. "|r")
        end

    elseif a[1] == "RESULT" then
        if a[3] == "OK" then
            PlaySound("LEVELUPSOUND")
            if a[2] == "T" then
                -- Clear both input slots first (their quote resets also wipe
                -- the result preview), THEN light up the result with the
                -- destination item.
                local rKey, rEntry, rPick = dstSlot.key, dstSlot.entry, dstSlot.pick
                srcSlot:ClearItem()
                dstSlot:ClearItem()
                if rEntry then
                    resultSlot.key, resultSlot.entry, resultSlot.pick = rKey, rEntry, rPick
                    SetItemButtonTexture(resultSlot, GetItemIcon(rEntry))
                    resultSlot:SetAlpha(1)
                end
            else
                RequestRerollQuote()
            end
        else
            UIErrorsFrame:AddMessage(a[4] or "Service failed", 1.0, 0.25, 0.25, 1.0, 8)
        end
    end
end)
