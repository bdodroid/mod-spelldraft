#!/bin/bash
#
# install.sh
# Automated server-side installation script for the SpellDraft module.
# Automatically detects server environment, deploys Lua/DBC files, and triggers C++ rebuild.
#

# Resolve script directory to use as default module directory
MODULE_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$(cd "$MODULE_DIR/../.." && pwd)"

# Verify server root directory has AzerothCore files
if [ ! -f "$SERVER_DIR/docker-compose.yml" ] && [ ! -d "$SERVER_DIR/apps/docker" ]; then
    echo "Error: Could not locate AzerothCore server root directory relative to this module."
    echo "Make sure mod-spelldraft is cloned inside the server's 'modules/' folder."
    exit 1
fi

echo "============================================="
echo "  SpellDraft Module - Server Installation"
echo "============================================="

# ── 1. STAGE LUA SCRIPTS ──────────────────────────────────────
LUA_TARGET_DIR="$SERVER_DIR/env/dist/etc/modules/lua_scripts"
mkdir -p "$LUA_TARGET_DIR"

echo "Staging Lua scripts to: $LUA_TARGET_DIR"



# Copy config file to the root of target lua_scripts_dir
cp "$MODULE_DIR/lua/spelldraft_config.lua" "$LUA_TARGET_DIR/"

# Ensure the SpellDraft subdirectory exists in target lua_scripts_dir
mkdir -p "$LUA_TARGET_DIR/SpellDraft"

# Copy all Eluna scripts to the subdirectory
cp -r "$MODULE_DIR/lua/SpellDraft/"* "$LUA_TARGET_DIR/SpellDraft/"
echo "Lua scripts successfully staged."

# ── 2. STAGE CONFIGURATION FILE ──────────────────────────────────
CONF_TARGET_DIR="$SERVER_DIR/env/dist/etc/modules"
if [ -d "$CONF_TARGET_DIR" ]; then
    if [ ! -f "$CONF_TARGET_DIR/mod_spelldraft.conf" ]; then
        cp "$MODULE_DIR/conf/mod_spelldraft.conf.dist" "$CONF_TARGET_DIR/mod_spelldraft.conf"
        echo "Created default configuration file: $CONF_TARGET_DIR/mod_spelldraft.conf"
    else
        echo "Configuration file mod_spelldraft.conf already exists, skipping overwrite."
    fi
fi

# ── 3. DETECT DBC DIRECTORY & DEPLOY DBC FILES ─────────────────────
DBC_DIR=""

# Determine if running under Docker/Podman
if command -v podman >/dev/null 2>&1 || command -v docker >/dev/null 2>&1; then
    # Set rootless Podman DOCKER_HOST if socket exists
    if [ -z "$DOCKER_HOST" ] && [ -S "/run/user/$(id -u)/podman/podman.sock" ]; then
        export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
    fi

    # Find the container management tool
    CTR_TOOL="docker"
    if command -v podman >/dev/null 2>&1; then
        CTR_TOOL="podman"
    fi

    # Query the database client-data named volume
    VOL_NAME=""
    for v in $($CTR_TOOL volume ls -q); do
        if [[ "$v" == *"ac-client-data"* ]]; then
            VOL_NAME="$v"
            break
        fi
    done

    if [ -n "$VOL_NAME" ]; then
        MOUNT_POINT=$($CTR_TOOL volume inspect "$VOL_NAME" --format '{{.Mountpoint}}' 2>/dev/null)
        if [ -d "$MOUNT_POINT" ]; then
            DBC_DIR="$MOUNT_POINT/dbc"
        fi
    fi
fi

# Fallback to local compile path if container volume not found
if [ -z "$DBC_DIR" ]; then
    DBC_DIR="$SERVER_DIR/env/dist/data/dbc"
fi

# Deploy DBCs if directory found
if [ -d "$DBC_DIR" ]; then
    echo "Deploying custom DBC files to: $DBC_DIR"
    if cp "$MODULE_DIR/dbc/"*.dbc "$DBC_DIR/"; then
        echo "DBC files successfully copied."
    else
        echo "Error: Failed to copy DBC files to $DBC_DIR."
        echo "You may need elevated permissions. Otherwise, copy the contents of dbc/ manually into your server's Data/dbc/ folder."
    fi
