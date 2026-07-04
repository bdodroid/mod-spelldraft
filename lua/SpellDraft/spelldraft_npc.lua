local scriptPath = debug.getinfo(1).source:sub(2)
local parentPath = scriptPath:match("(.+[/\\])") or ""
local rootPath = parentPath:match("(.+[/\\])[^/\\]+[/\\]$") or parentPath
dofile(rootPath .. "spelldraft_config.lua")
local NPC_ID = CONFIG.NPC_ID
local MAX_LEVEL = CONFIG.MAX_LEVEL
local DRAFT_MODE_REROLLS = CONFIG.DRAFT_MODE_REROLLS 
local DRAFT_MODE_SPELLS = CONFIG.DRAFT_MODE_SPELLS
local DRAFT_BANS_START = CONFIG.DRAFT_BANS_START
local prestigeDescription = CONFIG.prestigeDescription
local prestigeBlockedMessage = CONFIG.prestigeBlockedMessage
local prestigeLossList = CONFIG.prestigeLossList


local LOGOUT_TIMER = 10 -- time in seconds to wait after sending back to start before logging out to finish process.
local LOGOUT_AFTER_PRESTIGE_TIMER = LOGOUT_TIMER * 1000
local EQUIP_SLOT_START = 0
local EQUIP_SLOT_END = 18
local MAIL_SUBJECT = "Your Returned Gear [Prestige]"
local MAIL_BODY = "Your equipped gear has been returned to you after prestiging."
local RED = "|cffff0000"
local YELLOW = "|cffffff00"
local WHITE = "|cffffffff"
local startingGear = CONFIG.startingGear



local function ResetPlayerQuests(guid, class)
    local dkQuests = {}
    local dkQuestQ = WorldDBQuery("SELECT ID FROM quest_template WHERE QuestSortID = -372 AND ID NOT IN (13188, 13189)")
    if dkQuestQ then
        repeat
            table.insert(dkQuests, dkQuestQ:GetUInt32(0))
        until not dkQuestQ:NextRow()
    end

    local dkQuestStr = table.concat(dkQuests, ",")

    if class == 6 and #dkQuests > 0 then
        CharDBExecute("DELETE FROM character_queststatus WHERE guid = " .. guid .. " AND quest NOT IN (" .. dkQuestStr .. ")")
        CharDBExecute("DELETE FROM character_queststatus_rewarded WHERE guid = " .. guid .. " AND quest NOT IN (" .. dkQuestStr .. ")")
    else
        CharDBExecute("DELETE FROM character_queststatus WHERE guid = " .. guid)
        CharDBExecute("DELETE FROM character_queststatus_rewarded WHERE guid = " .. guid)
    end
    CharDBExecute("DELETE FROM character_queststatus_daily WHERE guid = " .. guid)
    CharDBExecute("DELETE FROM character_queststatus_weekly WHERE guid = " .. guid)
    CharDBExecute("DELETE FROM character_queststatus_seasonal WHERE guid = " .. guid)
    CharDBExecute("DELETE FROM character_queststatus_monthly WHERE guid = " .. guid)
end


local function UpdateClassAfterLogout(guid, newClass)
    local ticks = 0
    local maxTicks = 15
    local eventId

    eventId = CreateLuaEvent(function(evId)
        local actualEvId = evId or eventId
        ticks = ticks + 1

        local online = 1
        local q = CharDBQuery("SELECT online FROM characters WHERE guid = " .. guid)
        if q then
            online = q:GetUInt32(0)
        end

        local p = GetPlayerByGUID(guid)

        if (p == nil and online == 0) or ticks >= maxTicks then
            if ticks >= maxTicks and (p ~= nil or online ~= 0) then
                print(string.format("[Prestige] WARNING: UpdateClassAfterLogout safety cap hit for player guid %d (online state: %s). Forcing class swap to %d.", guid, tostring(online), newClass))
            end

            CharDBExecute(string.format("UPDATE characters SET class = %d WHERE guid = %d", newClass, guid))

            if actualEvId then
                RemoveEventById(actualEvId)
            end
        end
    end, 2000, 0)
end




