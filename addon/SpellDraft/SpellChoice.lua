SpellDraft = SpellDraft or {}

-- Shared single timer frame implementation for Delay/After
local timerFrame = CreateFrame("Frame")
local timerQueue = {}

timerFrame:SetScript("OnUpdate", function(self, elapsed)
  local now = GetTime()
  local i = 1
  while i <= #timerQueue do
    local item = timerQueue[i]
    if now >= item.fireAt then
      table.remove(timerQueue, i)
      local success, err = pcall(item.fn)
      if not success then
        geterrorhandler()(err)
      end
    else
      i = i + 1
    end
  end
  if #timerQueue == 0 then
    self:Hide()
  end
end)
timerFrame:Hide()

function SpellDraft.After(seconds, func)
  table.insert(timerQueue, { fireAt = GetTime() + seconds, fn = func })
  timerFrame:Show()
end

local Delay = SpellDraft.After

-- Create a hidden tooltip for reading spell descriptions
local tooltip = CreateFrame("GameTooltip", "SpellDraftHiddenTooltip", UIParent, "GameTooltipTemplate")
local cacheTooltip = CreateFrame("GameTooltip", "SpellDraftCacheTooltip", UIParent, "GameTooltipTemplate")
cacheTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local showHUD = true
local rarityTextures = {
  "COMM.tga",  -- Common
  "UNCO.tga",  -- Uncommon
  "RARE.tga",  -- Rare
  "EPIC.tga",  -- Epic
  "LEGE.tga",  -- Legendary
  "BROK.tga",  -- Broken (joke/trap cards?)
}

local lastSpellIDs = {}
local dismissToggled = false
local restoringFromDismiss = false
local isTalentDraftActive = false
local bannedSpells = {}
local currentSpellRarities = {}
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
GameTooltip:SetFrameStrata("TOOLTIP")
GameTooltip:SetFrameLevel(100)
GameTooltip:SetClampedToScreen(true)

-- Determine primary faction language that is speakable and known
local function GetFactionLanguage()
  return nil
end

-- Filter out SC:* whispers from showing in chat (only for self-whispers)
local function SpellChoiceWhisperFilter(_, _, msg, sender)
  if sender == UnitName("player") then
    if msg:match("^SC:%d+$") or
       msg:match("^SC_BAN:%d+$") or
       msg:match("^SC_BUY_TALENT:%d+$") or
       msg == "SC_CHECK" or
       msg == "SC_REROLL" or
       msg == "SC_REPLACE_BANNED" then
      return true
    end
  end
end
local bansLeft = 0
local rerollsLeft = 0
local banMode = false
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", SpellChoiceWhisperFilter)         -- incoming
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", SpellChoiceWhisperFilter) -- outgoing

local unlocked = false -- ← Controlled by server response
local frame = SpellChoiceFrame
SpellChoiceFrame:EnableMouse(true)
SpellChoiceFrame:SetFrameStrata("TOOLTIP")
GameTooltip:SetClampedToScreen(true)
local buttons = {SpellChoiceButton1, SpellChoiceButton2, SpellChoiceButton3}

-- Using shared timer frame for Delay
local function UpdateRerollButton()
  if not SpellChoiceRerollButton then return end
  SpellChoiceRerollButton:SetText("Reroll (" .. rerollsLeft .. ")")

  if rerollsLeft > 0 then
    SpellChoiceRerollButton:Enable()
  else
    SpellChoiceRerollButton:Disable()
  end
end
-- Debug helper
local function Debug(msg)
  --DEFAULT_CHAT_FRAME:AddMessage("|cff9999ff[DEBUG]|r " .. tostring(msg))
end

-- Request prestige status on login/reload
local function RequestPrestigeStatus()
  local target = UnitName("player")
  if target then
    SendChatMessage("SC_CHECK", "WHISPER", GetFactionLanguage(), UnitName("player"))
    --Debug("Sent SC_CHECK to server")
  else
    print("SpellChoice: Failed to send SC message — player name is nil.")
  end
end

local function HandleSpellClick(self)
  local spellID = self:GetID()
  if not spellID or spellID <= 0 then return end

  if bannedSpells[spellID] then
    Debug("[Ban] Blocked click on banned spell ID: " .. spellID)
    return
  end

  PlaySound("igMainMenuOptionCheckBoxOn")

  if banMode then
    local target = UnitName("player")
    if target then
      SendChatMessage("SC_BAN:" .. spellID, "WHISPER", GetFactionLanguage(), target)
      Debug("[Ban] Attempting to ban spell ID: " .. spellID)
    end
    return
  end

  -- Selection animation block
  for _, otherBtn in ipairs(buttons) do
    if otherBtn ~= self then
      otherBtn:EnableMouse(false)
      UIFrameFadeOut(otherBtn, 0.5, 1, 0.1)
    else
      otherBtn:SetScale(1.1)
      UIFrameFadeOut(otherBtn, 0.5, 1, 1)
    end
  end

  local target = UnitName("player")
  if target then
    Delay(0.5, function()
      SendChatMessage("SC:" .. spellID, "WHISPER", GetFactionLanguage(), target)
    end)
  end
end



