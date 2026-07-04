-- Playerbots must never enter the draft/prestige system.
local function IsBotPlayer(player)
  return player.IsBot ~= nil and player:IsBot()
end

-- Check draft mode from CharDB
local function IsInDraftMode(player)
  if IsBotPlayer(player) then return false end
  local guid = player:GetGUIDLow()
  local result = CharDBQuery("SELECT draft_state FROM prestige_stats WHERE player_id = " .. guid)
  return result and result:GetUInt32(0) == 1
end

-- On login: Reset talents immediately if in draft
RegisterPlayerEvent(3, function(_, player)
  if IsInDraftMode(player) then
    player:ResetTalents(true)
    player:SetFreeTalentPoints(0)
  end
end)

-- On level up: delay the reset 100ms
RegisterPlayerEvent(13, function(_, player, oldLevel)
  if IsInDraftMode(player) then
    local pGUID = player:GetGUIDLow()
    CreateLuaEvent(function()
      local p = GetPlayerByGUID(pGUID)
      if p then
        p:SetFreeTalentPoints(0)
      end
    end, 100, 1)
  end
end)

-- On spell learn: extra safety
RegisterPlayerEvent(44, function(_, player, spellId)
  if IsInDraftMode(player) then
    local pGUID = player:GetGUIDLow()
    CreateLuaEvent(function()
      local p = GetPlayerByGUID(pGUID)
      if p then
        p:SetFreeTalentPoints(0)
      end
    end, 100, 1)
  end
end)
