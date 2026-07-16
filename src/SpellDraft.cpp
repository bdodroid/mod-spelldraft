#include "Player.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ScriptMgr.h"
#include "ScriptDefines/PlayerScript.h"
#include "ScriptDefines/WorldScript.h"
#include "Spell.h"

#include <vector>

class SpellDraftPlayerScript : public PlayerScript
{
private:
    static bool IsBotSession(Player const* player)
    {
#ifdef MOD_PLAYERBOTS
        return player->GetSession() && player->GetSession()->IsBot();
#else
        return false;
#endif
    }

    void UpdateBaseMana(Player* player)
    {
        if (player->getPowerType() == POWER_MANA)
            return; // Caster class — let core handle it

        uint32 level = player->GetLevel();
        uint32 baseMana = 150 + level * 45;
        player->SetUInt32Value(UNIT_FIELD_BASE_MANA, baseMana);
    }

public:
    SpellDraftPlayerScript() : PlayerScript("SpellDraftPlayerScript",
    {
        PLAYERHOOK_ON_PLAYER_HAS_ACTIVE_POWER_TYPE,
        PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_AFTER_UPDATE_MAX_POWER,
        PLAYERHOOK_ON_LEVEL_CHANGED
    }) {}

    // 1. Prevent AzerothCore's stats update loop from erasing a Lua-set Mana pool on Rogues/Warriors.
    void OnPlayerAfterUpdateMaxPower(Player* player, Powers& power, float& value) override
    {
        if (!sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
            return;
        if (IsBotSession(player))
            return;
        if (power != POWER_MANA)
            return;
        if (player->getPowerType() == POWER_MANA)
            return;  // Native caster — let the core's calculation stand.
        if (value > 0.0f)
            return;  // Has native mana — let it stand.

        // Non-caster classes: keep the previously assigned max mana value.
        uint32 current = player->GetMaxPower(POWER_MANA);
        if (current > 0)
            value = static_cast<float>(current);
    }

    // 2. Allow non-native resources (Rage/Energy/Mana) to generate and spend natively in combat.
    bool OnPlayerHasActivePowerType(Player const* player, Powers power) override
    {
        if (!sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
            return false;
        if (IsBotSession(player))
            return false; // Bots keep native power handling.
        if (player->getPowerType() == power)
            return false; // Native power type — let core handle it.

        // If the player has a max pool > 0 (assigned during draft), activate it.
        return player->GetMaxPower(power) > 0;
    }

    // 3. Grant full weapon and armor proficiencies on login and sync to the client.
    void OnPlayerLogin(Player* player) override
    {
        if (!sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
            return;
        if (IsBotSession(player))
            return;

        UpdateBaseMana(player);

        // Grant full weapon and armor proficiency so the client tooltips show them as usable (not red).
        uint32 allWeapons = (1u << MAX_ITEM_SUBCLASS_WEAPON) - 1u;
        uint32 allArmor   = (1u << MAX_ITEM_SUBCLASS_ARMOR)  - 1u;

        player->AddWeaponProficiency(allWeapons);
        player->AddArmorProficiency(allArmor);
        player->SendProficiency(ITEM_CLASS_WEAPON, player->GetWeaponProficiency());
        player->SendProficiency(ITEM_CLASS_ARMOR,  player->GetArmorProficiency());

        // Enable maximum weapon skills so they don't miss attacks.
        uint32 weaponSkills[] = { 43, 44, 45, 46, 54, 55, 136, 160, 162, 172, 173, 176, 229, 313, 315 };
        uint32 maxSkillValue = player->GetLevel() * 5;
        if (maxSkillValue > 400)
            maxSkillValue = 400; // Cap at 400 for Level 80

        for (uint32 skillId : weaponSkills)
        {
            if (!player->HasSkill(skillId))
                player->SetSkill(skillId, 0, 1, maxSkillValue);
            else
                player->SetSkill(skillId, 0, maxSkillValue, maxSkillValue);
        }
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (!sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
            return;
        if (IsBotSession(player))
            return;

        UpdateBaseMana(player);
    }
};

static bool IsHealingOrResurrectionSpell(SpellInfo const* spellInfo)
{
    if (spellInfo->IsPassive())
        return false;

    for (auto const& effect : spellInfo->GetEffects())
    {
        switch (effect.Effect)
        {
            case SPELL_EFFECT_HEAL:
            case SPELL_EFFECT_HEAL_PCT:
            case SPELL_EFFECT_HEAL_MAX_HEALTH:
            case SPELL_EFFECT_HEAL_MECHANICAL:
            case SPELL_EFFECT_RESURRECT:
            case SPELL_EFFECT_RESURRECT_NEW:
            case SPELL_EFFECT_SELF_RESURRECT:
                return true;
            default:
                break;
        }

        if (effect.Effect == SPELL_EFFECT_APPLY_AURA && effect.ApplyAuraName == SPELL_AURA_PERIODIC_HEAL)
            return true;
    }
    return false;
}

static bool IsDruidShapeshiftSpell(SpellInfo const* spellInfo)
{
    if (spellInfo->SpellFamilyName != SPELLFAMILY_DRUID)
        return false;

    for (auto const& effect : spellInfo->GetEffects())
        if (effect.ApplyAuraName == SPELL_AURA_MOD_SHAPESHIFT)
            return true;

    return false;
}

// Mode 2 (Mystic Enchants): while the marker aura is active, spells of the
// given family (0 = any class) may be cast in the druid forms covered by
// formMask (bit is form - 1, the Spell.dbc Stances convention). Rules live in
// the world DB table `custom_form_casting_rules`, seeded together with their
// marker auras and enchant rows by 26_druid_form_casting_enchant.sql — new
// enchants need no C++ change.
struct EnchantCastRule
{
    uint32 markerAura;
    uint32 spellFamily;
    uint32 formMask;
};

static std::vector<EnchantCastRule> _enchantCastRules;

class SpellDraftWorldScript : public WorldScript
{
public:
    SpellDraftWorldScript() : WorldScript("SpellDraftWorldScript", { WORLDHOOK_ON_STARTUP }) {}

    void OnStartup() override
    {
        _enchantCastRules.clear();
        QueryResult result = WorldDatabase.Query(
            "SELECT marker_aura, spell_family, form_mask FROM custom_form_casting_rules");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                _enchantCastRules.push_back(
                    { fields[0].Get<uint32>(), fields[1].Get<uint32>(), fields[2].Get<uint32>() });
            } while (result->NextRow());
        }
        LOG_INFO("module", "[SpellDraft] Loaded {} form-casting enchant rules.", _enchantCastRules.size());
    }
};

// Druid-family utility that Tree of Life natively permits (its StancesNot in
// native Spell.dbc lacks the tree bit): cures, Mark/Gift of the Wild, Thorns,
// Nature's Grasp, Nature's Swiftness, Barkskin — all ranks.
static bool IsTreeFormUtilitySpell(uint32 spellId)
{
    switch (spellId)
    {
        case 22812:                                            // Barkskin
        case 17116:                                            // Nature's Swiftness
        case 2782:                                             // Remove Curse
        case 8946:                                             // Cure Poison
        case 2893:                                             // Abolish Poison
        case 1126: case 5232: case 6756: case 5234:            // Mark of the Wild
        case 8907: case 9884: case 9885: case 26990: case 48469:
        case 21849: case 21850: case 26991: case 48470:        // Gift of the Wild
        case 467: case 782: case 1075: case 8914:              // Thorns
        case 9756: case 9910: case 26992: case 53307:
        case 16689: case 16810: case 16811: case 16812:        // Nature's Grasp
        case 16813: case 17329: case 27009: case 53312:
            return true;
        default:
            return false;
    }
}

class SpellDraftSpellScript : public AllSpellScript
{
public:
    SpellDraftSpellScript() : AllSpellScript("SpellDraftSpellScript") {}

    void OnSpellCheckCast(Spell* spell, bool strict, SpellCastResult& res) override
    {
        if (!sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
            return;

        uint32 castMode = sConfigMgr->GetOption<int32>("SpellDraft.AllowSpellsInDruidForms", 0);

        Unit* caster = spell->GetCaster();
        if (!caster)
            return;

        Player* player = caster->ToPlayer();
        if (!player)
            return;

        uint32 form = caster->GetShapeshiftForm();
        if (form == FORM_NONE)
            return;

        if (form == FORM_CAT || form == FORM_TREE || form == FORM_TRAVEL ||
            form == FORM_AQUA || form == FORM_BEAR || form == FORM_DIREBEAR ||
            form == FORM_MOONKIN || form == FORM_FLIGHT || form == FORM_FLIGHT_EPIC)
        {
            // Mode 1: Allow casting all spells in Druid forms
            if (castMode == 1)
            {
                res = SPELL_CAST_OK;
                return;
            }

            // Mode 2: Allow casting based on active Mystic Enchants / Auras,
            // limited to the specific forms each enchant covers.
            if (castMode == 2)
            {
                if (SpellInfo const* spellInfo = spell->GetSpellInfo())
                {
                    for (auto const& rule : _enchantCastRules)
                    {
                        if ((rule.formMask & (uint32(1) << (form - 1)))
                            && (rule.spellFamily == 0 || spellInfo->SpellFamilyName == rule.spellFamily)
                            && player->HasAura(rule.markerAura))
                        {
                            res = SPELL_CAST_OK;
                            return;
                        }
                    }
                }

                // No matching enchant for this spell in this form:
                // fall through to the native shapeshift rules below.
            }

            // Otherwise (castMode == 0, or castMode == 2 but no matching enchant was
            // active), re-enforce native WoW shapeshift rules. The deployed server
            // DBCs are patched (SHAPESHIFT_FLAG_STANCE added to the feral forms,
            // Druid form bits cleared from StancesNot) so that modes 1/2 can work —
            // SpellInfo::CheckShapeshift therefore no longer blocks anything, and
            // this hook must supply exactly the checks that patch disabled.
            if (strict && !spell->HasTriggeredCastFlag(TRIGGERED_IGNORE_SHAPESHIFT))
            {
                SpellInfo const* spellInfo = spell->GetSpellInfo();
                if (!spellInfo)
                    return;

                if (spellInfo->IsPassive())
                    return;

                // Druid shapeshift spells themselves are always allowed (the client
                // patch stops the client from cancelling the form before the cast).
                if (IsDruidShapeshiftSpell(spellInfo))
                    return;

                // Spells whose Stances mask includes this form (Maul, Nature's Grasp, ...).
                if (spellInfo->Stances & (uint32(1) << (form - 1)))
                    return;

                // Feral forms (the ones the DBC patch stance-flagged): replicate the
                // core's disabled actAsShifted branch. Spells with no stance data and
                // no attribute (potions, racials, items, generic spells) stay allowed,
                // exactly as native servers allow them.
                if (form == FORM_CAT || form == FORM_TRAVEL || form == FORM_AQUA ||
                    form == FORM_BEAR || form == FORM_DIREBEAR)
                {
                    if (spellInfo->HasAttribute(SPELL_ATTR0_NOT_SHAPESHIFTED))
                        res = SPELL_FAILED_NOT_SHAPESHIFT;
                    else if (spellInfo->Stances != 0)
                        res = SPELL_FAILED_ONLY_SHAPESHIFT;
                }
                // Moonkin: natively blocked casts are the StancesNot data the DBC
                // patch erased — healing/resurrection spells plus Nature's Swiftness.
                else if (form == FORM_MOONKIN)
                {
                    if (IsHealingOrResurrectionSpell(spellInfo) || spellInfo->Id == 17116)
                        res = SPELL_FAILED_NOT_SHAPESHIFT;
                }
                // Tree of Life: the erased StancesNot data covered the Druid
                // damage/balance spells. Non-Druid spells, items, and heals keep
                // their native (allowed) behaviour; stance-requiring Druid spells
                // (Thorns, Innervate, ...) are decided by the core's intact
                // stance-flag branch or the allowlist below.
                else if (form == FORM_TREE)
                {
                    if (spellInfo->SpellFamilyName == SPELLFAMILY_DRUID
                        && !IsHealingOrResurrectionSpell(spellInfo)
                        && !IsTreeFormUtilitySpell(spellInfo->Id))
                        res = SPELL_FAILED_NOT_SHAPESHIFT;
                }
                // Flight forms are not touched by the DBC patch, so the core's own
                // CheckShapeshift still enforces native rules there — nothing to do.
            }
        }
    }
};

void AddSpellDraftScripts()
{
    new SpellDraftPlayerScript();
    new SpellDraftSpellScript();
    new SpellDraftWorldScript();
}