else
    echo "Warning: Could not automatically locate your server's DBC directory."
    echo "Please copy the contents of dbc/ manually into your server's Data/dbc/ folder."
fi

# ── 4. PATCH CORE C++ FOR COMBO POINTS ──────────────────────────
UNIT_CPP="$SERVER_DIR/src/server/game/Entities/Unit/Unit.cpp"
if [ -f "$UNIT_CPP" ]; then
    if ! grep -q "SpellDraftCP" "$UNIT_CPP"; then
        echo "Patching Unit.cpp to support combo points for classless builds..."
        python3 -c '
import sys
unit_cpp = sys.argv[1]
with open(unit_cpp, "r", encoding="utf-8") as f:
    content = f.read()

target = "playerMe->SendDirectMessage(&data);"

replacement = """playerMe->SendDirectMessage(&data);

        // Send custom SpellDraft addon message for custom combo point rendering
        std::string prefix = "SpellDraftCP";
        std::string message = std::to_string(m_comboPoints);
        std::string fullmsg = prefix + "\\t" + message;

        WorldPacket addonData(SMSG_MESSAGECHAT, 100);
        addonData << uint8(0); // CHAT_MSG_ADDON (Whisper/Normal channel context)
        addonData << int32(LANG_ADDON);
        addonData << playerMe->GetGUID();
        addonData << uint32(0);
        addonData << playerMe->GetGUID();
        addonData << uint32(fullmsg.length() + 1);
        addonData << fullmsg;
        addonData << uint8(0);
        playerMe->GetSession()->SendPacket(&addonData);"""

if target in content:
    content = content.replace(target, replacement, 1)
    with open(unit_cpp, "w", encoding="utf-8") as f:
        f.write(content)
    print("Unit.cpp successfully patched.")
else:
    print("Error: Could not locate target block in Unit.cpp.")
    sys.exit(1)
' "$UNIT_CPP"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to patch Unit.cpp. Aborting installation."
            exit 1
        fi
    else
        echo "Unit.cpp is already patched for SpellDraft combo points."
    fi
else
    echo "Warning: Could not locate Unit.cpp at $UNIT_CPP. Skipping core patch."
fi

# ── 4.5. PATCH CORE C++ FOR PET TRAINERS ──────────────────────────
TRAINER_CPP="$SERVER_DIR/src/server/game/Entities/Creature/Trainer.cpp"
if [ -f "$TRAINER_CPP" ]; then
    if ! grep -q "SpellDraft.Enable" "$TRAINER_CPP"; then
        echo "Patching Trainer.cpp to support pet trainers for all classes..."
        python3 -c '
import sys
trainer_cpp = sys.argv[1]
with open(trainer_cpp, "r", encoding="utf-8") as f:
    content = f.read()

target_inc = "#include \"Trainer.h\""
replacement_inc = "#include \"Trainer.h\"\\n#include \"Config.h\""

target_pet = """            case Type::Class:
            case Type::Pet:
                // check class for class trainers
                return player->getClass() == GetTrainerRequirement();"""

replacement_pet = """            case Type::Class:
                // check class for class trainers
                return player->getClass() == GetTrainerRequirement();
            case Type::Pet:
                // check class for pet trainers (allow any class if SpellDraft is enabled)
                if (sConfigMgr->GetOption<bool>("SpellDraft.Enable", true))
                    return true;
                return player->getClass() == GetTrainerRequirement();"""

if target_inc in content and target_pet in content:
    content = content.replace(target_inc, replacement_inc, 1)
    content = content.replace(target_pet, replacement_pet, 1)
    with open(trainer_cpp, "w", encoding="utf-8") as f:
        f.write(content)
    print("Trainer.cpp successfully patched.")
else:
    print("Error: Could not locate target blocks in Trainer.cpp.")
    sys.exit(1)
' "$TRAINER_CPP"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to patch Trainer.cpp. Aborting installation."
            exit 1
        fi
    else
        echo "Trainer.cpp is already patched for SpellDraft pet trainers."
    fi
else
    echo "Warning: Could not locate Trainer.cpp at $TRAINER_CPP. Skipping core patch."
fi

# ── 4.6. PATCH CORE C++ FOR PLAYER.H STABLES ──────────────────────────
PLAYER_H="$SERVER_DIR/src/server/game/Entities/Player/Player.h"
if [ -f "$PLAYER_H" ]; then
    if ! grep -q "ShowCustomStableMenu" "$PLAYER_H"; then
        echo "Patching Player.h to support custom stable gossip helper declarations..."
        python3 -c '
