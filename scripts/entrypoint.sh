#!/bin/bash
set -euo pipefail

## =============================================================================
## Palworld Windows Dedicated Server — Proton entrypoint
## =============================================================================
## Flow: install/update via SteamCMD → install UE4SS → copy mods → start server
## =============================================================================

## Palworld 1.0 renamed the executable from -Test to -Shipping-Cmd
SERVER_EXE_10="${SERVER_DIR}/Pal/Binaries/Win64/PalServer-Win64-Shipping-Cmd.exe"
SERVER_EXE_EA="${SERVER_DIR}/Pal/Binaries/Win64/PalServer-Win64-Test.exe"
SERVER_EXE="${SERVER_EXE_10}"  ## default to 1.0, fall back to Early Access
if [ ! -f "${SERVER_EXE_10}" ] && [ -f "${SERVER_EXE_EA}" ]; then
    SERVER_EXE="${SERVER_EXE_EA}"
fi
WIN64_DIR="${SERVER_DIR}/Pal/Binaries/Win64"
SETTINGS_DIR="${SERVER_DIR}/Pal/Saved/Config/WindowsServer"
SETTINGS_FILE="${SETTINGS_DIR}/PalWorldSettings.ini"
UE4SS_URL="https://github.com/Okaetsu/RE-UE4SS/releases/download/experimental-palworld/UE4SS-Palworld.zip"

log() { echo -e "\033[32;1m>>> $1 <<<\033[0m"; }

## -----------------------------------------------------------------------------
## Install or update the Palworld Windows server via SteamCMD
## The +@sSteamCmdForcePlatformType windows flag is critical — it downloads
## the Windows binaries instead of Linux, which is required for UE4SS mods.
## -----------------------------------------------------------------------------
install_server() {
    log "Installing/Updating Palworld Windows Server (AppID ${APPID})"

    ## Fix permissions: Unraid uses FUSE-mounted volumes where chown may
    ## silently fail. Use chmod to ensure writeability regardless of filesystem.
    ## -R is needed because failed installs leave root-owned subdirectories.
    ## Also fix SteamCMD's own directory — it switches from root to steam internally.
    chmod -R 777 "${SERVER_DIR}" 2>/dev/null || true
    chown -R steam:steam /home/steam 2>/dev/null || true

    local manifest_arg=""
    if [ -n "${TARGET_MANIFEST_ID:-}" ]; then
        log "Pinning to manifest ${TARGET_MANIFEST_ID}"
        manifest_arg="-manifest ${TARGET_MANIFEST_ID}"
    fi

    ## Run SteamCMD as the steam user via gosu. This avoids the internal
    ## root→steam switch which can fail when the steam home dir isn't writable.
    gosu steam "${STEAMCMD}" \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "${SERVER_DIR}" \
        +login anonymous \
        +app_update "${APPID}" ${manifest_arg} validate \
        +quit
}

## -----------------------------------------------------------------------------
## Install UE4SS (Palworld-specific build with MemberVariableLayout.ini fix)
## UE4SS only supports Windows, which is why we run the Windows server via Proton.
## Files installed: dwmapi.dll (loader) + ue4ss/ folder in Pal/Binaries/Win64/
## -----------------------------------------------------------------------------
install_ue4ss() {
    if [ "${ENABLE_UE4SS:-true}" != "true" ]; then
        log "UE4SS installation skipped (ENABLE_UE4SS != true)"
        return 0
    fi

    if [ -f "${WIN64_DIR}/dwmapi.dll" ]; then
        log "UE4SS already installed, skipping"
        return 0
    fi

    log "Installing UE4SS (Palworld experimental build)"
    curl -sL "${UE4SS_URL}" -o /tmp/ue4ss.zip
    unzip -q /tmp/ue4ss.zip -d "${WIN64_DIR}"
    rm -f /tmp/ue4ss.zip

    ## Configure UE4SS for headless dedicated server
    local ini="${WIN64_DIR}/UE4SS-settings.ini"
    if [ -f "${ini}" ]; then
        sed -i 's/GuiConsoleEnabled *= *1/GuiConsoleEnabled = 0/' "${ini}"
        sed -i 's/GuiConsoleVisible *= *1/GuiConsoleVisible = 0/' "${ini}"
        sed -i 's/bUseUObjectArrayCache *= *true/bUseUObjectArrayCache = false/' "${ini}"
        sed -i 's/GraphicsAPI *= *opengl/GraphicsAPI = dx11/' "${ini}"
        log "UE4SS configured for dedicated server (GUI off, UObjectArrayCache off, DX11)"
    fi
}

