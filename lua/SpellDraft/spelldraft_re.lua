--[[
    spelldraft_re.lua — Random Enchantment (RE) system.

    Freshly acquired weapons/armor (loot, quest rewards, crafts, group rolls)
    can roll a Mystic Enchant from the world table `custom_random_enchantments`.
    Rolled enchants are bound to the item instance GUID in the characters table
    `character_item_enchantments` (enchantment_id = 0 marks "rolled nothing" so
    an item is only ever rolled once).

    While an enchanted item is equipped, its handler runs:
        aura    — handler_data spell ID is applied as a permanent aura
    Handlers 'proc', 'display' and 'teach' are reserved for later waves.

    Client sync: item links carry no usable instance id (uniqueId is 0 for
    regular items), so enchanted items are identified to the client BY
    POSITION. "SpellDraftRE" addon messages push a full position map
    ("RESET" then "POS;<key>;<spellId>;<quality>;<name>;<tooltip>" per item)
    whenever the inventory changes; RETooltip.lua keys its tooltip hooks off
    bag/slot and equipment slot.
]]

local RE_ENABLE = CONFIG.RE_ENABLE
if RE_ENABLE == nil then RE_ENABLE = true end
local ROLL_CHANCE = CONFIG.RE_ROLL_CHANCE or { [2] = 10, [3] = 25, [4] = 50, [5] = 100 }
local BOTS_CAN_ROLL = CONFIG.RE_BOTS_CAN_ROLL or false
local SYNC_INTERVAL = CONFIG.RE_SYNC_INTERVAL_MS or 2000

local ADDON_PREFIX = "SpellDraftRE"
local ITEM_CLASS_WEAPON = 2
local ITEM_CLASS_ARMOR = 4
local EQUIPMENT_SLOT_END = 19

-- InventoryType -> slot_mask bit (matches docs/RANDOM_ENCHANTMENT_PLAN.md)
local INV_TYPE_BIT = {
    [1] = 1,       -- Head
    [2] = 2,       -- Neck
    [3] = 4,       -- Shoulders
    [4] = 8,       -- Shirt
    [5] = 16,      -- Chest
    [6] = 32,      -- Waist
    [7] = 64,      -- Legs
    [8] = 128,     -- Feet
    [9] = 256,     -- Wrist
    [10] = 512,    -- Hands
    [11] = 1024,   -- Finger
    [12] = 2048,   -- Trinket
    [13] = 4096,   -- One-Hand
    [14] = 8192,   -- Shield
    [15] = 16384,  -- Bow
    [16] = 32768,  -- Back
    [17] = 4096,   -- Two-Hand
    [20] = 16,     -- Robe (chest)
    [21] = 4096,   -- Main-Hand
    [22] = 8192,   -- Off-Hand held
    [23] = 8192,   -- Holdable
    [25] = 16384,  -- Thrown
    [26] = 16384,  -- Ranged (guns/crossbows/wands)
    [28] = 16384,  -- Relic
}

local QUALITY_COLOR = {
    [2] = "|cff1eff00",
    [3] = "|cff0070dd",
    [4] = "|cffa335ee",
    [5] = "|cffff8000",
    [6] = "|cffe6cc80",
}

-- ============================================================================
-- Enchant definitions (loaded once from the world DB)
-- ============================================================================

local enchants = {}      -- id -> definition
local enchantCount = 0

do
    -- Probe via information_schema first: a direct query against a missing
    -- table is a FATAL error during worldserver startup (crash loop).
    local probe = WorldDBQuery([[
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'custom_random_enchantments'
    ]])
    if not probe then
        RE_ENABLE = false
        print("[SpellDraft] RE system disabled: table custom_random_enchantments is missing."
            .. " Apply data/sql/db-world/21_random_enchantments.sql and restart.")
    end

    local charProbe = CharDBQuery([[
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'character_item_enchantments'
    ]])
    if not charProbe then
        RE_ENABLE = false
        print("[SpellDraft] RE system disabled: table character_item_enchantments is missing."
            .. " Apply data/sql/db-characters/07_random_enchantments.sql and restart.")
    end

    local q = RE_ENABLE and WorldDBQuery([[
        SELECT id, name, tooltip, quality, weight, min_level, slot_mask, handler, handler_data
        FROM custom_random_enchantments
    ]]) or nil
    if q then
        repeat
            local e = {
                id = q:GetUInt32(0),
                name = q:GetString(1),
                tooltip = q:GetString(2),
                quality = q:GetUInt32(3),
                weight = q:GetFloat(4),
                minLevel = q:GetUInt32(5),
                slotMask = q:GetUInt32(6),
                handler = q:GetString(7),
                handlerData = q:GetString(8),
            }
            if e.handler == "aura" then
                e.auraSpell = tonumber(e.handlerData) or 0
            end
            enchants[e.id] = e
            enchantCount = enchantCount + 1
        until not q:NextRow()
    end
    print("[SpellDraft] RE system loaded " .. enchantCount .. " enchant definitions.")
end

-- ============================================================================
-- Rolling
-- ============================================================================

-- Guards double-fires across hooks (e.g. group roll + loot for the same item).
-- Wiped periodically; the DB row is the durable once-only guarantee.
local attemptedThisSession = {}
local attemptedCount = 0