import sys
player_h = sys.argv[1]
with open(player_h, "r", encoding="utf-8") as f:
    content = f.read()

target = "void OnGossipSelect(WorldObject* source, uint32 gossipListId, uint32 menuId);"
replacement = """void OnGossipSelect(WorldObject* source, uint32 gossipListId, uint32 menuId);
    void ShowCustomStableMenu(WorldObject* source);
    void HandleCustomStableGossip(WorldObject* source, uint32 action);"""

if target in content:
    content = content.replace(target, replacement, 1)
    with open(player_h, "w", encoding="utf-8") as f:
        f.write(content)
    print("Player.h successfully patched.")
else:
    print("Error: Could not locate target block in Player.h.")
    sys.exit(1)
' "$PLAYER_H"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to patch Player.h. Aborting installation."
            exit 1
        fi
    else
        echo "Player.h is already patched for custom stable gossip helper declarations."
    fi
else
    echo "Warning: Could not locate Player.h at $PLAYER_H. Skipping core patch."
fi

# ── 4.7. PATCH CORE C++ FOR PLAYERGOSSIP.CPP STABLES ──────────────────
PLAYERGOSSIP_CPP="$SERVER_DIR/src/server/game/Entities/Player/PlayerGossip.cpp"
if [ -f "$PLAYERGOSSIP_CPP" ]; then
    if ! grep -q "ShowCustomStableMenu" "$PLAYERGOSSIP_CPP"; then
        echo "Patching PlayerGossip.cpp to support custom stable gossip..."
        python3 -c '
import sys
playergossip_cpp = sys.argv[1]
with open(playergossip_cpp, "r", encoding="utf-8") as f:
    content = f.read()

target_inc = "#include \"WorldSession.h\""
replacement_inc = "#include \"WorldSession.h\"\\n#include \"DatabaseEnv.h\""

target_select = """    uint32 gossipOptionId = item->OptionType;
    ObjectGuid guid = source->GetGUID();"""

replacement_select = """    uint32 gossipOptionId = item->OptionType;
    ObjectGuid guid = source->GetGUID();

    if (gossipOptionId >= 1000)
    {
        HandleCustomStableGossip(source, gossipOptionId);
        return;
    }"""

target_gossip = """        case GOSSIP_OPTION_STABLEPET:
            GetSession()->SendStablePet(guid);
            break;"""

replacement_gossip = """        case GOSSIP_OPTION_STABLEPET:
            if (sConfigMgr->GetOption<bool>("SpellDraft.Enable", true) && getClass() != CLASS_HUNTER)
            {
                ShowCustomStableMenu(source);
            }
            else
            {
                GetSession()->SendStablePet(guid);
            }
            break;"""

target_menu = """            menu->GetGossipMenu().AddMenuItem(itr->second.OptionID, itr->second.OptionIcon, strOptionText, 0, itr->second.OptionType, strBoxText, itr->second.BoxMoney, itr->second.BoxCoded);"""

replacement_menu = """            uint32 optionType = itr->second.OptionType;
            uint8 optionIcon = itr->second.OptionIcon;
            if (optionType == GOSSIP_OPTION_STABLEPET && sConfigMgr->GetOption<bool>("SpellDraft.Enable", true) && getClass() != CLASS_HUNTER)
            {
                optionType = 1007;
                optionIcon = GOSSIP_ICON_CHAT;
            }

            menu->GetGossipMenu().AddMenuItem(itr->second.OptionID, optionIcon, strOptionText, 0, optionType, strBoxText, itr->second.BoxMoney, itr->second.BoxCoded);"""

target_end = """void Player::ToggleInstantFlight()
{
    m_isInstantFlightOn = !m_isInstantFlightOn;
}"""