## -----------------------------------------------------------------------------
## Copy mods from mounted /mods volume into the server tree
##   /mods/Win64/  → UE4SS Lua/DLL mods  → Pal/Binaries/Win64/Mods/
##   /mods/pak/    → .pak file mods      → Pal/Content/Paks/
## -----------------------------------------------------------------------------
install_mods() {
    if [ -d "/mods/Win64" ]; then
        log "Installing UE4SS mods from /mods/Win64"
        mkdir -p "${WIN64_DIR}/Mods"
        cp -r /mods/Win64/* "${WIN64_DIR}/Mods/" 2>/dev/null || true
    fi

    if [ -d "/mods/pak" ]; then
        log "Installing pak mods from /mods/pak"
        mkdir -p "${SERVER_DIR}/Pal/Content/Paks"
        cp -r /mods/pak/* "${SERVER_DIR}/Pal/Content/Paks/" 2>/dev/null || true
    fi
}

## -----------------------------------------------------------------------------
## Ensure PalWorldSettings.ini exists (copy from DefaultPalWorldSettings.ini)
## Palworld 1.0: 119 total option keys (88 pre-1.0 + 31 new). The default
## template ships with all keys — we only override specific ones via env vars.
## -----------------------------------------------------------------------------
ensure_settings() {
    if [ ! -f "${SETTINGS_FILE}" ]; then
        log "Creating PalWorldSettings.ini from defaults"
        mkdir -p "${SETTINGS_DIR}"
        local default="${SERVER_DIR}/DefaultPalWorldSettings.ini"
        if [ -f "${default}" ]; then
            cp "${default}" "${SETTINGS_FILE}"
        else
            touch "${SETTINGS_FILE}"
        fi
    fi

    ## WorldOption.sav override: if the world was first created in-game,
    ## WorldOption.sav overrides PalWorldSettings.ini entirely. Warn the user.
    local save_dir="${SERVER_DIR}/Pal/Saved/SaveGames"
    if [ -d "${save_dir}" ]; then
        local world_opt
        world_opt=$(find "${save_dir}" -name "WorldOption.sav" 2>/dev/null | head -1)
        if [ -n "${world_opt}" ]; then
            log "WARNING: WorldOption.sav found at ${world_opt}"
            log "WorldOption.sav overrides PalWorldSettings.ini — env var settings may not apply"
            log "To fix: back up and delete WorldOption.sav, or set config before first world launch"
        fi
    fi
}

## -----------------------------------------------------------------------------
## Apply environment variables to PalWorldSettings.ini
## Palworld reads identity/network settings from this file, not CLI args.
## We use sed to update specific fields in the OptionSettings tuple.
## Note: Palworld 1.0 has 119 config keys — we only manage the high-value ones
## here. For gameplay rates (EXP, capture, etc.) edit the ini directly.
## -----------------------------------------------------------------------------
update_settings() {
    [ -f "${SETTINGS_FILE}" ] || return 0

    log "Applying server settings from environment variables"

    ## Disable exit-on-error: sed -i can fail on FUSE/network filesystems
    ## even when the underlying file is writable. We'd rather skip one
    ## broken setting than kill the entire container.
    set +e

    ## Helper: replace a FieldName="value" or FieldName=value in the ini
    set_field() {
        local field="$1" value="$2" quote="${3:-true}"
        if [ "${quote}" = "true" ]; then
            sed -i "s/${field}=\"[^\"]*\"/${field}=\"${value}\"/" "${SETTINGS_FILE}"
        else
            sed -i "s/${field}=[0-9]*/${field}=${value}/" "${SETTINGS_FILE}"
        fi
    }

    ## Helper: replace boolean fields (True/False)
    set_bool() {
        local field="$1" value="$2"
        sed -i "s/${field}=\(True\|False\)/${field}=${value}/" "${SETTINGS_FILE}"
    }

    ## Helper: replace tuple fields like CrossplayPlatforms=(Steam,Xbox,PS5,Mac)
    set_tuple() {
        local field="$1" value="$2"
        sed -i "s/${field}=([^)]*)/${field}=(${value})/" "${SETTINGS_FILE}"
    }

    ## Server identity
    [ -n "${SERVER_NAME:-}" ] && set_field ServerName "${SERVER_NAME}"
    [ -n "${SERVER_DESCRIPTION:-}" ] && set_field ServerDescription "${SERVER_DESCRIPTION}"
    [ -n "${ADMIN_PASSWORD:-}" ] && set_field AdminPassword "${ADMIN_PASSWORD}"
    [ -n "${SERVER_PASSWORD:-}" ] && set_field ServerPassword "${SERVER_PASSWORD}"
    [ -n "${MAX_PLAYERS:-}" ] && set_field ServerPlayerMaxNum "${MAX_PLAYERS}" false

    ## Network (1.0: RCON and REST API are also configurable in the ini)
    [ -n "${RCON_ENABLED:-}" ] && set_bool RCONEnabled "$(to_bool "${RCON_ENABLED}")"
    [ -n "${RCON_PORT:-}" ] && set_field RCONPort "${RCON_PORT}" false
    [ -n "${REST_API_ENABLED:-}" ] && set_bool RESTAPIEnabled "$(to_bool "${REST_API_ENABLED}")"
    [ -n "${REST_API_PORT:-}" ] && set_field RESTAPIPort "${REST_API_PORT}" false

    ## Public IP/port (for NAT/multi-homed setups — only advertises, doesn't change listen port)
    [ -n "${PUBLIC_IP:-}" ] && set_field PublicIP "${PUBLIC_IP}"
    [ -n "${PUBLIC_PORT:-}" ] && set_field PublicPort "${PUBLIC_PORT}" false

    ## Crossplay (1.0: CrossplayPlatforms tuple in PalWorldSettings.ini)
    [ -n "${CROSSPLAY_PLATFORMS:-}" ] && set_tuple CrossplayPlatforms "${CROSSPLAY_PLATFORMS}"

    ## PvP (1.0: requires all three toggles on together)
    if [ "${ENABLE_PVP:-false}" = "true" ]; then
        set_bool bIsPvP True
        set_bool bEnablePlayerToPlayerDamage True
        set_bool bEnableDefenseOtherGuildPlayer True
        log "PvP enabled (bIsPvP + bEnablePlayerToPlayerDamage + bEnableDefenseOtherGuildPlayer)"
    fi

    ## Gameplay multipliers (only set if non-empty — otherwise ini defaults apply)
    [ -n "${DIFFICULTY:-}" ] && set_field Difficulty "${DIFFICULTY}"
    [ -n "${EXP_RATE:-}" ] && set_field ExpRate "${EXP_RATE}" false
    [ -n "${PAL_CAPTURE_RATE:-}" ] && set_field PalCaptureRate "${PAL_CAPTURE_RATE}" false
    [ -n "${PAL_SPAWN_NUM_RATE:-}" ] && set_field PalSpawnNumRate "${PAL_SPAWN_NUM_RATE}" false
    [ -n "${PAL_EGG_HATCHING_TIME:-}" ] && set_field PalEggDefaultHatchingTime "${PAL_EGG_HATCHING_TIME}" false
    [ -n "${WORK_SPEED_RATE:-}" ] && set_field WorkSpeedRate "${WORK_SPEED_RATE}" false
    [ -n "${DAYTIME_SPEED_RATE:-}" ] && set_field DayTimeSpeedRate "${DAYTIME_SPEED_RATE}" false
    [ -n "${NIGHTTIME_SPEED_RATE:-}" ] && set_field NightTimeSpeedRate "${NIGHTTIME_SPEED_RATE}" false
    [ -n "${COLLECTION_DROP_RATE:-}" ] && set_field CollectionDropRate "${COLLECTION_DROP_RATE}" false
    [ -n "${ENEMY_DROP_ITEM_RATE:-}" ] && set_field EnemyDropItemRate "${ENEMY_DROP_ITEM_RATE}" false
    [ -n "${DEATH_PENALTY:-}" ] && set_field DeathPenalty "${DEATH_PENALTY}"

    ## Pal/player stat rates
    [ -n "${PAL_STOMACH_DECREACE_RATE:-}" ] && set_field PalStomachDecreaceRate "${PAL_STOMACH_DECREACE_RATE}" false
    [ -n "${PAL_STAMINA_DECREACE_RATE:-}" ] && set_field PalStaminaDecreaceRate "${PAL_STAMINA_DECREACE_RATE}" false
    [ -n "${PLAYER_STOMACH_DECREACE_RATE:-}" ] && set_field PlayerStomachDecreaceRate "${PLAYER_STOMACH_DECREACE_RATE}" false
    [ -n "${PLAYER_STAMINA_DECREACE_RATE:-}" ] && set_field PlayerStaminaDecreaceRate "${PLAYER_STAMINA_DECREACE_RATE}" false
    [ -n "${PAL_DAMAGE_RATE_ATTACK:-}" ] && set_field PalDamageRateAttack "${PAL_DAMAGE_RATE_ATTACK}" false
    [ -n "${PAL_DAMAGE_RATE_DEFENSE:-}" ] && set_field PalDamageRateDefense "${PAL_DAMAGE_RATE_DEFENSE}" false
    [ -n "${PLAYER_DAMAGE_RATE_ATTACK:-}" ] && set_field PlayerDamageRateAttack "${PLAYER_DAMAGE_RATE_ATTACK}" false
    [ -n "${PLAYER_DAMAGE_RATE_DEFENSE:-}" ] && set_field PlayerDamageRateDefense "${PLAYER_DAMAGE_RATE_DEFENSE}" false

    ## Base/guild limits
    [ -n "${BASE_CAMP_MAX_NUM:-}" ] && set_field BaseCampMaxNum "${BASE_CAMP_MAX_NUM}" false
    [ -n "${BASE_CAMP_WORKER_MAX_NUM:-}" ] && set_field BaseCampWorkerMaxNum "${BASE_CAMP_WORKER_MAX_NUM}" false
    [ -n "${GUILD_PLAYER_MAX_NUM:-}" ] && set_field GuildPlayerMaxNum "${GUILD_PLAYER_MAX_NUM}" false
    [ -n "${DROP_ITEM_MAX_NUM:-}" ] && set_field DropItemMaxNum "${DROP_ITEM_MAX_NUM}" false

    ## Invader enemy (disabling halves RAM — useful for constrained servers)
    [ -n "${ENABLE_INVADER_ENEMY:-}" ] && set_bool bEnableInvaderEnemy "$(to_bool "${ENABLE_INVADER_ENEMY}")"

    ## Restore strict error handling for the rest of the script
    set -e
}