local function GetStoredClass(player)
    local guid = player:GetGUIDLow()
    local result = CharDBQuery("SELECT stored_class FROM prestige_stats WHERE player_id = " .. guid)
    if result then
        local storedClass = result:GetUInt8(0)
        return storedClass
    else
        return nil -- not found
    end
end

local function GiveStartingGear(player)
    local race = player:GetRace()
    local class = GetStoredClass(player)

    local raceNames = {
        [1] = "HUMAN",
        [2] = "ORC",
        [3] = "DWARF",
        [4] = "NIGHTELF",
        [5] = "UNDEAD",
        [6] = "TAUREN",
        [7] = "GNOME",
        [8] = "TROLL",
        [10] = "BLOODELF",
        [11] = "DRAENEI",
    }

    local classNames = {
        [1]  = "WARRIOR",
        [2]  = "PALADIN",
        [3]  = "HUNTER",
        [4]  = "ROGUE",
        [5]  = "PRIEST",
        [6]  = "DEATHKNIGHT",
        [7]  = "SHAMAN",
        [8]  = "MAGE",
        [9]  = "WARLOCK",
        [11] = "DRUID",
    }

    local raceName = raceNames[race]
    local className = classNames[class]

    local key
    if class == 6 then -- Death Knight
        key = "DEATHKNIGHT"
    elseif raceName and className then
        key = raceName .. "_" .. className
    end

    local items = key and startingGear[key]
    if not items and className then
        -- Fall back to another race of the same faction with the same class
        local isAlliance = (race == 1 or race == 3 or race == 4 or race == 7 or race == 11)
        local fallbackRaces
        if isAlliance then
            fallbackRaces = {"HUMAN", "DWARF", "NIGHTELF", "GNOME", "DRAENEI"}
        else
            fallbackRaces = {"ORC", "TROLL", "TAUREN", "UNDEAD", "BLOODELF"}
        end
        for _, rName in ipairs(fallbackRaces) do
            local fbKey = rName .. "_" .. className
            if startingGear[fbKey] then
                key = fbKey
                items = startingGear[fbKey]
                break
            end
        end
    end

    if not items then
        player:SendBroadcastMessage("Starting gear not found for your race and class.")
        return
    end

    for slotID, itemID in pairs(items) do
        local count = 1
        if itemID == 2512 or itemID == 2516 then
            count = 200
        end

        local item = player:AddItem(itemID, count)
        if item and count == 1 then
            player:EquipItem(itemID, slotID)
        end
    end
    player:SendBroadcastMessage("Your starting gear has been equipped.")
end






local function GetLossListText()
    return "The following will be removed when you prestige:\n\n" .. table.concat(prestigeLossList, "\n")
end

local EQUIPPED_SLOTS = {
    0,  -- HEAD
    1,  -- NECK
    2,  -- SHOULDERS
    3,  -- BODY (shirt)
    4,  -- CHEST
    5,  -- WAIST
    6,  -- LEGS
    7,  -- FEET
    8,  -- WRISTS
    9,  -- HANDS
    10, -- FINGER1
    11, -- FINGER2
    12, -- TRINKET1
    13, -- TRINKET2
    14, -- BACK
    15, -- MAIN HAND
    16, -- OFF HAND
    17, -- RANGED/RELIC
    18, -- TABARD
}

local function RemoveAndMailEquippedItems(player)
    local itemsSent = false
    local receiverGuid = player:GetGUIDLow()
    local senderGuid = player:GetGUIDLow()

    for _, slot in ipairs(EQUIPPED_SLOTS) do
        local item = player:GetEquippedItemBySlot(slot)
        if item then
            local entry = item:GetEntry()
            local count = item:GetCount()
            if type(SendMail) == "function" then
                SendMail(MAIL_SUBJECT, MAIL_BODY, senderGuid, receiverGuid, 61, 0, 0, 0, entry, count)
            end
            player:RemoveItem(entry, count)
            itemsSent = true
        end
    end

    if itemsSent then
        player:SendBroadcastMessage("Your equipped items have been mailed to you.")
    end
end