-- Show spell choices to the player
local function ShowSpellChoices(spellIDs)

  if UnitAffectingCombat("player") and UnitLevel("player") > 1 then
    dismissToggled = true
    if SpellDraftDB then
      SpellDraftDB.dismissToggled = true
    end
    if SpellChoiceDismissButton then
      local btnText = isTalentDraftActive and "Talent Draft" or ((SpellDraft.DraftsLeft or 0) .. " Draft(s) Left")
      SpellChoiceDismissButton:SetText(btnText)
      SpellChoiceDismissButton:SetParent(UIParent)
      SpellChoiceDismissButton:ClearAllPoints()
      SpellChoiceDismissButton:SetPoint("CENTER", UIParent, "CENTER", 0, -300)
      SpellChoiceDismissButton:SetFrameStrata("FULLSCREEN_DIALOG")
      SpellChoiceDismissButton:EnableMouse(true)
      SpellChoiceDismissButton:Show()
    end
  end

  if dismissToggled then
    -- Full suppression: disable everything interactable
    for _, btn in ipairs(buttons) do
      btn:Hide()
      btn:EnableMouse(false)
      btn:SetScript("OnEnter", nil)
      btn:SetScript("OnLeave", nil)
      btn:SetScript("OnClick", nil)
    end

    GameTooltip:Hide()
    GameTooltip:ClearAllPoints()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")

    SpellChoiceFrame:Hide()
    SpellChoiceFrame:EnableMouse(false)
    SpellChoiceFrame:SetAlpha(0)
    return
  end

  -- Restore clean UI state from minimized/dismissed state
  SpellChoiceFrame:SetAlpha(1)
  SpellChoiceFrame:EnableMouse(true)
  if SpellChoiceDismissButton then
    SpellChoiceDismissButton:SetParent(SpellChoiceFrame)
    SpellChoiceDismissButton:ClearAllPoints()
    SpellChoiceDismissButton:SetPoint("CENTER", SpellChoiceTitle, "TOP", 0, -290)
    SpellChoiceDismissButton:SetFrameStrata("FULLSCREEN_DIALOG")
    SpellChoiceDismissButton:SetText("Dismiss")
  end

  --print("SpellChoiceTitle is", SpellChoiceTitle and "found" or "MISSING")
  if not unlocked then
    --Debug("Blocked: Player is not prestiged.")
    return
  end

  -- if UnitLevel("player") == 1 then
  --   Debug("Blocked: Player is level 1. Spell choices disabled.")
  --   return
  -- end

  --Debug("Showing spell choices...")

local FALLBACK_SPELLS = {
  [75] = { name = "Auto Shot", icon = "Interface\\Icons\\Ability_Marksmanship", subName = "" },
  [5019] = { name = "Shoot", icon = "Interface\\Icons\\Ability_ShootWand", subName = "" },
  [2764] = { name = "Throw", icon = "Interface\\Icons\\Ability_Throw", subName = "" },
  [6603] = { name = "Attack", icon = "Interface\\Icons\\INV_Sword_04", subName = "" }
}

  for i = 1, #buttons do
    local spellID = tonumber(spellIDs[i])
    local btn = buttons[i]

    if spellID and btn then
      local name, subName, icon = GetSpellInfo(spellID)
      if (not name or not icon) and FALLBACK_SPELLS[spellID] then
        name = name or FALLBACK_SPELLS[spellID].name
        icon = icon or FALLBACK_SPELLS[spellID].icon
        subName = subName or FALLBACK_SPELLS[spellID].subName
      end

      btn.icon        = _G[btn:GetName() .. "Icon"]
      btn.name        = _G[btn:GetName() .. "Name"]
      --btn.mana        = _G[btn:GetName() .. "Mana"]
      --btn.castTime    = _G[btn:GetName() .. "CastTime"]
      --btn.description = _G[btn:GetName() .. "Description"]
      btn.levelReq    = _G[btn:GetName() .. "LevelReq"]

      if name and icon then
        if not btn.subNameText then
          local subNameText = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
          subNameText:SetJustifyH("CENTER")
          btn.subNameText = subNameText
        end

        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOP", btn, "TOP", 0, -90)

        btn.name:ClearAllPoints()
        btn.name:SetPoint("TOP", btn, "TOP", 0, -56)
        btn.name:SetText(name)

        btn.subNameText:ClearAllPoints()
        if subName and subName ~= "" then
          btn.subNameText:SetPoint("TOP", btn, "TOP", 0, -70)
          btn.subNameText:SetText("|cff808080" .. subName .. "|r")
          btn.subNameText:Show()
        else
          btn.subNameText:Hide()
        end

        Debug("Spell " .. i .. ": " .. name .. " (ID: " .. spellID .. ")")
        -- Force spell to load into cache
        cacheTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        cacheTooltip:SetHyperlink("spell:" .. spellID)
        
      btn:SetID(spellID)
      btn:SetNormalTexture("Interface\\Icons\\" .. icon)
      btn.icon:SetTexture(icon)

      if bannedSpells[spellID] then
        btn:SetAlpha(0.3)
        btn:Disable()
        btn:EnableMouse(false)
        Debug("[Ban] Auto-disabled banned spell ID: " .. spellID)
      else
        btn:SetAlpha(1)
        btn:Enable()
        btn:EnableMouse(true)
      end


        btn.icon:SetTexture(icon)
        local rarityFrame = _G[btn:GetName() .. "Rarity"]
        local rarityIndex = currentSpellRarities[i] or -1
        if rarityFrame and rarityIndex >= 0 then
          local rarityTex = rarityTextures[rarityIndex + 1]
          if rarityTex then
            rarityFrame:SetTexture("Interface\\AddOns\\SpellDraft\\Textures\\" .. rarityTex)
            rarityFrame:Show()
          else
            rarityFrame:Hide()
          end
        elseif rarityFrame then
          rarityFrame:Hide()
        end

        if not restoringFromDismiss then
        btn:SetScale(0.8)
        btn:SetAlpha(0)
        UIFrameFadeIn(btn, 0.6, 0, 1)

        -- Pulse animation
        local t = 0
        local pulseSpeed = 10
        local pulseDuration = (2 * math.pi) / pulseSpeed

        btn:SetScript("OnUpdate", function(self, elapsed)
          t = t + elapsed
          if t >= pulseDuration then
            self:SetScript("OnUpdate", nil)
            self:SetScale(1)
          else
            local scale = 1 + 0.05 * math.sin(t * pulseSpeed)
            self:SetScale(scale)
          end
        end)
      else
        btn:SetScale(1)
        btn:SetAlpha(1)
        btn:SetScript("OnUpdate", nil)
      end
        btn:EnableMouse(true)
        btn:Show()
      else
        Debug("Missing data for spell ID: " .. tostring(spellID))
        btn:SetID(spellID)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.name:SetText("Spell #" .. spellID)
        if btn.description then
          btn.description:SetText("Spell data not cached.")
        end
        if btn.levelReq then
          btn.levelReq:SetText("")
        end
        btn:EnableMouse(true)
        btn:Show()
        local rarityFrame = _G[btn:GetName() .. "Rarity"]
        if rarityFrame then
          rarityFrame:Hide()
        end
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:SetHyperlink("spell:" .. spellID)
      end
    else
      Debug("Invalid spell or button at index " .. tostring(i))
      if btn then btn:Hide() end
    end
  end

  if isTalentDraftActive then
    if SpellChoiceRerollButton then SpellChoiceRerollButton:Hide() end
    if SpellChoiceBanButton then SpellChoiceBanButton:Hide() end
  else
    if SpellChoiceRerollButton then SpellChoiceRerollButton:Show() end
    if SpellChoiceBanButton then SpellChoiceBanButton:Show() end
  end

  frame:Show()
