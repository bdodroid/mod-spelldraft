-- TotemBarFix.lua — let the totem bar (MultiCastActionBarFrame) and the
-- stance/shapeshift bar (ShapeshiftBarFrame) coexist on classless characters.
--
-- Stock 3.3.5 FrameXML makes the two bars mutually exclusive:
--   * UIParent_ManageFramePositions() force-hides the totem bar whenever the
--     stance bar is shown, and only shows it when the C-side
--     HasMultiCastActionBar() returns true (shaman-only).
--   * Both bars share the same managed anchor above MainMenuBar, so when both
--     manage to show they overlap.
--   * ShowMultiCastActionBar() early-outs while bar.state == "top", so simply
--     re-showing after the forced hide does nothing; the queued hide-slide has
--     to be cancelled via the bar's mode/state fields before OnUpdate runs.

-- The draft system grants totem spells without the shaman multi-cast summon
-- spells (66842-66844), so spell-knowledge checks are useless here. The
-- reliable signal is the bar's own content: MultiCastActionBarFrame_Update()
-- counts populated slots into bar.numActiveSlots from the C-side totem data,
-- which works for any class that knows totem spells.
local function PlayerHasTotemBar()
    local bar = MultiCastActionBarFrame
    return bar ~= nil and (bar.numActiveSlots or 0) > 0
end

-- HasMultiCastActionBar() is a shaman-gated C function the default UI uses to
-- decide whether a totem bar exists at all; widen it to any character whose
-- totem bar has content.
local Blizzard_HasMultiCastActionBar = HasMultiCastActionBar
HasMultiCastActionBar = function()
    return Blizzard_HasMultiCastActionBar() or PlayerHasTotemBar()
end

local reanchoring = false

local function AdjustTotemBar()
    local bar = MultiCastActionBarFrame
    if not bar or not PlayerHasTotemBar() then
        return
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return
    end

    if ShapeshiftBarFrame and ShapeshiftBarFrame:IsShown() then
        -- Cancel the hide-slide UIParent_ManageFramePositions() just queued,
        -- before MultiCastActionBarFrame_OnUpdate acts on it.
        bar.mode = "none"
        bar.completed = true
        bar.state = "top"
        if not bar:IsShown() then
            bar:Show()
        end
        -- Stack above the stance bar instead of overlapping it
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", ShapeshiftBarFrame, "TOPLEFT", 0, 8)
    else
        -- No stance bar: normalize state so the stock show path works again
        -- (ShowMultiCastActionBar refuses to run while state == "top").
        if not bar:IsShown() and bar.state == "top" then
            bar.state = "bottom"
        end
        -- Only intervene if we left the bar anchored to the now-hidden stance
        -- bar; otherwise leave placement to Blizzard's layout manager, which
        -- correctly offsets for the bottom-left multibar and rep/XP bars.
        local _, relativeTo = bar:GetPoint(1)
        if relativeTo == ShapeshiftBarFrame and not reanchoring then
            reanchoring = true
            UIParent_ManageFramePositions()
            reanchoring = false
        end
        if not bar:IsShown() then
            ShowMultiCastActionBar()
        end
    end
end

-- /totemfix — print bar state and force a re-adjust (debugging aid)
SLASH_SPELLDRAFTTOTEMFIX1 = "/totemfix"
SlashCmdList["SPELLDRAFTTOTEMFIX"] = function()
    local bar = MultiCastActionBarFrame
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "TotemBarFix: slots=%d shown=%s mode=%s state=%s blizzHas=%s forms=%d stanceShown=%s",
        bar and (bar.numActiveSlots or 0) or -1,
        tostring(bar and bar:IsShown()),
        tostring(bar and bar.mode),
        tostring(bar and bar.state),
        tostring(Blizzard_HasMultiCastActionBar()),
        GetNumShapeshiftForms() or 0,
        tostring(ShapeshiftBarFrame and ShapeshiftBarFrame:IsShown())))
    AdjustTotemBar()
end

-- ---------------------------------------------------------------------------
-- Totem timer icons (TotemFrame) — the per-totem duration markers attached to
-- the player frame. Stock anchors ("TOPLEFT", PlayerFrame, "TOPLEFT", 65, -55;
-- 28, -75 with a pet frame) sit on top of the player frame's bottom power bar,
-- so push them further down. TotemFrame_Update re-applies the stock anchor on
-- every totem change, so this must be a post-hook, not a one-time move.
-- ---------------------------------------------------------------------------

local TOTEM_TIMER_EXTRA_Y = 20 -- extra pixels below the stock position

local function AdjustTotemTimers()
    if not TotemFrame then
        return
    end
    TotemFrame:ClearAllPoints()
    if PetFrame and PetFrame:IsShown() then
        TotemFrame:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 28, -75 - TOTEM_TIMER_EXTRA_Y)
    else
        TotemFrame:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 65, -55 - TOTEM_TIMER_EXTRA_Y)
    end
end

if TotemFrame then
    hooksecurefunc("TotemFrame_Update", AdjustTotemTimers)
    AdjustTotemTimers()
    if PetFrame then
        -- Pet appearing/disappearing switches the stock anchor without a totem update
        PetFrame:HookScript("OnShow", AdjustTotemTimers)
        PetFrame:HookScript("OnHide", AdjustTotemTimers)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
watcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
watcher:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
watcher:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
watcher:RegisterEvent("PLAYER_TALENT_UPDATE")
watcher:RegisterEvent("LEARNED_SPELL_IN_TAB")

local function OnDelayedUpdate(self)
    self:SetScript("OnUpdate", nil)
    AdjustTotemBar()
end

-- Defer one frame so the default UI finishes its own layout pass first
local function QueueAdjust()
    watcher:SetScript("OnUpdate", OnDelayedUpdate)
end

watcher:SetScript("OnEvent", QueueAdjust)

-- Runs in the same execution as the stock hide, before OnUpdate can slide the
-- bar away — this is what actually cancels the mutual exclusion.
hooksecurefunc("UIParent_ManageFramePositions", AdjustTotemBar)
hooksecurefunc("MultiCastActionBarFrame_Update", AdjustTotemBar)

if ShapeshiftBarFrame then
    ShapeshiftBarFrame:HookScript("OnShow", QueueAdjust)
    ShapeshiftBarFrame:HookScript("OnHide", QueueAdjust)
end
