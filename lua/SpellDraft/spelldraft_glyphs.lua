--[[
    spelldraft_glyphs.lua — Custom Glyph system (native glyph UI).

    Custom glyphs are defined entirely in SQL (23_custom_glyphs.sql):
    glyphproperties_dbc + spell_dbc rows make the native socketing pipeline
    work; this script only drives the COSMETIC side. It reads the player's six
    native glyph slots (player:GetGlyph) against the `custom_glyphs` registry
    and hands display overrides to the RE engine (spelldraft_re.lua), which
    merges them into its activeDisplays flow via the SpellDraftGlyphs global:

        SpellDraftGlyphs.GetDisplays(player)  -> array of {formAuras, display}
        SpellDraftGlyphs.GetSignature(player) -> string, changes when glyph
                                                 slots change (drives resync)

    Loads before spelldraft_re.lua (alphabetical); the RE engine guards every
    call with `if SpellDraftGlyphs`.
]]

local MAX_GLYPH_SLOTS = 6

local glyphs = {}      -- glyph_id -> { name, display = {formAuras=set, display=id} | nil }
local glyphCount = 0

-- Parses display handler_data "5487,9634:31094" (same format as RE enchants).
local function ParseDisplayData(data)
    local auraPart, displayId = data:match("^([%d,]+):(%d+)$")
    if not auraPart then return nil end
    local formAuras = {}
    for id in auraPart:gmatch("%d+") do
        formAuras[tonumber(id)] = true
    end
    return { formAuras = formAuras, display = tonumber(displayId) }
end

do
    -- Probe via information_schema first: a direct query against a missing
    -- table is a FATAL error during worldserver startup (crash loop).
    local probe = WorldDBQuery([[
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'custom_glyphs'
    ]])
    if not probe then
        print("[SpellDraft] Custom glyph system disabled: table custom_glyphs is missing."
            .. " Apply data/sql/db-world/23_custom_glyphs.sql and restart.")
        return
    end

    local q = WorldDBQuery("SELECT glyph_id, name, handler, handler_data FROM custom_glyphs")
    if q then
        repeat
            local g = { name = q:GetString(1) }
            local handler = q:GetString(2)
            if handler == "display" then
                g.display = ParseDisplayData(q:GetString(3))
            elseif handler == "proc" then
                g.proc = q:GetString(3)
            end
            glyphs[q:GetUInt32(0)] = g
            glyphCount = glyphCount + 1
        until not q:NextRow()
    end
    print("[SpellDraft] Custom glyph system loaded " .. glyphCount .. " glyph definitions.")
end

SpellDraftGlyphs = {
    -- Display overrides granted by currently socketed custom glyphs.
    GetDisplays = function(player)
        local out = {}
        for slot = 0, MAX_GLYPH_SLOTS - 1 do
            local g = glyphs[player:GetGlyph(slot)]
            if g and g.display then
                out[#out + 1] = g.display
            end
        end
        return out
    end,

    -- Proc recipe keys granted by currently socketed custom glyphs.
    GetProcs = function(player)
        local out = {}
        for slot = 0, MAX_GLYPH_SLOTS - 1 do
            local g = glyphs[player:GetGlyph(slot)]
            if g and g.proc then
                out[g.proc] = true
            end
        end
        return out
    end,

    -- Cheap change-detection string over the six glyph slots.
    GetSignature = function(player)
        local parts = {}
        for slot = 0, MAX_GLYPH_SLOTS - 1 do
            parts[#parts + 1] = player:GetGlyph(slot)
        end
        return table.concat(parts, ",")
    end,
}