end


-- Event listening for addon messages
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

local enterTime = nil
local isWorldLoaded = false
local prestigeRetries = 0

local function TryRequestPrestige()
  if not enterTime then
    enterTime = GetTime()
  end

  local target = UnitName("player")
  if target and target ~= UNKNOWNOBJECT and target ~= "" then
    local elapsed = GetTime() - enterTime
    local minDelay = 0.5
    if UnitLevel("player") == 1 then
      minDelay = 5.0
    end

    if elapsed >= minDelay and isWorldLoaded then
      RequestPrestigeStatus()
    elseif prestigeRetries < 20 then
      prestigeRetries = prestigeRetries + 1
      Delay(0.5, TryRequestPrestige)
    end
  elseif prestigeRetries < 20 then
    prestigeRetries = prestigeRetries + 1
    Delay(0.5, TryRequestPrestige)
  end
end

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
  if event == "ADDON_LOADED" and arg1 == "SpellDraft" then
    SpellDraftDB = SpellDraftDB or {}
    if SpellDraftDB.showHUD == nil then
      SpellDraftDB.showHUD = true
    end
    if SpellDraftDB.dismissToggled == nil then
      SpellDraftDB.dismissToggled = false
    end
    showHUD = SpellDraftDB.showHUD
    dismissToggled = SpellDraftDB.dismissToggled

    if dismissToggled then
      if SpellChoiceTitle then SpellChoiceTitle:Hide() end
      if SpellChoiceRerollButton then SpellChoiceRerollButton:Hide() end
      SpellChoiceFrame:EnableMouse(false)
      SpellChoiceFrame:SetAlpha(0.01)

      if SpellChoiceDismissButton then
          SpellChoiceDismissButton:SetParent(UIParent)
          SpellChoiceDismissButton:ClearAllPoints()
          SpellChoiceDismissButton:SetPoint("CENTER", UIParent, "CENTER", 0, -300)
          SpellChoiceDismissButton:SetFrameStrata("FULLSCREEN_DIALOG")
          SpellChoiceDismissButton:EnableMouse(true)
          SpellChoiceDismissButton:Show()
      end
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    isWorldLoaded = true
    prestigeRetries = 0
    enterTime = nil
    TryRequestPrestige()

  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = arg1, arg2, arg3, arg4
    if prefix == "SpellChoiceStatus" then
      if message == "prestiged" then
        unlocked = true
        SpellDraft.Unlocked = true
        Debug("SpellChoice unlocked (prestiged).")
      else
        unlocked = false
        SpellDraft.Unlocked = false
        Debug("SpellChoice locked (not prestiged).")
      end
      if SpellDraft.UpdateHUD then SpellDraft.UpdateHUD() end

    elseif prefix == "SpellChoiceIsTalent" then
      isTalentDraftActive = (message == "1")

    elseif prefix == "SpellChoiceBansLeft" then
      bansLeft = tonumber(message) or 0
      SpellDraft.BansLeft = bansLeft
      if SpellChoiceBanButton then
        SpellChoiceBanButton:SetText(banMode and ("Ban [ON] (" .. bansLeft .. ")") or ("Ban (" .. bansLeft .. ")"))
      end
      if SpellDraft.UpdateStatsDisplay then
        SpellDraft.UpdateStatsDisplay()
      end
  elseif prefix == "SpellChoiceBans" then
    bannedSpells = {}
    local count = 0
    for id in string.gmatch(message, "%d+") do
      bannedSpells[tonumber(id)] = true
      count = count + 1
    end
    Debug("Loaded " .. count .. " banned spells from server.")   
  elseif prefix == "SpellChoiceBanAccepted" then
    local bannedID = tonumber(message)
    for _, btn in ipairs(buttons) do
      if btn:GetID() == bannedID then
        btn:SetAlpha(0.3)
        btn:Disable()
        Debug("[Ban] Server confirmed ban of spell ID " .. bannedID)
      end
    end

    -- Immediately refresh with new spell if needed
    local target = UnitName("player")
    if target then
      Delay(0.3, function()
        SendChatMessage("SC_REPLACE_BANNED", "WHISPER", GetFactionLanguage(), target)
      end)      
      Debug("[Ban] Immediately requested replacement for banned spell ID: " .. bannedID)
    end

  elseif prefix == "SpellChoiceBanDenied" then
      UIErrorsFrame:AddMessage("No bans remaining.", 1.0, 0.2, 0.2, 1)
      Debug("[Ban] Ban denied: no bans left")
    elseif prefix == "SpellChoice" then
      Debug("Received SpellChoice message: " .. message)

      local spellIDs = {}
      for id in string.gmatch(message, "%d+") do
        table.insert(spellIDs, tonumber(id))
      end

      -- Compare to last shown list
      local isDuplicate = #spellIDs == #lastSpellIDs
      if isDuplicate then
        for i = 1, #spellIDs do
          if spellIDs[i] ~= lastSpellIDs[i] then
            isDuplicate = false
            break
          end
        end
      end

      if isDuplicate and SpellChoiceFrame:IsShown() then
        Debug("Ignored duplicate spellID list (frame already shown).")
        return
      end

      -- If we got here, it's a new set
      lastSpellIDs = spellIDs
      dismissToggled = false
      if SpellDraftDB then
        SpellDraftDB.dismissToggled = false
      end
      Delay(0.5, function()
        ShowSpellChoices(spellIDs)
      end)
    elseif prefix == "SpellChoiceClose" then
      frame:Hide()

    elseif prefix == "SpellChoiceTalents" then
      SpellDraft.DraftedTalents = {}
      if message and message ~= "" then
        for id in string.gmatch(message, "%d+") do
          table.insert(SpellDraft.DraftedTalents, tonumber(id))
        end
      end
      if SpellDraft.RefreshTalentsList then
        SpellDraft.RefreshTalentsList()
      end

    elseif prefix == "SpellChoiceTalentPoints" then
      local points = tonumber(message) or 0
      SpellDraft.TalentPoints = points
      if SpellDraft.UpdateStatsDisplay then
        SpellDraft.UpdateStatsDisplay()
      end

    elseif prefix == "SpellChoiceRerollDenied" then
      UIErrorsFrame:AddMessage("You have no rerolls remaining.", 1, 0, 0, 1)

    elseif prefix == "SpellChoiceRerolls" then
      rerollsLeft = tonumber(message) or 0
      SpellDraft.RerollsLeft = rerollsLeft
      UpdateRerollButton()
      if SpellDraft.UpdateStatsDisplay then
        SpellDraft.UpdateStatsDisplay()
      end

    elseif prefix == "SpellChoiceDrafts" then
      local totalDrafts = tonumber(message) or 0
      SpellDraft.DraftsLeft = totalDrafts
      if SpellChoiceTitle then
        SpellChoiceTitle:SetText("" .. totalDrafts .. " Drafts Remaining")
      end
      if dismissToggled and SpellChoiceDismissButton then
        SpellChoiceDismissButton:SetText(totalDrafts .. " Draft(s) Left")
      end
      if SpellDraft.UpdateStatsDisplay then
        SpellDraft.UpdateStatsDisplay()
      end
    elseif prefix == "SpellChoiceRarities" then
      currentSpellRarities = {}
      for r in string.gmatch(message, "-?%d+") do
        table.insert(currentSpellRarities, tonumber(r))
      end
      local rarities = {}
      for r in string.gmatch(message, "-?%d+") do
        table.insert(rarities, tonumber(r))
      end

      for i, rarity in ipairs(rarities) do
        local btn = buttons[i]
        if not btn then break end
        local rarityFrame = _G[btn:GetName() .. "Rarity"]

        if rarity and rarity >= 0 then
          local rarityTex = rarityTextures[rarity + 1]
          if rarityTex and rarityFrame then
            rarityFrame:SetTexture("Interface\\AddOns\\SpellDraft\\Textures\\" .. rarityTex)
            rarityFrame:Show()
          elseif rarityFrame then
            rarityFrame:Hide()
          end
        elseif rarityFrame then
          -- Rarity is -1 or invalid (NULL or missing)
          rarityFrame:Hide()
        end
      end
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Auto-minimize choice frame on entering combat (only for level > 1)
    if UnitLevel("player") > 1 and not dismissToggled and SpellChoiceFrame:IsShown() then
      local dismissBtn = SpellChoiceDismissButton
      if dismissBtn then
        local onClick = dismissBtn:GetScript("OnClick")
        if onClick then
          onClick(dismissBtn)
        end
      end
    end
  end