## Convert "true"/"false" strings to "True"/"False" for UE ini format
to_bool() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        true|1|yes) echo "True" ;;
        *) echo "False" ;;
    esac
}

## -----------------------------------------------------------------------------
## Start scheduled backups via supercronic (if enabled)
## -----------------------------------------------------------------------------
setup_backup_cron() {
    if [ "${BACKUP_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    local cron_expr="${BACKUP_CRON_EXPRESSION:-0 0 * * *}"
    log "Starting scheduled backups (cron: ${cron_expr})"

    echo "${cron_expr} /usr/local/bin/backup" > /tmp/crontab
    supercronic /tmp/crontab &
}

## -----------------------------------------------------------------------------
## Start the Palworld Windows server via Proton
## -----------------------------------------------------------------------------
start_server() {
    log "Starting Palworld Server via ${PROTON_VERSION}"

    local args=""

    ## Community server mode (shows up in community server browser)
    if [ "${COMMUNITY:-false}" = "true" ]; then
        args="${args} EpicApp=PalServer"
    fi

    ## Multithreading flags (improve performance on multi-core CPUs)
    if [ "${MULTITHREADING:-true}" = "true" ]; then
        args="${args} -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS"
    fi

    ## Port overrides
    args="${args} -port=${PORT:-8211}"
    args="${args} -queryport=${QUERY_PORT:-27015}"

    ## RCON
    if [ "${RCON_ENABLED:-false}" = "true" ]; then
        args="${args} -rcon -rconport=${RCON_PORT:-25575}"
    fi

    ## REST API
    if [ "${REST_API_ENABLED:-false}" = "true" ]; then
        args="${args} -restapi -restapiport=${REST_API_PORT:-8212}"
    fi

    ## Fix ownership then drop to steam user.
    ## chmod -R 777 is already done by install_server for Unraid FUSE compat.
    ## chown is skipped — can fail silently on FUSE volumes.
    chown -R steam:steam "${SERVER_DIR}" 2>/dev/null || true

    ## cd into the Win64 directory — Proton can get confused by unix pathing
    ## if the working directory doesn't match the exe location
    echo "Launch command: ${PROTON} run ${SERVER_EXE}${args}"
    cd "${WIN64_DIR}"
    exec gosu steam "${PROTON}" run "${SERVER_EXE}" ${args}
}

## =============================================================================
## Main
## =============================================================================

## Install or update server
if [ ! -f "${SERVER_EXE}" ]; then
    log "Server not found, performing fresh install"
    install_server
elif [ "${ALWAYS_UPDATE_ON_START:-false}" = "true" ]; then
    install_server
fi

## Install UE4SS and mods
install_ue4ss
install_mods

## Ensure settings file exists
ensure_settings
log "DEBUG: after ensure_settings"
update_settings
log "DEBUG: after update_settings"

## Start scheduled backups (if enabled)
setup_backup_cron
log "DEBUG: after setup_backup_cron"

## Start the server
start_server
