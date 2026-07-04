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

# ── 4. REBUILD WORLDSERVER IMAGE ───────────────────────────────
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