end)

Debug("SpellChoice addon loaded.")

for _, btn in ipairs(buttons) do
  btn:SetScript("OnEnter", function(self)
    local spellID = self:GetID()
    if spellID and spellID > 0 then
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink("spell:" .. spellID)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)
btn:SetScript("OnClick", HandleSpellClick)
end



local rerollCooldown = false

SpellChoiceRerollButton:SetScript("OnClick", function()
  PlaySound("igMainMenuOptionCheckBoxOn")
  if rerollCooldown or not unlocked or rerollsLeft <= 0 then
    UIErrorsFrame:AddMessage("Cannot reroll at this time.", 1, 0, 0, 1)
    return
  end

  rerollCooldown = true
  SpellChoiceRerollButton:Disable()

  Delay(0.5, function()
    rerollCooldown = false
    UpdateRerollButton() -- Re-enables if rerollsLeft > 0
  end)

  local target = UnitName("player")
  if target then
    SendChatMessage("SC_REROLL", "WHISPER", GetFactionLanguage(), target)
  else
    print("SpellChoice: Failed to send SC_REROLL — player name is nil.")
  end
end)
SpellChoiceBanButton = CreateFrame("Button", "SpellChoiceBanButton", SpellChoiceFrame, "UIPanelButtonTemplate")
SpellChoiceBanButton:SetSize(100, 22)
SpellChoiceBanButton:SetText("Ban")
SpellChoiceBanButton:SetPoint("LEFT", SpellChoiceRerollButton, "RIGHT", 10, 0)
SpellChoiceBanButton:SetScript("OnClick", function(self)
  PlaySound("igMainMenuOptionCheckBoxOn")
  banMode = not banMode

  -- Toggle appearance
  if banMode then
    self:SetText("Ban [ON] (" .. bansLeft .. ")")
    SpellChoiceRerollButton:Disable()
    UIErrorsFrame:AddMessage("Ban Mode Activated", 1.0, 0.5, 0.0, 1)
    Debug("[Ban] Mode activated")
  else
    self:SetText("Ban (" .. bansLeft .. ")")
    UpdateRerollButton()
    Debug("[Ban] Mode deactivated")

    -- Check if any shown spell is banned
    local found = false
    for _, btn in ipairs(buttons) do
      local id = btn:GetID()
      if bannedSpells[id] then
        found = true
        Debug("[Ban] Detected banned spell in current draft: " .. id)
        break
      end
    end

    -- If so, request replacements for just banned ones
    if found then
      local target = UnitName("player")
      if target then
        SendChatMessage("SC_REPLACE_BANNED", "WHISPER", GetFactionLanguage(), target)
        Debug("[Ban] Requesting replacement for banned spells...")
        SendChatMessage("SC_CHECK", "WHISPER", GetFactionLanguage(), target)  -- Refresh bans too
        Debug("[Ban] Also re-requesting ban list to clear replaced spell")
      end
    end
  end
end)
SpellChoiceBanButton:Show()
SpellChoiceDismissButton:SetScript("OnClick", function(self)
    PlaySound("igMainMenuOptionCheckBoxOn")
    dismissToggled = not dismissToggled
    if SpellDraftDB then
        SpellDraftDB.dismissToggled = dismissToggled
    end

    if dismissToggled then
        local btnText
        if isTalentDraftActive then
            btnText = "Talent Draft"
        else
            local label = SpellChoiceTitle:GetText() or ""
            local count = label:match("(%d+)") or "0"
            btnText = count .. " Draft(s) Left"
        end
        self:SetText(btnText)

        for _, btn in ipairs(buttons) do
            btn:Hide()
            btn:EnableMouse(false)
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn:SetScript("OnClick", nil)
        end

        SpellChoiceTitle:Hide()
        SpellChoiceRerollButton:Hide()
        SpellChoiceFrame:EnableMouse(false)
        SpellChoiceFrame:SetAlpha(0.01)

        self:SetParent(UIParent)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, -300)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:EnableMouse(true)
        self:Show()

        -- Reset ban state when hidden
        banMode = false
        SpellChoiceBanButton:SetText("Ban")
        UpdateRerollButton()
        Debug("[Ban] Ban mode reset due to dismissal")
    else
        self:SetText("Dismiss")

        -- Reset ban mode just in case
        banMode = false
        SpellChoiceBanButton:SetText("Ban")
        UpdateRerollButton()
        Debug("[Ban] Ban mode reset on re-toggle")

        -- Restore full UI state
        if lastSpellIDs and #lastSpellIDs > 0 then
        local target = UnitName("player")
        if target then
          SendChatMessage("SC_CHECK", "WHISPER", GetFactionLanguage(), target)
          Debug("[Ban] Re-requested banned spell list before restoring UI.")
        end

        restoringFromDismiss = true
        Delay(0.2, function()
          ShowSpellChoices(lastSpellIDs)
          restoringFromDismiss = false
        end)
      end

        SpellChoiceFrame:EnableMouse(true)
        SpellChoiceFrame:SetAlpha(1)
        SpellChoiceFrame:Show()

        for _, btn in ipairs(buttons) do
            btn:EnableMouse(true)
            btn:Show()

            btn:SetScript("OnEnter", function(self)
                local spellID = self:GetID()
                if spellID and spellID > 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                    GameTooltip:SetHyperlink("spell:" .. spellID)
                    GameTooltip:Show()
                end
            end)

            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            btn:SetScript("OnClick", HandleSpellClick)
        end

        SpellChoiceTitle:Show()
        SpellChoiceRerollButton:Show()

        self:SetParent(SpellChoiceFrame)
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", SpellChoiceTitle, "TOP", 0, -290)
    end