-- Menus
local function ShowMainMenu(player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_QuestionMark:20|t |cffffff00What is Prestige?", 1, 1)
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\Achievement_BG_winAB:20|t |cff3399ffI would like to Prestige!", 1, 2)
    local guid = player:GetGUIDLow()
    local result = CharDBQuery("SELECT draft_state FROM prestige_stats WHERE player_id = " .. guid)
    if result and result:GetUInt32(0) == 1 then
        player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_Gear_01:20|t |cff66ff66Show My Draft Stats", 1, 300)
        player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_Head_Human_01:20|t " .. RED .. "I want to QUIT DRAFT", 1, 200)
    end

    -- Exit
    player:GossipMenuAddItem(0, "Goodbye", 1, 999)

    player:GossipSendMenu(1, creature)
end

local function ShowPrestigeInfo(player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(0, prestigeDescription, 1, 998)
    player:GossipMenuAddItem(0, "Back", 1, 0)
    player:GossipSendMenu(1, creature)
end

local function ShowPrestigeOptions(player, creature)
    player:GossipClearMenu()
    local guid = player:GetGUIDLow()
    if player:GetLevel() < MAX_LEVEL then
        player:GossipMenuAddItem(0, prestigeBlockedMessage, 1, 998)
    else
        player:GossipMenuAddItem(4, GetLossListText(), 1, 998)
        player:GossipMenuAddItem(9, RED .. "Prestige", 1, 3)
        player:GossipMenuAddItem(9, RED .. "Prestige into Draft Mode", 1, 4)
    end
    player:GossipMenuAddItem(0, "Back", 1, 0)
    player:GossipSendMenu(1, creature)
end

local function ShowConfirmation(player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_Bag_10:20|t Prestige requires 10 free inventory slots", 1, 998)
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\Ability_Hunter_BeastCall:20|t Prestige requires no active pet. Dismiss your pet if you have one", 1, 998)

    player:GossipMenuAddItem(0, "", 1, 998) -- Spacer
    player:GossipMenuAddItem(9, RED .. "I am sure I want to Prestige!", 1, 100)
    player:GossipMenuAddItem(0, "Back", 1, 2)
    player:GossipSendMenu(1, creature)
end
local function ShowDraftConfirmation(player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_Bag_10:20|t Prestige requires 10 free inventory slots", 1, 998)
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\Ability_Hunter_BeastCall:20|t Prestige requires no active pet. Dismiss your pet if you have one", 1, 998)
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Scroll_11:20|t Prestige Draft requires the Patch-P and SpellDraft Addon", 1, 998)
    player:GossipMenuAddItem(0, "", 1, 998) -- Spacer
    player:GossipMenuAddItem(9, RED .. "I am sure I want to Prestige into Draft Mode!", 1, 101)
    player:GossipMenuAddItem(0, "Back", 1, 2)
    player:GossipSendMenu(1, creature)
end
local function ShowEndDraftConfirmation(player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_QuestionMark:20|t This will reset your character as if you prestiged, but without increasing your prestige level.", 1, 998)
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\Ability_Hunter_BeastCall:20|t This Process requires no active pet. Dismiss your pet if you have one", 1, 998)
    player:GossipMenuAddItem(0, "", 1, 998) -- Spacer
    player:GossipMenuAddItem(9, RED .. "I am sure I want to end Drafting.", 1, 201)
    player:GossipMenuAddItem(0, "Back", 1, 0)
    player:GossipSendMenu(1, creature)
end
-- Gossip handler
local function OnGossipHello(event, player, creature)
    ShowMainMenu(player, creature)
end

local function DeleteAllPlayerPets(playerGUID)
    local petResults = CharDBQuery("SELECT id FROM character_pet WHERE owner = " .. playerGUID)
    if not petResults then
        return
    end

    repeat
        local petGuid = petResults:GetUInt32(0)
        CharDBExecute("DELETE FROM pet_spell WHERE guid = " .. petGuid)
        CharDBExecute("DELETE FROM character_pet WHERE id = " .. petGuid)
        CharDBExecute("DELETE FROM pet_aura WHERE guid = " .. petGuid)
        CharDBExecute("DELETE FROM pet_spell_cooldown WHERE guid = " .. petGuid)
    until not petResults:NextRow()
end


local function DoPrestige(player, draftMode)
    local guid = player:GetGUIDLow()
    local requiredSlots = 10
    local freeSlots = 0
    local foundEnough = false


            for bag = 0, 4 do
                local bagSize = 16
                local skipBag = false
                local container = 255  -- Use 255 for virtual inventory (backpack, equipment, etc.)

                if bag == 0 then
                    -- Backpack occupies slot 23–38 in container 255
                    bagSize = 16

                else
                    local bagItem = player:GetItemByPos(255, 18 + bag)
                    if not bagItem then

                        skipBag = true
                    else
                        local entry = bagItem:GetEntry()
                        local result = WorldDBQuery("SELECT class, subclass FROM item_template WHERE entry = " .. entry)
                        if not result then

                            skipBag = true
                        else
                            local class = result:GetUInt8(0)
                            local subclass = result:GetUInt8(1)


                            if (class == 1 and (subclass == 2 or subclass == 3)) or class == 11 then

                                skipBag = true
                            else
                                bagSize = bagItem:GetBagSize()
                                container = 18 + bag  -- Use slot index, NOT GUID

                            end
                        end
                    end
                end

                if not skipBag then
                    for slot = 0, bagSize - 1 do
                        local item

                        if bag == 0 then
                            -- Backpack check: actual slots are 23–38
                            item = player:GetItemByPos(255, 23 + slot)
                        else
                            -- Normal bag check
                            item = player:GetItemByPos(container, slot)
                        end



                        if not item then
                            freeSlots = freeSlots + 1

                            if freeSlots >= requiredSlots then
                                foundEnough = true

                                break
                            end
                        end
                    end
                end

                if foundEnough then break end
            end

            -- Final evaluation
            if freeSlots < requiredSlots then
                player:SendBroadcastMessage("You need at least " .. requiredSlots .. " free bag slots to Prestige.")
                return
            end


    -- Draft mode only:
    if draftMode then
        player:SendBroadcastMessage("Draft Mode: Enabled for next run.")


        -- Recalculate current prestige level after increment (safe fallback)
        local prestigeLevel = 1
        local q = CharDBQuery("SELECT prestige_level FROM prestige_stats WHERE player_id = " .. guid)
        if q then
            prestigeLevel = q:GetUInt32(0)
        end

        -- Calculate rerolls for this prestige level:
        -- Prestige 1: PRESTIGE1_REROLLS (5)
        -- Prestige 2+: +PRESTIGE_REROLL_SCALING (2) per level beyond 1
        local bonusRerolls
        if prestigeLevel <= 0 then
            bonusRerolls = DRAFT_MODE_REROLLS -- fallback (shouldn't happen during prestige)
        else
            bonusRerolls = CONFIG.PRESTIGE1_REROLLS + CONFIG.PRESTIGE_REROLL_SCALING * (prestigeLevel - 1)
        end

        -- Determine original class safely
        local storedClass = player:GetClass()
        local storedQuery = CharDBQuery("SELECT stored_class FROM prestige_stats WHERE player_id = " .. guid)
        if storedQuery and storedQuery:GetUInt8(0) > 0 then
            storedClass = storedQuery:GetUInt8(0)  -- Keep existing non-zero value
        end

        local startingDrafts = (storedClass == 6) and 5 or DRAFT_MODE_SPELLS
        local updateStatsQuery = string.format([[
            UPDATE prestige_stats
            SET draft_state = 1,
                successful_drafts = 0,
                total_expected_drafts = %d,
                rerolls = %d,
                stored_class = %d,
                bans = %d,
                bonus_drafts = 0,
                offered_spell_1 = 0,
                offered_spell_2 = 0,
                offered_spell_3 = 0
            WHERE player_id = %d
        ]], startingDrafts, bonusRerolls, storedClass, DRAFT_BANS_START, guid)

        CharDBExecute(updateStatsQuery)
        if type(SpellDraft_SetDraftStateCache) == "function" then
            SpellDraft_SetDraftStateCache(guid, 1)
        end

        local perLevel = CONFIG.PRESTIGE1_REROLLS_PER_LEVEL + CONFIG.PRESTIGE_REROLL_SCALING * (prestigeLevel - 1)
        player:SendBroadcastMessage("Draft rerolls granted: " .. bonusRerolls .. " (+" .. perLevel .. " per level)")
    end
    RemoveAndMailEquippedItems(player)
    player:SetLevel(player:GetClass() == 6 and 55 or 1)
    GiveStartingGear(player)

    local name = player:GetName()
    local newPrestige = 1
    local q = CharDBQuery("SELECT prestige_level FROM prestige_stats WHERE player_id = " .. guid)
    if q then
        local currentPrestige = q:GetUInt32(0)
        newPrestige = currentPrestige + 1
        CharDBExecute("UPDATE prestige_stats SET prestige_level = " .. newPrestige .. " WHERE player_id = " .. guid)
    else
        CharDBExecute("INSERT INTO prestige_stats (player_id, prestige_level) VALUES (" .. guid .. ", 1)")
    end

    if type(SpellDraft_SetPrestigeCache) == "function" then
        SpellDraft_SetPrestigeCache(guid, newPrestige)
    end

    SendWorldMessage("|cffff8800[Prestige]|r Player |cffffff00" .. name .. "|r has prestiged! New Prestige Level: |cff00ff00" .. newPrestige .. "|r")
    player:SendBroadcastMessage("|cffff0000You have prestiged!|r Your level has been reset to 1.")
    player:SendBroadcastMessage("You will be logged out in " .. LOGOUT_TIMER ..  " seconds to complete the prestige process.")
    player:GossipComplete()

    -- Actionbar, spell, quest wipes
    CharDBExecute("DELETE FROM character_action WHERE guid = " .. guid)
    CharDBExecute("DELETE FROM character_spell WHERE guid = " .. guid)
    local result = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid)
    -- if result then
    --     repeat
    --         local spellId = result:GetUInt32(0)
    --         player:RemoveSpell(spellId)
    --     until not result:NextRow()
    -- end
    CharDBExecute("DELETE FROM drafted_spells WHERE player_guid = " .. guid)
    ResetPlayerQuests(guid, player:GetClass())
    DeleteAllPlayerPets(guid)

    -- Teleport and logout
    CreateLuaEvent(function()
        local plr = GetPlayerByGUID(guid)
        if not plr then return end

        local raceStartLocations = {
            [1]  = {map = 0,   x = -8949.95,  y = -132.493, z = 83.5312,   o = 3.142},
            [2]  = {map = 1,   x = -618.518,  y = -4251.67, z = 38.718,    o = 6.2},
            [3]  = {map = 0,   x = -6240.32,  y = 331.033,  z = 382.757,   o = 5.2},
            [4]  = {map = 1,   x = 10311.3,   y = 832.463,  z = 1326.41,   o = 5.7},
            [5]  = {map = 0,   x = 1676.35,   y = 1678.68,  z = 121.67,    o = 1.6},
            [6]  = {map = 1,   x = -2917.58,  y = -257.98,  z = 52.9968,   o = 0.0},
            [7]  = {map = 0,   x = -6240.95,  y = 331.493, z = 382.5312,   o = 5.2},
            [8]  = {map = 1,   x = -618.518,  y = -4251.67, z = 38.718,    o = 6.2},
            [10] = {map = 530, x = 10349.6,   y = -6357.29, z = 33.4026,   o = 5.3},
            [11] = {map = 530, x = -3961.64,  y = -13931.2, z = 100.615,   o = 2.08},
        }

        local dkAllianceStart = {map = 0, x = -8354.2, y = 334.3, z = 121.0, o = 3.6} -- Stormwind Gates
        local dkHordeStart = {map = 1, x = 1672.4, y = -4344.1, z = 24.3, o = 2.4}   -- Orgrimmar Gates
        local loc
        if plr:GetClass() == 6 then
            loc = (plr:GetTeam() == 0) and dkAllianceStart or dkHordeStart
        else
            loc = raceStartLocations[plr:GetRace()]
        end

        if loc then
            plr:Teleport(loc.map, loc.x, loc.y, loc.z, loc.o)
            if plr:GetClass() == 6 then
                local finalQuest = (plr:GetTeam() == 0) and 13188 or 13189
                plr:AddQuest(finalQuest)

                -- Re-grant the EXACT core starting spells + starting zone quest rewards a DK should have
                local dkStartSpells = {
                    47541, 49576, 45477, 45462, 45902, 48266, 48263, -- Death Coil, Death Grip, Icy Touch, Plague Strike, Blood Strike, Blood Presence, Frost Presence
                    50977, 53428, 48778                              -- Death Gate, Runeforging, Acherus Deathcharger mount
                }
                for _, sid in ipairs(dkStartSpells) do
                    if not plr:HasSpell(sid) then
                        plr:LearnSpell(sid)
                    end
                end
            end
        else
            plr:SendBroadcastMessage("Unknown race/class start location.")
        end
        -- Always schedule delayed logout if not drafting
        if not draftMode then
            CreateLuaEvent(function()
                local p = GetPlayerByGUID(guid)
                if p then p:LogoutPlayer(true) end
            end, LOGOUT_AFTER_PRESTIGE_TIMER, 1)
        end
        -- If draftMode, immediately kick and schedule class change
        if draftMode then
            local guidLow = plr:GetGUIDLow()  -- Cache the GUID before logout
            plr:AddItem(46978,1) -- All in one totem
            plr:KickPlayer()
            UpdateClassAfterLogout(guidLow, 8)
        end
    end, 500, 1)
end
local function DoDraftEnd(player)
    local guid = player:GetGUIDLow()

    -- Fetch stored class
    local q = CharDBQuery("SELECT stored_class FROM prestige_stats WHERE player_id = " .. guid)
    if not q then
        player:SendBroadcastMessage("Could not end Draft Mode: missing stored_class.")
        return
    end

    local originalClass = q:GetUInt8(0)
    if not originalClass or originalClass == 0 then
        player:SendBroadcastMessage("Stored class is invalid.")
        return
    end

    -- Reset draft state
    local currentPrestige = 0
    local qPrestige = CharDBQuery("SELECT prestige_level FROM prestige_stats WHERE player_id = " .. guid)
    if qPrestige then
        currentPrestige = qPrestige:GetUInt32(0)
    end

    if player:GetLevel() >= CONFIG.MAX_LEVEL then
        currentPrestige = currentPrestige + 1
        CharDBExecute("UPDATE prestige_stats SET draft_state = 0, prestige_level = " .. currentPrestige .. " WHERE player_id = " .. guid)
    else
        CharDBExecute("UPDATE prestige_stats SET draft_state = 0 WHERE player_id = " .. guid)
    end

    if type(SpellDraft_SetDraftStateCache) == "function" then
        SpellDraft_SetDraftStateCache(guid, 0)
    end

    if type(SpellDraft_SetPrestigeCache) == "function" then
        SpellDraft_SetPrestigeCache(guid, currentPrestige)
    end

    RemoveAndMailEquippedItems(player)
    player:SetLevel(originalClass == 6 and 55 or 1)
    GiveStartingGear(player)

    player:SendBroadcastMessage("|cffff0000You have exited Draft Mode.|r Your class will be restored.")
    player:SendBroadcastMessage("You will be kicked to finalize your class change.")
    player:GossipComplete()
    local draftedSpellsQuery = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid)
    if draftedSpellsQuery then
        repeat
            local spellId = draftedSpellsQuery:GetUInt32(0)
            if player:HasSpell(spellId) then
                player:RemoveSpell(spellId)
            end
        until not draftedSpellsQuery:NextRow()
    end
    -- Clean up data
    CharDBExecute("DELETE FROM character_action WHERE guid = " .. guid)
    CharDBExecute("DELETE FROM character_spell WHERE guid = " .. guid)
    CharDBExecute("DELETE FROM draft_bans WHERE player_id = " .. guid)
    CharDBExecute("DELETE FROM drafted_spells WHERE player_guid = " .. guid)
    ResetPlayerQuests(guid, originalClass)
    DeleteAllPlayerPets(guid)

    -- Teleport, then logout and restore original class
    CreateLuaEvent(function()
        local plr = GetPlayerByGUID(guid)
        if not plr then return end

        local raceStartLocations = {
            [1]  = {map = 0,   x = -8949.95,  y = -132.493, z = 83.5312,   o = 3.142},
            [2]  = {map = 1,   x = -618.518,  y = -4251.67, z = 38.718,    o = 6.2},
            [3]  = {map = 0,   x = -6240.32,  y = 331.033,  z = 382.757,   o = 5.2},
            [4]  = {map = 1,   x = 10311.3,   y = 832.463,  z = 1326.41,   o = 5.7},
            [5]  = {map = 0,   x = 1676.35,   y = 1678.68,  z = 121.67,    o = 1.6},
            [6]  = {map = 1,   x = -2917.58,  y = -257.98,  z = 52.9968,   o = 0.0},
            [7]  = {map = 0,   x = -6240.95,  y = 331.493,  z = 382.5312,  o = 5.2},
            [8]  = {map = 1,   x = -618.518,  y = -4251.67, z = 38.718,    o = 6.2},
            [10] = {map = 530, x = 10349.6,   y = -6357.29, z = 33.4026,   o = 5.3},
            [11] = {map = 530, x = -3961.64,  y = -13931.2, z = 100.615,   o = 2.08},
        }

        local dkAllianceStart = {map = 0, x = -8354.2, y = 334.3, z = 121.0, o = 3.6} -- Stormwind Gates
        local dkHordeStart = {map = 1, x = 1672.4, y = -4344.1, z = 24.3, o = 2.4}   -- Orgrimmar Gates
        local loc = (originalClass == 6) and ((plr:GetTeam() == 0) and dkAllianceStart or dkHordeStart) or raceStartLocations[plr:GetRace()]
        if loc then
            plr:Teleport(loc.map, loc.x, loc.y, loc.z, loc.o)
            if originalClass == 6 then
                local finalQuest = (plr:GetTeam() == 0) and 13188 or 13189
                plr:AddQuest(finalQuest)

                -- Re-grant the EXACT core starting spells + starting zone quest rewards a DK should have
                local dkStartSpells = {
                    47541, 49576, 45477, 45462, 45902, 48266, 48263, -- Death Coil, Death Grip, Icy Touch, Plague Strike, Blood Strike, Blood Presence, Frost Presence
                    50977, 53428, 48778                              -- Death Gate, Runeforging, Acherus Deathcharger mount
                }
                for _, sid in ipairs(dkStartSpells) do
                    if not plr:HasSpell(sid) then
                        plr:LearnSpell(sid)
                    end
                end
            end
        end

        -- Schedule logout + class restore
        local guidLow = plr:GetGUIDLow()
        plr:KickPlayer()
        UpdateClassAfterLogout(guidLow, originalClass)
    end, 500, 1)
end

local function HasActivePetBlockPrestige(player)
    local petGUID = tostring(player:GetPetGUID())
    if not petGUID or petGUID == "0" or petGUID == nil then
        return false
    end
    player:SendBroadcastMessage("You must dismiss your pet before prestiging!")
    player:SendBroadcastMessage("Also make sure you've got 10 free inven. slots!")
    return true
end


local function OnGossipSelect(event, player, creature, sender, intid)
    local guid = player:GetGUIDLow()

    if intid == 0 then
        ShowMainMenu(player, creature)
    elseif intid == 1 then
        ShowPrestigeInfo(player, creature)
    elseif intid == 2 then
        ShowPrestigeOptions(player, creature)
    elseif intid == 3 then
        ShowConfirmation(player, creature)
    elseif intid == 998 then
        player:GossipComplete()
    elseif intid == 999 then
        player:GossipComplete()
    elseif intid == 4 then
        ShowDraftConfirmation(player, creature)
    elseif intid == 100 then
        if HasActivePetBlockPrestige(player) then return end
    local q = CharDBQuery("SELECT draft_state, stored_class FROM prestige_stats WHERE player_id = " .. guid)
        if q then
            local draftState = q:GetUInt32(0)
            if draftState == 1 then
                DoDraftEnd(player)
                return
            end
        end
      DoPrestige(player, false)
    elseif intid == 101 then
        if HasActivePetBlockPrestige(player) then return end
        DoPrestige(player, true)
    elseif intid == 200 then
        ShowEndDraftConfirmation(player, creature) 
    elseif intid == 201 then
        if HasActivePetBlockPrestige(player) then return end
        DoDraftEnd(player) 
    elseif intid == 300 then
        player:GossipClearMenu()
        player:GossipMenuAddItem(5, "|TInterface\\Icons\\Spell_Holy_SurgeOfLight:20|t Show My Drafted Spells", 1, 301)
        player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Scroll_03:20|t Show My Banned Spells", 1, 302)

        -- Show reroll count
        local statsQuery = CharDBQuery("SELECT rerolls FROM prestige_stats WHERE player_id = " .. guid)
        local rerolls = statsQuery and statsQuery:GetUInt32(0) or 0
        player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_CoinBag_01:16|t |cff000000Rerolls Remaining:|r " .. rerolls, 1, 998)

        -- Show ban count
        local bansQuery = CharDBQuery("SELECT bans FROM prestige_stats WHERE player_id = " .. guid)
        local banCount = bansQuery and bansQuery:GetUInt32(0) or 0
        player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Misc_Gear_01:16|t |cff000000Bans Remaining:|r " .. banCount, 1, 998)

        player:GossipMenuAddItem(0, "Back", 1, 0)
        player:GossipSendMenu(1, creature)

    elseif intid == 301 then
        local q = CharDBQuery("SELECT spell_id FROM drafted_spells WHERE player_guid = " .. guid)
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, "|cff000000Your Drafted Spells:|r", 1, 998)
        local seenNames = {}

        if q then
            repeat
                local spellId = q:GetUInt32(0)
                local nameResult = WorldDBQuery("SELECT Name_Lang_enUS FROM dbc_spells WHERE ID = " .. spellId)
                local name = nameResult and nameResult:GetString(0) or ("Unknown Spell [" .. spellId .. "]")

                if not seenNames[name] then
                    seenNames[name] = true
                    player:GossipMenuAddItem(5, name, 1, 998)
                end
            until not q:NextRow()
        else
            player:GossipMenuAddItem(0, "No drafted spells found.", 1, 998)
        end

        player:GossipMenuAddItem(0, "Back", 1, 300)
        player:GossipSendMenu(1, creature)

    elseif intid == 302 then

        local q = CharDBQuery("SELECT spell_id FROM draft_bans WHERE player_id = " .. guid)
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, "|cff3366ccClicking on a spell here will remove it from your ban list|r", 1, 998)
        player:GossipMenuAddItem(0, "|cff000000Your Banned Spells:|r", 1, 998)

        if q then
            repeat
                local spellId = q:GetUInt32(0)
                local nameResult = WorldDBQuery("SELECT Name_Lang_enUS FROM dbc_spells WHERE ID = " .. spellId)
                local name = nameResult and nameResult:GetString(0) or ("Unknown Spell [" .. spellId .. "]")

                player:GossipMenuAddItem(5, name .. " (" .. spellId .. ")", 1, 100000 + spellId)
            until not q:NextRow()
        else
            player:GossipMenuAddItem(0, "No banned spells found.", 1, 998)
        end
        player:GossipMenuAddItem(0, "Back", 1, 300)
        player:GossipSendMenu(1, creature) 
  elseif intid >= 100000 then
    local spellId = intid - 100000
    CharDBExecute("DELETE FROM draft_bans WHERE player_id = " .. guid .. " AND spell_id = " .. spellId)
    player:SendBroadcastMessage("Removed banned spell ID: " .. spellId)

    -- Go back to the Draft Stats submenu (intid 300)
    player:GossipClearMenu()
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\Spell_Holy_SurgeOfLight:20|t Show My Drafted Spells", 1, 301)
    player:GossipMenuAddItem(5, "|TInterface\\Icons\\INV_Scroll_03:20|t Show My Banned Spells", 1, 302)
    player:GossipMenuAddItem(0, "Back", 1, 0)
    player:GossipSendMenu(1, creature)


    end
end

RegisterCreatureGossipEvent(NPC_ID, 1, OnGossipHello)
RegisterCreatureGossipEvent(NPC_ID, 2, OnGossipSelect)