replacement_end = """void Player::ToggleInstantFlight()
{
    m_isInstantFlightOn = !m_isInstantFlightOn;
}

void Player::ShowCustomStableMenu(WorldObject* source)
{
    PlayerTalkClass->ClearMenus();

    PetStable* petStable = GetPetStable();
    if (!petStable)
    {
        petStable = &GetOrInitPetStable();
    }

    Pet* pet = GetPet();

    if (pet && pet->IsAlive() && pet->getPetType() == HUNTER_PET)
    {
        std::string label = "Stable current pet: " + pet->GetName() + " (Level " + std::to_string(pet->GetLevel()) + ")";
        PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, GOSSIP_ICON_CHAT, label, 0, 1001, "", 0, false);
    }
    else if (petStable->CurrentPet)
    {
        std::string label = "Call pet: " + petStable->CurrentPet->Name + " (Level " + std::to_string(uint32(petStable->CurrentPet->Level)) + ")";
        PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, GOSSIP_ICON_CHAT, label, 0, 1006, "", 0, false);

        std::string labelStable = "Stable pet: " + petStable->CurrentPet->Name + " (Level " + std::to_string(uint32(petStable->CurrentPet->Level)) + ")";
        PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, GOSSIP_ICON_CHAT, labelStable, 0, 1001, "", 0, false);
    }

    for (uint32 i = 0; i < petStable->MaxStabledPets; ++i)
    {
        if (petStable->StabledPets[i])
        {
            std::string label = "Retrieve stabled pet " + std::to_string(i + 1) + ": " +
                                petStable->StabledPets[i]->Name + " (Level " +
                                std::to_string(uint32(petStable->StabledPets[i]->Level)) + ")";
            PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, GOSSIP_ICON_CHAT, label, 0, 1002 + i, "", 0, false);
        }
        else
        {
            PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, GOSSIP_ICON_CHAT, "Stable slot " + std::to_string(i + 1) + " [Empty]", 0, 1000, "", 0, false);
        }
    }

    PlayerTalkClass->GetGossipMenu().AddMenuItem(-1, GOSSIP_ICON_CHAT, "Goodbye", 0, GOSSIP_OPTION_QUESTGIVER, "", 0, false);
    PlayerTalkClass->SendGossipMenu(4783, source->GetGUID());
}

void Player::HandleCustomStableGossip(WorldObject* source, uint32 action)
{
    PetStable* petStable = GetPetStable();
    if (!petStable)
        return;

    if (action == 1007) // Initial click on stable master option
    {
        ShowCustomStableMenu(source);
    }
    else if (action == 1001) // Stable pet
    {
        Pet* pet = GetPet();
        int freeSlot = -1;
        for (uint32 i = 0; i < petStable->MaxStabledPets; ++i)
        {
            if (!petStable->StabledPets[i])
            {
                freeSlot = i;
                break;
            }
        }

        if (freeSlot == -1)
        {
            ChatHandler(GetSession()).SendNotification("Your stable is full!");
            ShowCustomStableMenu(source);
            return;
        }

        if (pet)
        {
            RemovePet(pet, PetSaveMode(PET_SAVE_FIRST_STABLE_SLOT + freeSlot));
            std::swap(petStable->StabledPets[freeSlot], petStable->CurrentPet);
            ChatHandler(GetSession()).SendNotification("Pet stabled successfully.");
        }
        else if (petStable->CurrentPet)
        {
            CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_CHAR_PET_SLOT_BY_ID);
            stmt->SetData(0, PetSaveMode(PET_SAVE_FIRST_STABLE_SLOT + freeSlot));
            stmt->SetData(1, GetGUID().GetCounter());
            stmt->SetData(2, petStable->CurrentPet->PetNumber);
            CharacterDatabase.Execute(stmt);

            petStable->StabledPets[freeSlot] = std::move(petStable->CurrentPet);
            petStable->CurrentPet.reset();
            ChatHandler(GetSession()).SendNotification("Pet stabled successfully.");
        }

        ShowCustomStableMenu(source);
    }
    else if (action >= 1002 && action <= 1005) // Retrieve pet
    {
        uint32 slot = action - 1002;
        if (slot >= petStable->MaxStabledPets || !petStable->StabledPets[slot])
        {
            ShowCustomStableMenu(source);
            return;
        }

        Pet* activePet = GetPet();
        if (activePet)
        {
            RemovePet(activePet, PetSaveMode(PET_SAVE_FIRST_STABLE_SLOT + slot));
            std::swap(petStable->StabledPets[slot], petStable->CurrentPet);

            uint32 petnumber = petStable->CurrentPet->PetNumber;
            Pet* newPet = new Pet(this, HUNTER_PET);
            if (!newPet->LoadPetFromDB(this, 0, petnumber, false))
            {
                delete newPet;
                ChatHandler(GetSession()).SendNotification("Failed to load pet.");
            }
            else
            {
                CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_CHAR_PET_SLOT_BY_ID);
                stmt->SetData(0, PET_SAVE_AS_CURRENT);
                stmt->SetData(1, GetGUID().GetCounter());
                stmt->SetData(2, petnumber);
                CharacterDatabase.Execute(stmt);
                ChatHandler(GetSession()).SendNotification("Pets swapped successfully.");
            }
        }
        else
        {
            petStable->CurrentPet = std::move(petStable->StabledPets[slot]);
            petStable->StabledPets[slot].reset();

            uint32 petnumber = petStable->CurrentPet->PetNumber;
            Pet* newPet = new Pet(this, HUNTER_PET);
            if (!newPet->LoadPetFromDB(this, 0, petnumber, false))
            {
                delete newPet;
                ChatHandler(GetSession()).SendNotification("Failed to load pet.");
            }
            else
            {
                CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_UPD_CHAR_PET_SLOT_BY_ID);
                stmt->SetData(0, PET_SAVE_AS_CURRENT);
                stmt->SetData(1, GetGUID().GetCounter());
                stmt->SetData(2, petnumber);
                CharacterDatabase.Execute(stmt);
                ChatHandler(GetSession()).SendNotification("Pet retrieved successfully.");
            }
        }

        ShowCustomStableMenu(source);
    }
    else if (action == 1006) // Call pet
    {
        if (petStable->CurrentPet)
        {
            uint32 petnumber = petStable->CurrentPet->PetNumber;
            Pet* newPet = new Pet(this, HUNTER_PET);
            if (!newPet->LoadPetFromDB(this, 0, petnumber, false))
            {
                delete newPet;
                ChatHandler(GetSession()).SendNotification("Failed to call pet.");
            }
            else
            {
                ChatHandler(GetSession()).SendNotification("Pet called successfully.");
            }
        }
        ShowCustomStableMenu(source);
    }
    else
    {
        ShowCustomStableMenu(source);
    }
}"""