end)





--------------------------------------------------------------------------------
-- Multi-Resource HUD programmatically generated below
--------------------------------------------------------------------------------

local hudFrame = CreateFrame("Frame", "SpellDraftHUD", UIParent)
hudFrame:SetWidth(119)
hudFrame:SetHeight(45)

local function PositionHUD()
    hudFrame:ClearAllPoints()
    hudFrame:SetPoint("BOTTOMLEFT", PlayerFrameHealthBar, "TOPLEFT", 5, 3)
end

local blizzardFramesDirty = false
local function RepositionBlizzardFrames()
    if InCombatLockdown() then
        blizzardFramesDirty = true
        return
    end

    blizzardFramesDirty = false

    -- 1. Druid Mana Bar
    if PlayerFrameDruidManaBar then
        local maxMana = UnitPowerMax("player", 0)
        if showHUD and maxMana and maxMana > 0 then
            if not PlayerFrameDruidManaBar:IsShown() then
                PlayerFrameDruidManaBar:Show()
            end
            local _, class = UnitClass("player")
            if class == "WARRIOR" then
                PlayerFrameDruidManaBar:ClearAllPoints()
                PlayerFrameDruidManaBar:SetPoint("TOPLEFT", PlayerFrameManaBar, "BOTTOMLEFT", 0, -1)
                PlayerFrameDruidManaBar:SetWidth(119)
                PlayerFrameDruidManaBar:SetHeight(10)
                
                -- Force standard textures, colors, and values
                PlayerFrameDruidManaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                PlayerFrameDruidManaBar:SetStatusBarColor(0, 0.4, 1)
                
                -- Style background
                local bg = _G["PlayerFrameDruidManaBarBG"] or PlayerFrameDruidManaBar.bg
                if bg then
                    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    bg:SetVertexColor(0, 0.08, 0.2, 0.6)
                end
            end
        else
            if PlayerFrameDruidManaBar:IsShown() then
                PlayerFrameDruidManaBar:Hide()
            end
        end
    end

    -- 2. Pet Frame
    if PetFrame and PetFrame:IsShown() then
        PetFrame:ClearAllPoints()
        local maxMana = PlayerFrameDruidManaBar and UnitPowerMax("player", 0) or 0
        if showHUD and maxMana > 0 then
            PetFrame:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 80, -14)
        else
            PetFrame:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 80, -4)
        end
    end

    -- 3. Rune Frame
    if RuneFrame and RuneFrame:IsShown() then
        RuneFrame:ClearAllPoints()
        RuneFrame:SetPoint("TOP", PlayerFrameManaBar, "BOTTOM", 0, -16)
    end