-- ============================================================================
-- Client tooltip sync: the item link's uniqueId is 0 for regular items, so
-- items are identified to the client BY POSITION. Keys must match the client
-- tooltip hooks in RETooltip.lua:
--     "inv:<1-19>"           equipped slots (client numbering = server + 1)
--     "bag:0:<1-16>"         backpack
--     "bag:<1-4>:<1-36>"     side bags
-- ============================================================================

local BACKPACK_BAG = 255
local BACKPACK_SLOT_START = 23
local BACKPACK_SLOT_END = 38
local BAG_SLOT_START = 19
local BAG_SLOT_END = 22
local MAX_BAG_SIZE = 36

-- Walks equipment + backpack + side bags; returns
--   positions: { { key = clientKey, guid = itemGuidLow }, ... }
--   signature: string that changes when any item moves/changes
local function CollectInventoryPositions(player)
    local positions, sig = {}, {}
    for slot = 0, EQUIPMENT_SLOT_END - 1 do
        local item = player:GetEquippedItemBySlot(slot)
        if item then
            local guid = item:GetGUIDLow()
            positions[#positions + 1] = { key = "inv:" .. (slot + 1), guid = guid }
            sig[#sig + 1] = slot .. ":" .. guid
        end
    end
    for slot = BACKPACK_SLOT_START, BACKPACK_SLOT_END do
        local item = player:GetItemByPos(BACKPACK_BAG, slot)
        if item then
            local guid = item:GetGUIDLow()
            positions[#positions + 1] = { key = "bag:0:" .. (slot - BACKPACK_SLOT_START + 1), guid = guid }
            sig[#sig + 1] = slot .. ":" .. guid
        end
    end
    for bag = BAG_SLOT_START, BAG_SLOT_END do
        for slot = 0, MAX_BAG_SIZE - 1 do
            local item = player:GetItemByPos(bag, slot)
            if item then
                local guid = item:GetGUIDLow()
                positions[#positions + 1] = { key = "bag:" .. (bag - BAG_SLOT_START + 1) .. ":" .. (slot + 1), guid = guid }
                sig[#sig + 1] = bag .. "." .. slot .. ":" .. guid
            end
        end
    end
    return positions, table.concat(sig, ",")
end

-- Pushes the full position -> enchant map to the client.
local function PushEnchantMap(player, positions)
    if not positions then
        positions = CollectInventoryPositions(player)
    end
    player:SendAddonMessage(ADDON_PREFIX, "RESET", 0, player)
    if #positions == 0 then return end

    local guids, byGuid = {}, {}
    for i = 1, #positions do
        guids[#guids + 1] = positions[i].guid
    end
    local q = CharDBQuery(
        "SELECT item_guid, enchantment_id FROM character_item_enchantments WHERE enchantment_id > 0 AND item_guid IN ("
        .. table.concat(guids, ",") .. ")")
    if not q then return end
    repeat
        byGuid[q:GetUInt32(0)] = enchants[q:GetUInt32(1)]
    until not q:NextRow()

    for i = 1, #positions do
        local e = byGuid[positions[i].guid]
        if e then
            local tooltip = e.tooltip
            if #tooltip > 150 then
                tooltip = tooltip:sub(1, 150)
            end
            player:SendAddonMessage(ADDON_PREFIX,
                "POS;" .. positions[i].key .. ";" .. (e.auraSpell or 0) .. ";" .. e.quality .. ";" .. e.name .. ";" .. tooltip,
                0, player)
        end
    end
end

local function PickEnchant(playerLevel, invTypeBit, minQuality, excludeId)
    local eligible, total = {}, 0
    for _, e in pairs(enchants) do
        if e.minLevel <= playerLevel and bit_and(e.slotMask, invTypeBit) ~= 0
            and (not minQuality or e.quality >= minQuality)
            and e.id ~= excludeId then
            eligible[#eligible + 1] = e
            total = total + e.weight
        end
    end
    if total <= 0 then return nil end

    local r = math.random() * total
    for i = 1, #eligible do
        r = r - eligible[i].weight
        if r <= 0 then return eligible[i] end
    end
    return eligible[#eligible]
end

-- Weapons/armor, Uncommon..Legendary (excludes Artifact/Heirloom), known slot.
local function IsEligibleItem(item)
    local class = item:GetClass()
    if class ~= ITEM_CLASS_WEAPON and class ~= ITEM_CLASS_ARMOR then return false end
    local quality = item:GetQuality()
    if quality < 2 or quality > 5 then return false end
    return INV_TYPE_BIT[item:GetInventoryType()] ~= nil
end

-- force = true (GM ".rollre" testing) bypasses the roll chance and re-rolls
-- items that already have a result.
local function RollForItem(player, item, force)
    if not RE_ENABLE or not player or not item then return end
    if enchantCount == 0 then return end
    if not BOTS_CAN_ROLL and player:IsBot() then return end

    if not IsEligibleItem(item) then return end

    local invTypeBit = INV_TYPE_BIT[item:GetInventoryType()]
    local itemGuid = item:GetGUIDLow()
    if force then
        attemptedThisSession[itemGuid] = nil
        -- CharDBQuery is synchronous; CharDBExecute would race the SELECT below.
        CharDBQuery("DELETE FROM character_item_enchantments WHERE item_guid = " .. itemGuid)
    end
    if attemptedThisSession[itemGuid] then return end
    if attemptedCount > 20000 then
        attemptedThisSession = {}
        attemptedCount = 0
    end
    attemptedThisSession[itemGuid] = true
    attemptedCount = attemptedCount + 1

    -- Never re-roll an item instance that has a result already (incl. "nothing").
    local existing = CharDBQuery("SELECT 1 FROM character_item_enchantments WHERE item_guid = " .. itemGuid)
    if existing then return end

    local chance = force and 100 or (ROLL_CHANCE[item:GetQuality()] or 0)
    if math.random(1, 100) > chance then
        CharDBQuery("INSERT IGNORE INTO character_item_enchantments (item_guid, enchantment_id) VALUES (" .. itemGuid .. ", 0)")
        return
    end

    -- Force rolls (GM testing) ignore the per-enchant level gate.
    local effectiveLevel = force and (CONFIG.MAX_LEVEL or 80) or player:GetLevel()
    local e = PickEnchant(effectiveLevel, invTypeBit)
    if not e then
        if force then
            player:SendBroadcastMessage("|cff00ff00[Mystic Enchant]|r No eligible enchants for " .. item:GetItemLink() .. ".")
        end
        CharDBQuery("INSERT IGNORE INTO character_item_enchantments (item_guid, enchantment_id) VALUES (" .. itemGuid .. ", 0)")
        return
    end

    CharDBQuery("INSERT IGNORE INTO character_item_enchantments (item_guid, enchantment_id) VALUES (" .. itemGuid .. ", " .. e.id .. ")")

    local color = QUALITY_COLOR[e.quality] or "|cff1eff00"
    player:SendBroadcastMessage("|cff00ff00[Mystic Enchant]|r " .. color .. "[" .. e.name .. "]|r rolled on " .. item:GetItemLink() .. "!")
    PushEnchantMap(player)
end

local function OnLootItem(_, player, item, _)
    RollForItem(player, item)
end

local function OnQuestRewardItem(_, player, item, _)
    RollForItem(player, item)
end

local function OnCreateItem(_, player, item, _)
    RollForItem(player, item)
end

local function OnGroupRollRewardItem(_, player, item, _, _, _)
    RollForItem(player, item)
end

-- ============================================================================
-- Equipped-enchant handler engine (aura / proc / display)
-- ============================================================================

local appliedAuras = {}   -- playerGuidLow -> { [spellId] = true } (auras this script applied)
local ClearProcState      -- forward declaration; assigned in the proc section below
local activeProcs = {}    -- playerGuidLow -> { [recipeKey] = true }
local activeDisplays = {} -- playerGuidLow -> { { formAuras = {id=true,...}, display = n }, ... }
local morphedTo = {}      -- playerGuidLow -> displayId currently forced by us
local invSignature = {}   -- playerGuidLow -> inventory signature (positions + guids)

-- Parses display handler_data "5487,9634:31094" -> { formAuras = set, display = n }
local function ParseDisplayData(data)
    local auraPart, displayId = data:match("^([%d,]+):(%d+)$")
    if not auraPart then return nil end
    local formAuras = {}
    for id in auraPart:gmatch("%d+") do
        formAuras[tonumber(id)] = true
    end
    return { formAuras = formAuras, display = tonumber(displayId) }
end

-- Queries the rolled enchants on currently equipped items and splits them by
-- handler: desired aura set, active proc recipe set, active display overrides.
local function GetEquippedHandlers(player)
    local auras, procs, displays = {}, {}, {}

    local guids = {}
    for slot = 0, EQUIPMENT_SLOT_END - 1 do
        local item = player:GetEquippedItemBySlot(slot)
        if item then
            guids[#guids + 1] = item:GetGUIDLow()
        end
    end
    if #guids == 0 then return auras, procs, displays end

    local q = CharDBQuery(
        "SELECT item_guid, enchantment_id FROM character_item_enchantments WHERE enchantment_id > 0 AND item_guid IN ("
        .. table.concat(guids, ",") .. ")")
    if q then
        repeat
            local e = enchants[q:GetUInt32(1)]
            if e then
                if e.handler == "aura" and e.auraSpell and e.auraSpell > 0 then
                    auras[e.auraSpell] = true
                elseif e.handler == "proc" and e.handlerData ~= "" then
                    procs[e.handlerData] = true
                elseif e.handler == "display" then
                    local d = ParseDisplayData(e.handlerData)
                    if d then
                        displays[#displays + 1] = d
                    end
                end
            end
        until not q:NextRow()
    end
    return auras, procs, displays
end

-- Applies/removes the model override according to the player's current form.
local function ReconcileDisplay(player)
    local guid = player:GetGUIDLow()
    local wanted = nil
    local displays = activeDisplays[guid]
    if displays then
        for i = 1, #displays do
            for auraId in pairs(displays[i].formAuras) do
                if player:HasAura(auraId) then
                    wanted = displays[i].display
                    break
                end
            end
            if wanted then break end
        end
    end

    if wanted then
        -- Compare the live display: the core re-applies the stock form model
        -- around shapeshift aura events, silently undoing our morph.
        if player:GetDisplayId() ~= wanted then
            player:SetDisplayId(wanted)
        end
        morphedTo[guid] = wanted
    elseif morphedTo[guid] then
        player:DeMorph()
        morphedTo[guid] = nil
    end
end

local function SyncAuras(player)
    local guid = player:GetGUIDLow()
    local desired, procs, displays = GetEquippedHandlers(player)
    local applied = appliedAuras[guid] or {}

    for spellId in pairs(desired) do
        if not applied[spellId] then
            if not player:HasAura(spellId) then
                player:AddAura(spellId, player)
                if not player:HasAura(spellId) then
                    player:CastSpell(player, spellId, true)
                end
            end
            -- Claim the aura either way; a real socketed glyph providing the
            -- same aura is the rare overlap we accept losing on unequip.
            applied[spellId] = true
        end
    end

    for spellId in pairs(applied) do
        if not desired[spellId] then
            player:RemoveAura(spellId)
            applied[spellId] = nil
        end
    end

    appliedAuras[guid] = applied

    -- Merge displays and proc recipes granted by socketed custom glyphs
    -- (spelldraft_glyphs.lua) with the item-enchant ones.
    if SpellDraftGlyphs then
        local glyphDisplays = SpellDraftGlyphs.GetDisplays(player)
        for i = 1, #glyphDisplays do
            displays[#displays + 1] = glyphDisplays[i]
        end
        for key in pairs(SpellDraftGlyphs.GetProcs(player)) do
            procs[key] = true
        end
    end

    activeProcs[guid] = next(procs) and procs or nil

    activeDisplays[guid] = #displays > 0 and displays or nil
    ReconcileDisplay(player)
end

-- Detects any inventory change (equip, unequip, bag moves) and resyncs
-- both the auras and the client's position -> enchant tooltip map.
local function CheckEquipChanges(player)
    local guid = player:GetGUIDLow()
    local positions, sig = CollectInventoryPositions(player)
    if SpellDraftGlyphs then
        -- Socketing/removing a custom glyph must also trigger a resync.
        sig = sig .. "|" .. SpellDraftGlyphs.GetSignature(player)
    end
    if invSignature[guid] ~= sig then
        invSignature[guid] = sig
        SyncAuras(player)
        PushEnchantMap(player, positions)
    end
end

local function OnEquip(_, player, _, _, _)
    if not RE_ENABLE then return end
    if not BOTS_CAN_ROLL and player:IsBot() then return end
    CheckEquipChanges(player)
end

local function OnLogin(_, player)
    if not RE_ENABLE then return end
    if player:IsBot() then return end
    local guid = player:GetGUIDLow()
    appliedAuras[guid] = nil
    activeProcs[guid] = nil
    activeDisplays[guid] = nil
    morphedTo[guid] = nil
    invSignature[guid] = nil
    -- Defer past the core's own login aura loading.
    local playerGuid = player:GetGUID()
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(playerGuid)
        if p then
            CheckEquipChanges(p)
        end
    end, 3000, 1)
end

local function OnLogout(_, player)
    local guid = player:GetGUIDLow()
    appliedAuras[guid] = nil
    activeProcs[guid] = nil
    activeDisplays[guid] = nil
    morphedTo[guid] = nil
    invSignature[guid] = nil
    ClearProcState(guid)
end

-- Safety-net ticker: catches unequip/swap paths that fire no Eluna event,
-- re-asserts display morphs, and runs tick-based proc recipes.
local RunTickRecipes  -- forward declaration (defined with the recipes below)

if RE_ENABLE then
    CreateLuaEvent(function()
        for _, player in pairs(GetPlayersInWorld()) do
            if not player:IsBot() then
                CheckEquipChanges(player)
                ReconcileDisplay(player)
                RunTickRecipes(player)
            end
        end
    end, SYNC_INTERVAL, 0)
end

-- ============================================================================
-- Display handler events: morph on shapeshift, demorph on leaving the form
-- ============================================================================

local function OnAuraApply(_, player, aura)
    if not activeDisplays[player:GetGUIDLow()] then return end
    ReconcileDisplay(player)
end

local function OnAuraRemove(_, player, aura, _)
    if morphedTo[player:GetGUIDLow()] == nil then return end
    ReconcileDisplay(player)
end

-- ============================================================================
-- Proc recipes
--
-- handler_data of a 'proc' enchant names a recipe below. Recipes may define:
--     onSpellCast(player, spellId, spell)
--     onMeleeDamage(player, target)
--     onDealDamage(player, target)
--     onHeal(player, target)
--     onKill(player, victim)
--     onTick(player)
-- Effects use native max-rank spells cast as triggered (free, instant).
-- ============================================================================

local procState = {}  -- playerGuidLow -> { [recipeKey] = lastProcTime }

ClearProcState = function(guid)
    procState[guid] = nil
end

-- Returns true if the recipe is off internal cooldown; stamps the new time.
local function PassICD(player, key, icd)
    local guid = player:GetGUIDLow()
    local state = procState[guid]
    if not state then
        state = {}
        procState[guid] = state
    end
    local now = os.time()
    if state[key] and now - state[key] < icd then
        return false
    end
    state[key] = now
    return true
end

local function MakeSpellSet(ids)
    local set = {}
    for i = 1, #ids do set[ids[i]] = true end
    return set
end

local FIREBALL = MakeSpellSet({ 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306, 27070, 38692, 42832, 42833 })
local LIGHTNING_BOLT = MakeSpellSet({ 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449, 49237, 49238 })
local SHADOW_WORD_PAIN = MakeSpellSet({ 589, 594, 970, 992, 2767, 10892, 10893, 10894, 25367, 25368, 48124, 48125 })
local MIND_BLAST_RANKS = { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, 25372, 25375, 48126, 48127 }

local FIRE_BLAST_MAX = 42873
local CHAIN_LIGHTNING_MAX = 49271
local ICE_LANCE_MAX = 42914
local PW_SHIELD_MAX = 48066
local RENEW_MAX = 48068

local PROC_RECIPES = {
    sparkflame = {
        onSpellCast = function(player, spellId, spell)
            if not FIREBALL[spellId] then return end
            if math.random(100) > 15 then return end
            local target = spell:GetTarget()
            if target and target.CastSpell then
                player:CastSpell(target, FIRE_BLAST_MAX, true)
            end
        end,
    },
    thunderstruck = {
        onSpellCast = function(player, spellId, spell)
            if not LIGHTNING_BOLT[spellId] then return end
            if math.random(100) > 15 then return end
            local target = spell:GetTarget()
            if target and target.CastSpell then
                player:CastSpell(target, CHAIN_LIGHTNING_MAX, true)
            end
        end,
    },
    echomind = {
        onSpellCast = function(player, spellId, _)
            if not SHADOW_WORD_PAIN[spellId] then return end
            if math.random(100) > 25 then return end
            for i = 1, #MIND_BLAST_RANKS do
                player:ResetSpellCooldown(MIND_BLAST_RANKS[i], true)
            end
        end,
    },
    battlemage = {
        onMeleeDamage = function(player, target)
            if math.random(100) > 10 then return end
            if not PassICD(player, "battlemage", 6) then return end
            player:CastSpell(target, ICE_LANCE_MAX, true)
        end,
    },
    -- Glyph of the Zealot (custom major glyph, see client_patch_manifest.json)
    zealot = {
        onMeleeDamage = function(player, target)
            if math.random(100) > 10 then return end
            if not PassICD(player, "zealot", 8) then return end
            player:CastSpell(target, 48801, true) -- Exorcism (max rank)
        end,
    },
    killheal = {
        onKill = function(player, _)
            if not PassICD(player, "killheal", 5) then return end
            local maxHealth = player:GetMaxHealth()
            player:SetHealth(math.min(maxHealth, player:GetHealth() + math.floor(maxHealth * 0.05)))
            local maxMana = player:GetMaxPower(0)
            if maxMana > 0 then
                player:SetPower(math.min(maxMana, player:GetPower(0) + math.floor(maxMana * 0.05)), 0)
            end
        end,
    },
    lastbastion = {
        onTick = function(player)
            if not player:IsInCombat() then return end
            if player:GetHealthPct() >= 30 then return end
            if not PassICD(player, "lastbastion", 60) then return end
            player:CastSpell(player, PW_SHIELD_MAX, true)
        end,
    },
    verdantecho = {
        onHeal = function(player, target)
            if math.random(100) > 15 then return end
            if not PassICD(player, "verdantecho", 4) then return end
            player:CastSpell(target, RENEW_MAX, true)
        end,
    },
    stormsurge = {
        onDealDamage = function(player, target)
            if math.random(100) > 5 then return end
            if not PassICD(player, "stormsurge", 8) then return end
            player:CastSpell(target, CHAIN_LIGHTNING_MAX, true)
        end,
    },
}

-- Dispatch helpers: early-out for players with no equipped proc enchants.
local function ActiveRecipes(player)
    return activeProcs[player:GetGUIDLow()]
end

local function OnProcSpellCast(_, player, spell, _)
    local procs = ActiveRecipes(player)
    if not procs then return end
    local spellId = spell:GetEntry()
    for key in pairs(procs) do
        local r = PROC_RECIPES[key]
        if r and r.onSpellCast then
            r.onSpellCast(player, spellId, spell)
        end
    end
end

local function OnProcMeleeDamage(_, player, target, damage)
    local procs = ActiveRecipes(player)
    if not procs or not target then return end
    for key in pairs(procs) do
        local r = PROC_RECIPES[key]
        if r and r.onMeleeDamage then
            r.onMeleeDamage(player, target)
        end
    end
end

local function OnProcDealDamage(_, player, target, damage, _)
    local procs = ActiveRecipes(player)
    if not procs or not target then return end
    if damage == nil or damage <= 0 then return end
    for key in pairs(procs) do
        local r = PROC_RECIPES[key]
        if r and r.onDealDamage then
            r.onDealDamage(player, target)
        end
    end
end

local function OnProcHeal(_, player, target, gain)
    local procs = ActiveRecipes(player)
    if not procs or not target then return end
    if gain == nil or gain <= 0 then return end
    for key in pairs(procs) do
        local r = PROC_RECIPES[key]
        if r and r.onHeal then
            r.onHeal(player, target)
        end
    end
end

local function OnProcKill(_, player, victim)
    local procs = ActiveRecipes(player)
    if not procs then return end
    for key in pairs(procs) do
        local r = PROC_RECIPES[key]
        if r and r.onKill then
            r.onKill(player, victim)
        end
    end
end

RunTickRecipes = function(player)
    local procs = activeProcs[player:GetGUIDLow()]
    if not procs then return end
    for key in pairs(procs) do
        local r = PROC_RECIPES[key]
        if r and r.onTick then
            r.onTick(player)
        end
    end
end

-- ============================================================================
-- GM testing command: ".rollre" force-rolls every eligible weapon/armor item
-- (equipped, backpack and side bags) at 100% chance, re-rolling items that
-- already have a result.
-- Usage: .additem a green/blue weapon or armor piece, then .rollre
-- ============================================================================

local function CollectCandidateItems(player)
    local items = {}
    for slot = 0, EQUIPMENT_SLOT_END - 1 do
        items[#items + 1] = player:GetEquippedItemBySlot(slot)
    end
    for slot = BACKPACK_SLOT_START, BACKPACK_SLOT_END do
        items[#items + 1] = player:GetItemByPos(BACKPACK_BAG, slot)
    end
    for bag = BAG_SLOT_START, BAG_SLOT_END do
        for slot = 0, MAX_BAG_SIZE - 1 do
            items[#items + 1] = player:GetItemByPos(bag, slot)
        end
    end
    return items
end

-- (The SDRE whisper protocol handler lives in the services section below.)

local function OnCommand(_, player, command, _)
    if not player then return end
    if command:gsub("%s+$", ""):lower() ~= "rollre" then return end
    if player:GetGMRank() < 1 then
        return false
    end

    local rolled = 0
    local items = CollectCandidateItems(player)
    for i = 1, #items do
        if IsEligibleItem(items[i]) then
            RollForItem(player, items[i], true)
            rolled = rolled + 1
        end
    end
    player:SendBroadcastMessage("|cff00ff00[Mystic Enchant]|r Force-rolled " .. rolled .. " eligible item(s) (equipped + bags).")
    return false
end

-- ============================================================================
-- Nibbs' Mystic Enchant services (Wave 4 economy) — custom client UI
--
-- Nibbs' gossip (spelldraft_npc.lua routes intid 3000 here via the
-- SpellDraftRE global) tells the client to open the Mystic Enchant frame
-- (REServices.lua). The frame drives everything over the whisper protocol:
--
--   client -> server (self-whispers)
--     SDRE_SYNC                          refresh tooltip position map
--     SDRE_BAL                           request prestige token balance
--     SDRE_QUOTE;R;<key>;<entry>         quote reroll/imbue for item at <key>
--     SDRE_ROLL;<G|T>;<key>;<entry>      pay gold/token and roll
--     SDRE_QUOTE;T;<sKey>;<sE>;<dKey>;<dE>  quote a transfer
--     SDRE_XFER;<sKey>;<sE>;<dKey>;<dE>     pay and transfer
--
--   server -> client (addon prefix "SpellDraftRE")
--     OPENUI                              show the frame
--     BAL;<tokens>
--     QUOTE;R;<key>;OK;<gold>;<tokens>;<curEnchName>
--     QUOTE;T;OK;<gold>;<srcEnchName>;<dstEnchName>
--     QUOTE;<R|T>;ERR;<reason>
--     RESULT;<R|T>;OK;<key>               action done; map/balances repushed
--     RESULT;<R|T>;ERR;<reason>
--
-- <key> is a tooltip position key ("inv:N" / "bag:B:S"); <entry> is the item
-- entry id, cross-checked server-side so a moved item can never be mistaken.
-- ============================================================================

local IMBUE_COST = CONFIG.RE_SERVICE_IMBUE_COST or { [2] = 100000, [3] = 250000, [4] = 500000, [5] = 1000000 }
local REROLL_MULT = CONFIG.RE_SERVICE_REROLL_MULT or 0.6
local GOLDEN_TOKENS = CONFIG.RE_SERVICE_GOLDEN_TOKENS or 1
local TRANSFER_COST = CONFIG.RE_TRANSFER_COST or { [3] = 100000, [4] = 300000, [5] = 600000 }

local function SendUI(player, ...)
    player:SendAddonMessage(ADDON_PREFIX, table.concat({ ... }, ";"), 0, player)
end

local function SendBalance(player)
    local q = CharDBQuery("SELECT prestige_tokens FROM prestige_stats WHERE player_id = " .. player:GetGUIDLow())
    SendUI(player, "BAL", q and q:GetUInt32(0) or 0)
end

-- Resolves a client position key back to the item there (nil if empty).
local function ResolveKey(player, key)
    local inv = key:match("^inv:(%d+)$")
    if inv then
        local slot = tonumber(inv) - 1
        if slot < 0 or slot >= EQUIPMENT_SLOT_END then return nil end
        return player:GetEquippedItemBySlot(slot)
    end
    local b, s = key:match("^bag:(%d+):(%d+)$")
    if not b then return nil end
    b, s = tonumber(b), tonumber(s)
    if b == 0 then
        local slot = BACKPACK_SLOT_START + s - 1
        if slot < BACKPACK_SLOT_START or slot > BACKPACK_SLOT_END then return nil end
        return player:GetItemByPos(BACKPACK_BAG, slot)
    end
    if b < 1 or b > 4 or s < 1 or s > MAX_BAG_SIZE then return nil end
    return player:GetItemByPos(BAG_SLOT_START + b - 1, s - 1)
end

-- Resolves and validates an item for a service. Returns item, enchantRow or
-- nil, errorString. enchantRow is -1 when the item has never been rolled.
local function ResolveServiceItem(player, key, entry)
    local item = ResolveKey(player, key)
    if not item or item:GetEntry() ~= tonumber(entry) then
        return nil, nil, "Item moved - place it in the slot again"
    end
    if not IsEligibleItem(item) then
        return nil, nil, "That item cannot hold a Mystic Enchant"
    end
    local row = -1
    local q = CharDBQuery("SELECT enchantment_id FROM character_item_enchantments WHERE item_guid = " .. item:GetGUIDLow())
    if q then
        row = q:GetUInt32(0)
    end
    return item, row, nil
end

local function RollCostFor(item, row)
    local base = IMBUE_COST[item:GetQuality()] or 250000
    if row and row > 0 then
        return math.floor(base * REROLL_MULT)
    end
    return base
end

local function QuoteRoll(player, key, entry)
    local item, row, err = ResolveServiceItem(player, key, entry)
    if not item then
        SendUI(player, "QUOTE", "R", "ERR", err)
        return
    end
    -- Quality precedes the name: names can be empty, and empty fields collapse
    -- in the client's semicolon split, so optional fields must come last.
    local curName, curQual = "", 0
    if row > 0 and enchants[row] then
        curName, curQual = enchants[row].name, enchants[row].quality
    end
    SendUI(player, "QUOTE", "R", key, "OK", RollCostFor(item, row), GOLDEN_TOKENS, curQual, curName)
end

local function DoRoll(player, mode, key, entry)
    local item, row, err = ResolveServiceItem(player, key, entry)
    if not item then
        SendUI(player, "RESULT", "R", "ERR", err)
        return
    end

    local guid = player:GetGUIDLow()
    local itemGuid = item:GetGUIDLow()
    local invTypeBit = INV_TYPE_BIT[item:GetInventoryType()]
    local minQuality = mode == "T" and 4 or nil
    local e = PickEnchant(player:GetLevel(), invTypeBit, minQuality, row > 0 and row or nil)
    if not e then
        SendUI(player, "RESULT", "R", "ERR", "No eligible enchants for that item at your level")
        return
    end

    if mode == "T" then
        local tq = CharDBQuery("SELECT prestige_tokens FROM prestige_stats WHERE player_id = " .. guid)
        local tokens = tq and tq:GetUInt32(0) or 0
        if tokens < GOLDEN_TOKENS then
            SendUI(player, "RESULT", "R", "ERR", "You need " .. GOLDEN_TOKENS .. " Prestige Token(s)")
            return
        end
        CharDBQuery("UPDATE prestige_stats SET prestige_tokens = " .. (tokens - GOLDEN_TOKENS) .. " WHERE player_id = " .. guid)
    else
        local cost = RollCostFor(item, row)
        if player:GetCoinage() < cost then
            SendUI(player, "RESULT", "R", "ERR", "Not enough gold")
            return
        end
        player:ModifyMoney(-cost)
    end

    CharDBQuery("DELETE FROM character_item_enchantments WHERE item_guid = " .. itemGuid)
    CharDBQuery("INSERT INTO character_item_enchantments (item_guid, enchantment_id) VALUES (" .. itemGuid .. ", " .. e.id .. ")")

    local color = QUALITY_COLOR[e.quality] or "|cff1eff00"
    player:SendBroadcastMessage("|cff00ff00[Mystic Enchant]|r " .. color .. "[" .. e.name .. "]|r bound to " .. item:GetItemLink() .. "!")

    invSignature[guid] = nil
    CheckEquipChanges(player)
    SendBalance(player)
    SendUI(player, "RESULT", "R", "OK", key)
end

local function ResolveTransferPair(player, sKey, sEntry, dKey, dEntry)
    local src, srcRow, err = ResolveServiceItem(player, sKey, sEntry)
    if not src then return nil, nil, nil, nil, "Source: " .. err end
    local dst, dstRow, err2 = ResolveServiceItem(player, dKey, dEntry)
    if not dst then return nil, nil, nil, nil, "Destination: " .. err2 end
    if src:GetGUIDLow() == dst:GetGUIDLow() then
        return nil, nil, nil, nil, "Source and destination are the same item"
    end
    if not srcRow or srcRow <= 0 or not enchants[srcRow] then
        return nil, nil, nil, nil, "The source item has no Mystic Enchant"
    end
    return src, srcRow, dst, dstRow, nil
end

local function QuoteTransfer(player, sKey, sEntry, dKey, dEntry)
    local src, srcRow, dst, dstRow, err = ResolveTransferPair(player, sKey, sEntry, dKey, dEntry)
    if not src then
        SendUI(player, "QUOTE", "T", "ERR", err)
        return
    end
    local e = enchants[srcRow]
    local cost = TRANSFER_COST[e.quality] or 100000
    local dstName, dstQual = "", 0
    if dstRow and dstRow > 0 and enchants[dstRow] then
        dstName, dstQual = enchants[dstRow].name, enchants[dstRow].quality
    end
    SendUI(player, "QUOTE", "T", "OK", cost, e.quality, e.name, dstQual, dstName)
end

local function DoTransfer(player, sKey, sEntry, dKey, dEntry)
    local src, srcRow, dst, dstRow, err = ResolveTransferPair(player, sKey, sEntry, dKey, dEntry)
    if not src then
        SendUI(player, "RESULT", "T", "ERR", err)
        return
    end

    local e = enchants[srcRow]
    local cost = TRANSFER_COST[e.quality] or 100000
    if player:GetCoinage() < cost then
        SendUI(player, "RESULT", "T", "ERR", "Not enough gold")
        return
    end
    player:ModifyMoney(-cost)

    -- Source keeps a rolled-nothing marker (no free re-imbue); destination
    -- takes the enchant, overwriting any it had (client confirms first).
    CharDBQuery("DELETE FROM character_item_enchantments WHERE item_guid IN (" .. src:GetGUIDLow() .. ", " .. dst:GetGUIDLow() .. ")")
    CharDBQuery("INSERT INTO character_item_enchantments (item_guid, enchantment_id) VALUES (" .. src:GetGUIDLow() .. ", 0), (" .. dst:GetGUIDLow() .. ", " .. srcRow .. ")")

    local color = QUALITY_COLOR[e.quality] or "|cff1eff00"
    player:SendBroadcastMessage("|cff00ff00[Mystic Enchant]|r " .. color .. "[" .. e.name .. "]|r transferred to " .. dst:GetItemLink() .. "!")

    local guid = player:GetGUIDLow()
    invSignature[guid] = nil
    CheckEquipChanges(player)
    SendBalance(player)
    SendUI(player, "RESULT", "T", "OK", dKey)
end

local function HandleServiceGossip(player, creature, intid)
    player:GossipComplete()
    SendUI(player, "OPENUI")
    SendBalance(player)
    PushEnchantMap(player)
end

-- Whisper protocol dispatcher (also serves RETooltip's map resync).
local whisperWindow = {}  -- playerGuidLow -> { windowStart, count }

local function OnWhisper(_, player, msg, _, _, _)
    if not RE_ENABLE then return end
    msg = msg:gsub("%s+$", "")
    if msg:sub(1, 5) ~= "SDRE_" then return end

    local guid = player:GetGUIDLow()
    local now = os.time()
    local limit = whisperWindow[guid]
    if not limit or limit.windowStart ~= now then
        whisperWindow[guid] = { windowStart = now, count = 1 }
    else
        if limit.count >= 10 then
            return false
        end
        limit.count = limit.count + 1
    end

    if msg == "SDRE_SYNC" then
        PushEnchantMap(player)
    elseif msg == "SDRE_BAL" then
        SendBalance(player)
    else
        local args = {}
        for part in msg:gmatch("[^;]+") do
            args[#args + 1] = part
        end
        if args[1] == "SDRE_QUOTE" and args[2] == "R" and args[4] then
            QuoteRoll(player, args[3], args[4])
        elseif args[1] == "SDRE_ROLL" and (args[2] == "G" or args[2] == "T") and args[5] == nil and args[4] then
            DoRoll(player, args[2], args[3], args[4])
        elseif args[1] == "SDRE_QUOTE" and args[2] == "T" and args[6] then
            QuoteTransfer(player, args[3], args[4], args[5], args[6])
        elseif args[1] == "SDRE_XFER" and args[5] then
            DoTransfer(player, args[2], args[3], args[4], args[5])
        end
    end
    return false
end

if RE_ENABLE then
    -- Cross-file API: spelldraft_npc.lua routes Nibbs gossip intids 3000-3999 here.
    SpellDraftRE = { HandleGossip = HandleServiceGossip }

    -- Sweep enchant rows whose item instances no longer exist (deleted,
    -- disenchanted, expired mail). Runs once per script load.
    CharDBExecute("DELETE ci FROM character_item_enchantments ci LEFT JOIN item_instance ii ON ii.guid = ci.item_guid WHERE ii.guid IS NULL")

    RegisterPlayerEvent(42, OnCommand)             -- PLAYER_EVENT_ON_COMMAND
    RegisterPlayerEvent(32, OnLootItem)            -- PLAYER_EVENT_ON_LOOT_ITEM
    RegisterPlayerEvent(51, OnQuestRewardItem)     -- PLAYER_EVENT_ON_QUEST_REWARD_ITEM
    RegisterPlayerEvent(52, OnCreateItem)          -- PLAYER_EVENT_ON_CREATE_ITEM
    RegisterPlayerEvent(56, OnGroupRollRewardItem) -- PLAYER_EVENT_ON_GROUP_ROLL_REWARD_ITEM
    RegisterPlayerEvent(29, OnEquip)               -- PLAYER_EVENT_ON_EQUIP
    RegisterPlayerEvent(3, OnLogin)                -- PLAYER_EVENT_ON_LOGIN
    RegisterPlayerEvent(4, OnLogout)               -- PLAYER_EVENT_ON_LOGOUT
    RegisterPlayerEvent(19, OnWhisper)             -- PLAYER_EVENT_ON_WHISPER
    RegisterPlayerEvent(64, OnAuraApply)           -- PLAYER_EVENT_ON_AURA_APPLY
    RegisterPlayerEvent(67, OnAuraRemove)          -- PLAYER_EVENT_ON_AURA_REMOVE
    RegisterPlayerEvent(5, OnProcSpellCast)        -- PLAYER_EVENT_ON_SPELL_CAST
    RegisterPlayerEvent(69, OnProcMeleeDamage)     -- PLAYER_EVENT_ON_MODIFY_MELEE_DAMAGE
    RegisterPlayerEvent(72, OnProcDealDamage)      -- PLAYER_EVENT_ON_DEAL_DAMAGE
    RegisterPlayerEvent(65, OnProcHeal)            -- PLAYER_EVENT_ON_HEAL
    RegisterPlayerEvent(7, OnProcKill)             -- PLAYER_EVENT_ON_KILL_CREATURE
end