if target_inc in content:
    content = content.replace(target_inc, replacement_inc, 1)
if target_menu in content:
    content = content.replace(target_menu, replacement_menu, 1)
if target_select in content:
    content = content.replace(target_select, replacement_select, 1)
if target_gossip in content:
    content = content.replace(target_gossip, replacement_gossip, 1)
if target_end in content:
    content = content.replace(target_end, replacement_end, 1)

with open(playergossip_cpp, "w", encoding="utf-8") as f:
    f.write(content)
print("PlayerGossip.cpp successfully patched.")
' "$PLAYERGOSSIP_CPP"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to patch PlayerGossip.cpp. Aborting installation."
            exit 1
        fi
    else
        echo "PlayerGossip.cpp is already patched for custom stable gossip."
    fi
else
    echo "Warning: Could not locate PlayerGossip.cpp at $PLAYERGOSSIP_CPP. Skipping core patch."
fi

# ── 5. REBUILD WORLDSERVER IMAGE ───────────────────────────────
if [ -f "$SERVER_DIR/docker-compose.yml" ]; then
    echo "---------------------------------------------"
    echo "Rebuilding worldserver container image to compile SpellDraft C++..."
    
    # Detect an available compose command.
    # Docker options are tried first so Docker-only hosts behave exactly as before;
    # the podman fallbacks are only reached when no docker compose is available.
    COMPOSE_CMD=""
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    elif podman compose version >/dev/null 2>&1; then
        COMPOSE_CMD="podman compose"
    elif command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_CMD="podman-compose"
    fi

    if [ -z "$COMPOSE_CMD" ]; then
        echo "No Docker/Podman compose tool detected. Please compile the C++ changes manually (e.g. using CMake)."
        echo "============================================="
        echo "  SpellDraft Server Installation Complete!"
        echo "============================================="
        exit 0
    fi

    if (cd "$SERVER_DIR" && $COMPOSE_CMD build ac-worldserver); then
        echo "---------------------------------------------"
        echo "Rebuild complete. Please restart your server container to apply updates."
    else
        echo "Error: Docker build failed."
        exit 1
    fi
fi

echo "============================================="
echo "  SpellDraft Server Installation Complete!"
echo "============================================="