end

local function CreateHUDBar(colorR, colorG, colorB, name)
    local bar = CreateFrame("StatusBar", "SpellDraftHUD_" .. name, hudFrame)
    
    if name == "Energy" then
        bar:SetWidth(113)
        bar:SetHeight(12)
        bar:SetStatusBarTexture("Interface\\AddOns\\SpellDraft\\Textures\\energy_fill.tga")
        bar:SetStatusBarColor(1, 1, 1) -- White so texture's native yellow shows through
        
        -- Custom border overlay with rounded corners
        local border = bar:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\AddOns\\SpellDraft\\Textures\\energy_border.tga")
        border:SetAllPoints(bar)
        
        -- Solid black base (rounded via the bg texture on top)
        local bgSolid = bar:CreateTexture(nil, "BACKGROUND")
        bgSolid:SetAllPoints(bar)
        bgSolid:SetTexture("Interface\\AddOns\\SpellDraft\\Textures\\energy_bg.tga")
        bgSolid:SetVertexColor(0, 0, 0, 1)
        
        -- Tinted background layer with rounded texture
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
        bg:SetTexture("Interface\\AddOns\\SpellDraft\\Textures\\energy_bg.tga")
        bg:SetAllPoints(bar)
        bg:SetVertexColor(0.3, 0.3, 0, 1)
    else
        bar:SetWidth(119)
        bar:SetHeight(12)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(colorR, colorG, colorB)
        
        -- Black 1-pixel outer border to match default nameplate/player frame style
        local border = bar:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        border:SetTexture("Interface\\Buttons\\WHITE8x8")
        border:SetVertexColor(0, 0, 0, 0.9)
        
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
        bg:SetAllPoints(bar)
        bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bg:SetVertexColor(colorR * 0.2, colorG * 0.2, colorB * 0.2, 0.6)
    end

    local text = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    
    -- Mouseover tooltip showing resource name (like native Mana/Health/Rage)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(name, colorR, colorG, colorB)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    bar.text = text
    bar:Hide()
    return bar
