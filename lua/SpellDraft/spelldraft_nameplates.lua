-- Playerbots must never enter the draft/prestige system.
local function IsBotPlayer(player)
    return player.IsBot ~= nil and player:IsBot()
end

local prestigeCache = {}

-- Initialize cache for already online players (e.g. on hot-reload)
local onlinePlayers = GetPlayersInWorld()
if onlinePlayers then
    for _, p in ipairs(onlinePlayers) do
        if not IsBotPlayer(p) then
            local guid = p:GetGUIDLow()
            local results = CharDBQuery("SELECT prestige_level FROM prestige_stats WHERE player_id = " .. guid)
            local level = 0
            if results then
                level = results:GetUInt32(0)
            end
            prestigeCache[guid] = level
        end
    end
end

-- Global setter called when a player's prestige level changes
function SpellDraft_SetPrestigeCache(guid, level)
    prestigeCache[guid] = level
end

-- Send prestige level to nearby players and to self
local function SendPrestigeToNearbyPlayers(player)
    if IsBotPlayer(player) or not player:IsInWorld() then
        return
    end

    local guid = player:GetGUIDLow()
    local name = player:GetName()

    local prestige = prestigeCache[guid] or 0
    local message = name .. ":" .. prestige

    -- Send to the player themselves (exactly once)
    player:SendAddonMessage("PRESTIGE", message, 0, player)

    -- Then send to nearby players, and also send their prestige levels back to player
    local nearbyPlayers = player:GetPlayersInRange(100)
    for _, target in ipairs(nearbyPlayers) do
        if target ~= player and not IsBotPlayer(target) then
            -- Send player's level to target
            target:SendAddonMessage("PRESTIGE", message, 0, target)
            
            -- Send target's level back to player
            local targetGuid = target:GetGUIDLow()
            local targetPrestige = prestigeCache[targetGuid] or 0
            player:SendAddonMessage("PRESTIGE", target:GetName() .. ":" .. targetPrestige, 0, player)
        end
    end
end

-- Hooks to trigger prestige broadcast
local function OnLogin(event, player)
    if IsBotPlayer(player) then return end
    local guid = player:GetGUIDLow()
    local results = CharDBQuery("SELECT prestige_level FROM prestige_stats WHERE player_id = " .. guid)
    local level = 0
    if results then
        level = results:GetUInt32(0)
    end
    prestigeCache[guid] = level

    SendPrestigeToNearbyPlayers(player)
end

local function OnLogout(event, player)
    if IsBotPlayer(player) then return end
    local guid = player:GetGUIDLow()
    prestigeCache[guid] = nil
end

local function OnMapChange(event, player)
    SendPrestigeToNearbyPlayers(player)
end

local function OnZoneUpdate(event, player)
    SendPrestigeToNearbyPlayers(player)
end

-- Register events
RegisterPlayerEvent(3, OnLogin)           -- EVENT_ON_LOGIN
RegisterPlayerEvent(4, OnLogout)          -- EVENT_ON_LOGOUT
RegisterPlayerEvent(27, OnZoneUpdate)     -- EVENT_ON_UPDATE_ZONE
RegisterPlayerEvent(28, OnMapChange)      -- EVENT_ON_MAP_CHANGE
