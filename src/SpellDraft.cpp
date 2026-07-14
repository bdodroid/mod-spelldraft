#include "Player.h"
#include "Config.h"
#include "ScriptMgr.h"
#include "ScriptDefines/PlayerScript.h"
#include "Spell.h"

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

class SpellDraftSpellScript : public AllSpellScript
{
public:
    SpellDraftSpellScript() : AllSpellScript("SpellDraftSpellScript") {}

    void OnSpellCheckCast(Spell* spell, bool /*strict*/, SpellCastResult& res) override
    {
        if (!sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
            return;

        if (!sConfigMgr->GetOption<bool>("SpellDraft.AllowSpellsInDruidForms", false))
            return;

        if (res == SPELL_FAILED_ONLY_SHAPESHIFT || res == SPELL_FAILED_NOT_SHAPESHIFT)
        {
            if (Unit* caster = spell->GetCaster())
            {
                if (caster->ToPlayer())
                {
                    uint32 form = caster->GetShapeshiftForm();
                    if (form == FORM_CAT || form == FORM_TREE || form == FORM_TRAVEL ||
                        form == FORM_AQUA || form == FORM_BEAR || form == FORM_DIREBEAR ||
                        form == FORM_MOONKIN)
                    {
                        res = SPELL_CAST_OK;
                    }
                }
            }
        }
    }
};

void AddSpellDraftScripts()
{
    new SpellDraftPlayerScript();
    new SpellDraftSpellScript();
}