end

-- Create horizontal bars (Mana, Rage, Energy)
local manaBar = CreateHUDBar(0, 0.4, 1, "Mana")
local rageBar = CreateHUDBar(1, 0, 0, "Rage")
local energyBar = CreateHUDBar(1, 1, 0, "Energy")

-- Create vertical Runic Power bar (anchored to right side of player frame)
local runicFrame = CreateFrame("Frame", "SpellDraftRunicFrame", UIParent)
runicFrame:SetWidth(8)
runicFrame:SetHeight(42)

local runicBar = CreateFrame("StatusBar", "SpellDraftHUD_RunicPower", runicFrame)
runicBar:SetWidth(6)
runicBar:SetHeight(38)
runicBar:SetOrientation("VERTICAL")
runicBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
runicBar:SetStatusBarColor(0, 0.82, 1)
runicBar:SetPoint("CENTER", runicFrame, "CENTER", 0, 0)

-- Rounded dark border for the vertical bar
local runicBorder = runicFrame:CreateTexture(nil, "BACKGROUND")
runicBorder:SetPoint("TOPLEFT", runicFrame, "TOPLEFT", 0, 0)
runicBorder:SetPoint("BOTTOMRIGHT", runicFrame, "BOTTOMRIGHT", 0, 0)
runicBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
runicBorder:SetVertexColor(0.38, 0.38, 0.42, 1)

-- Dark tinted background inside the bar
local runicBg = runicBar:CreateTexture(nil, "BACKGROUND")
runicBg:SetAllPoints(runicBar)
runicBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
runicBg:SetVertexColor(0, 0.12, 0.18, 1)

-- Top rounded cap
local runicCapTop = runicFrame:CreateTexture(nil, "OVERLAY")
runicCapTop:SetTexture("Interface\\Buttons\\WHITE8x8")
runicCapTop:SetVertexColor(0.38, 0.38, 0.42, 1)
runicCapTop:SetWidth(8)
runicCapTop:SetHeight(1)
runicCapTop:SetPoint("TOP", runicFrame, "TOP", 0, 1)

-- Bottom rounded cap
local runicCapBot = runicFrame:CreateTexture(nil, "OVERLAY")
runicCapBot:SetTexture("Interface\\Buttons\\WHITE8x8")
runicCapBot:SetVertexColor(0.38, 0.38, 0.42, 1)
runicCapBot:SetWidth(8)
runicCapBot:SetHeight(1)
runicCapBot:SetPoint("BOTTOM", runicFrame, "BOTTOM", 0, -1)

-- Mouseover tooltip for runic bar
runicFrame:EnableMouse(true)
runicFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Runic Power", 0, 0.82, 1)
    local cur = UnitPower("player", 6)
    local max = UnitPowerMax("player", 6)
    GameTooltip:AddLine(cur .. " / " .. max, 1, 1, 1)
    GameTooltip:Show()
end)
runicFrame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

runicBar:Hide()
runicFrame:Hide()

-- Hook native secondary mana bar's Hide function to block the client from hiding it for Warriors
if PlayerFrameDruidManaBar then
    hooksecurefunc(PlayerFrameDruidManaBar, "Hide", function(self)
        if showHUD and not InCombatLockdown() then
            local maxMana = UnitPowerMax("player", 0)
            if maxMana and maxMana > 0 then
                self:Show()
                RepositionBlizzardFrames()
            end
        end
    end)
end

showHUD = true -- Enabled by default

function SpellDraft.UpdateHUD()
    if not showHUD then
        manaBar:Hide()
        rageBar:Hide()
        energyBar:Hide()
        runicBar:Hide()
        runicFrame:Hide()
        hudFrame:Hide()
        return
    end

    hudFrame:Show()
    PositionHUD()

    local nativePower = UnitPowerType("player")
    local _, playerClass = UnitClass("player")

    -- The "druid style" third mana bar is drawn by the client engine, which
    -- only triggers it for non-rage power types (energy/runic), so it never
    -- appears for Warriors (rage). For Warriors ONLY, show our own custom mana
    -- bar under the native power bar to mimic that third-bar layout. Every other
    -- class keeps using the engine's native secondary mana bar.
    if playerClass == "WARRIOR" then
        local maxMana = UnitPowerMax("player", 0)
        if maxMana and maxMana > 0 then
            local curMana = UnitPower("player", 0)
            manaBar:SetMinMaxValues(0, maxMana)
            manaBar:SetValue(curMana)
            manaBar.text:SetText(curMana .. " / " .. maxMana)
            manaBar:ClearAllPoints()
            -- Anchor directly beneath the native power bar (the rage bar for Warriors)
            manaBar:SetPoint("TOPLEFT", PlayerFrameManaBar, "BOTTOMLEFT", 0, -2)
            manaBar:Show()
        else
            manaBar:Hide()
        end
    else
        manaBar:Hide()
    end
    
    local hasRage = false
    local hasEnergy = false
    
    -- Update Rage bar
    if nativePower ~= 1 then
        local maxRage = UnitPowerMax("player", 1)
        if maxRage > 0 then
            local currentRage = UnitPower("player", 1)
            rageBar:SetMinMaxValues(0, maxRage)
            rageBar:SetValue(currentRage)
            rageBar.text:SetText(currentRage .. " / " .. maxRage)
            hasRage = true
        else
            rageBar:Hide()
        end
    else
        rageBar:Hide()
    end
    
    -- Update Energy bar
    if nativePower ~= 3 then
        local maxEnergy = UnitPowerMax("player", 3)
        if maxEnergy > 0 then
            local currentEnergy = UnitPower("player", 3)
            energyBar:SetMinMaxValues(0, maxEnergy)
            energyBar:SetValue(currentEnergy)
            energyBar.text:SetText(currentEnergy .. " / " .. maxEnergy)
            hasEnergy = true
        else
            energyBar:Hide()
        end
    else
        energyBar:Hide()
    end

    -- Update Runic Power bar (vertical, right side of nameplate)
    if nativePower ~= 6 then
        local maxRunic = UnitPowerMax("player", 6)
        if maxRunic > 0 then
            local currentRunic = UnitPower("player", 6)
            runicBar:SetMinMaxValues(0, maxRunic)
            runicBar:SetValue(currentRunic)
            runicFrame:ClearAllPoints()
            runicFrame:SetPoint("RIGHT", PlayerFrameHealthBar, "RIGHT", 14, 2)
            runicBar:Show()
            runicFrame:Show()
        else
            runicBar:Hide()
            runicFrame:Hide()
        end
    else
        runicBar:Hide()
        runicFrame:Hide()
    end

    -- Stack horizontal bars vertically upwards
    local lastBar = nil
    if hasEnergy then
        energyBar:ClearAllPoints()
        energyBar:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 0, 0)
        energyBar:Show()
        lastBar = energyBar
    end
    if hasRage then
        rageBar:ClearAllPoints()
        if lastBar then
            rageBar:SetPoint("BOTTOMLEFT", lastBar, "TOPLEFT", 0, 2)
        else
            rageBar:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 0, 0)
        end
        rageBar:Show()
        lastBar = rageBar
    end

    -- Show/Hide the native secondary mana bar safely (only outside combat)
    if PlayerFrameDruidManaBar and not InCombatLockdown() then
        local maxMana = UnitPowerMax("player", 0)
        if maxMana > 0 then
            if not PlayerFrameDruidManaBar:IsShown() then
                PlayerFrameDruidManaBar:Show()
                blizzardFramesDirty = true
            end
        else
            if PlayerFrameDruidManaBar:IsShown() then
                PlayerFrameDruidManaBar:Hide()
                blizzardFramesDirty = true
            end
        end
    end

    -- Update Druid Mana Bar values (safe, doesn't modify frame points/dimensions)
    if PlayerFrameDruidManaBar then
        local maxMana = UnitPowerMax("player", 0)
        if maxMana > 0 then
            local _, class = UnitClass("player")
            if class == "WARRIOR" then
                local cur = UnitPower("player", 0)
                local max = UnitPowerMax("player", 0)
                PlayerFrameDruidManaBar:SetMinMaxValues(0, max)
                PlayerFrameDruidManaBar:SetValue(cur)
            end
        end
    end

    -- Safe periodic reposition retry outside combat
    if blizzardFramesDirty or not InCombatLockdown() then
        RepositionBlizzardFrames()
    end
end

hudFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hudFrame:RegisterEvent("PLAYER_LEVEL_UP")
hudFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
hudFrame:RegisterEvent("PET_UI_UPDATE")
hudFrame:RegisterEvent("UNIT_PET")
hudFrame:RegisterEvent("PLAYER_PET_CHANGED")
hudFrame:RegisterEvent("UNIT_MAXPOWER")
hudFrame:RegisterEvent("UNIT_POWER")

hudFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if blizzardFramesDirty then
            RepositionBlizzardFrames()
        end
    elseif event == "UNIT_POWER" or event == "UNIT_MAXPOWER" then
        if unit == "player" then
            RepositionBlizzardFrames()
            SpellDraft.UpdateHUD()
        end
    elseif event == "PET_UI_UPDATE" or event == "UNIT_PET" or event == "PLAYER_PET_CHANGED" then
        RepositionBlizzardFrames()
    elseif event == "PLAYER_ENTERING_WORLD" then
        RepositionBlizzardFrames()
        SpellDraft.UpdateHUD()
    else
        SpellDraft.UpdateHUD()
    end
end)

local lastHUDUpdate = 0
hudFrame:SetScript("OnUpdate", function(self, elapsed)
    lastHUDUpdate = lastHUDUpdate + elapsed
    if lastHUDUpdate >= 0.2 then
        lastHUDUpdate = 0
        SpellDraft.UpdateHUD()
    end
end)

SLASH_SDHUD1 = "/sdhud"
SlashCmdList["SDHUD"] = function()
    showHUD = not showHUD
    if SpellDraftDB then
        SpellDraftDB.showHUD = showHUD
    end
    if not InCombatLockdown() then
        RepositionBlizzardFrames()
    else
        blizzardFramesDirty = true
    end
    SpellDraft.UpdateHUD()
    if showHUD then
        print("|cff00ccff[SpellDraft]|r Floating HUD enabled.")
    else
        print("|cff00ccff[SpellDraft]|r Floating HUD disabled.")
    end
end