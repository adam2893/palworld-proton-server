# Palworld Proton Server

Run a **modded Palworld dedicated server** on Linux via Docker. Downloads the Windows server binary through SteamCMD and runs it with GE-Proton -- enabling UE4SS server-side mods (Lua and DLL) that only work on Windows.

## Why Proton

UE4SS, the mod framework for Palworld, only supports Windows. The native Linux Palworld server cannot run UE4SS mods. This container forces SteamCMD to download the **Windows** server binary (`+@sSteamCmdForcePlatformType windows`) and runs it through GE-Proton on Linux. No virtual machine, no GPU passthrough -- just a headless Dedicated Server in a container.

## Quick Start (Docker Compose)

```bash
git clone https://github.com/adam2893/palworld-proton-server.git
cd palworld-proton-server
cp .env.example .env
# Edit .env -- set ADMIN_PASSWORD and any gameplay rates
docker compose build
docker compose up -d
docker compose logs -f
```

First boot takes 5-10 minutes (SteamCMD downloads the ~12-15GB server, Proton sets up the Wine prefix). Subsequent starts are faster with `ALWAYS_UPDATE_ON_START=false`.

You should see "wine: RLIMIT_NICE is <= 20" in the logs -- this means the server booted successfully under Proton.

## Quick Start (Unraid)

Copy and paste this block into the Unraid terminal (WebUI > Terminal):

```bash
mkdir -p /mnt/user/appdata/palworld-proton-server/{game,mods/Win64,mods/pak}
mkdir -p /boot/config/plugins/dockerMan/templates-user/
curl -sL https://raw.githubusercontent.com/adam2893/palworld-proton-server/main/scripts/unraid-install.sh | bash
```

Then go to Docker tab > Add Container, select "palworld-proton-server" from the dropdown, set your admin password, and click Apply.

## Container Features

- **Mod support** -- UE4SS auto-installed from the Okaetsu experimental-palworld build (includes MemberVariableLayout.ini fix required for Palworld 0.4.15+). Place UE4SS mods in `mods/Win64/` and .pak mods in `mods/pak/` on the host.
- **RCON console** -- `docker exec palworld-server rcon-cli "Save"` / `"ShowPlayers"` / `"Broadcast Hello"` / `"Shutdown 30 Restarting"`
- **Scheduled backups** -- Enable with `BACKUP_ENABLED=true`. Runs via supercronic. Saves the world via RCON before tarring SaveGames. Old backup cleanup configurable.
- **Healthcheck** -- Detects if the Windows server process dies under Proton.
- **Version pinning** -- Set `TARGET_MANIFEST_ID` to lock the server to a specific Steam build, preventing game updates from breaking UE4SS mods. Find manifest IDs on SteamDB (app 2394010).
- **Gameplay config via env vars** -- EXP rate, capture rate, egg hatch time, death penalty, base/guild limits, Pal/player stats, PvP, crossplay, and more -- all configurable from your `.env` file or Docker Compose environment block.

## Palworld 1.0 (July 10, 2026)

This image is built for Palworld 1.0, the full release exiting Early Access:

- **119 PalWorldSettings.ini keys** (88 unchanged + 31 new). All pre-1.0 configs work without migration.
- **Full crossplay** -- `CrossplayPlatforms=(Steam,Xbox,PS5,Mac)`, set via `CROSSPLAY_PLATFORMS` env var.
- **PvP mode** -- Enable with `ENABLE_PVP=true`. Sets all three required toggles (`bIsPvP`, `bEnablePlayerToPlayerDamage`, `bEnableDefenseOtherGuildPlayer`).
- **RAM requirements increased** -- 16GB minimum for small servers, 32GB recommended for community servers. The map roughly doubles in size.
- **Memory leak fixed** -- The 24h uptime memory leak that plagued Early Access dedicated servers is fixed in 1.0.
- **Server clustering** -- Binary groundwork exists but no supported config path yet. Watch for future patches.

### 1.0 Mod Compatibility

Palworld 1.0 recompiles the executable, breaking static memory pointers that UE4SS relies on. The Okaetsu UE4SS build was updated on July 10, 2026 (launch day) but does not explicitly confirm 1.0 compatibility. Test vanilla first, then add mods one at a time. Always delete old mod files -- do not just disable them.

## Image

Available on GitHub Container Registry:

```bash
docker pull ghcr.io/adam2893/palworld-proton-server:latest
```

Image size: ~1.7GB (cm2network/steamcmd base ~140MB + tools ~7MB + GE-Proton ~1.5GB). The Palworld server itself (12-15GB) downloads at runtime to the mounted volume.

The container is automatically built and pushed on every push to `main` via GitHub Actions. See `.github/workflows/docker-build.yml`.

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8211 | UDP | Game port (required) |
| 27015 | UDP | Steam query (community server browser) |
| 25575 | TCP | RCON (do not expose publicly) |
| 8212 | TCP | REST API (do not expose publicly) |

## Key Configuration

All gameplay env vars are optional -- leave blank to use PalWorldSettings.ini defaults.

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | `"My Palworld Server"` | Server name in the browser |
| `ADMIN_PASSWORD` | `"changeme"` | Admin password for RCON and REST API -- **change this** |
| `SERVER_PASSWORD` | `""` | Password to join (blank = open) |
| `MAX_PLAYERS` | `32` | Max concurrent players (hard cap 32) |
| `RCON_ENABLED` | `true` | Remote console for admin commands |
| `REST_API_ENABLED` | `false` | HTTP admin API |
| `COMMUNITY` | `false` | Show in community server browser |
| `CROSSPLAY_PLATFORMS` | `Steam,Xbox,PS5,Mac` | Platforms allowed to connect |
| `ENABLE_PVP` | `false` | Sets all three PvP toggles |
| `EXP_RATE` | `""` | XP multiplier (1.0 = vanilla) |
| `PAL_CAPTURE_RATE` | `""` | Capture multiplier |
| `PAL_EGG_HATCHING_TIME` | `""` | Hours to hatch eggs (72 = vanilla) |
| `DEATH_PENALTY` | `""` | `None`, `Item`, `ItemAndEquipment`, or `All` |
| `ENABLE_INVADER_ENEMY` | `""` | Base raids (set to `false` to roughly halve RAM) |
| `DIFFICULTY` | `""` | `None` (custom rates), `Casual`, `Normal`, `Hard` |
| `TARGET_MANIFEST_ID` | `""` | Lock to a specific Steam build |
| `BACKUP_ENABLED` | `false` | Scheduled backups via supercronic |
| `BACKUP_CRON_EXPRESSION` | `"0 0 * * *"` | Cron schedule for backups (midnight daily) |
| `ENABLE_UE4SS` | `true` | Auto-install UE4SS mod framework |
| `ALWAYS_UPDATE_ON_START` | `false` | Run SteamCMD validation on every start |

Full 119-key reference: [gamesomg.com/palworld-server-settings-explained](https://gamesomg.com/palworld-server-settings-explained/)

## Manual Commands

```bash
# RCON
docker exec palworld-server rcon-cli "Save"
docker exec palworld-server rcon-cli "ShowPlayers"
docker exec palworld-server rcon-cli "Broadcast Server restarting in 5 minutes"
docker exec palworld-server rcon-cli "Shutdown 30 Restarting for maintenance"

# Backup
docker exec palworld-server backup

# Force update on next start
docker compose exec palworld-server bash -c 'ALWAYS_UPDATE_ON_START=true /entrypoint.sh'
```

## Mod Installation

Place mods in the host directories before starting the container:

- **UE4SS mods** (Lua scripts, DLLs): `mods/Win64/` -- copied to `Pal/Binaries/Win64/Mods/` inside the container
- **Pak mods**: `mods/pak/` -- copied to `Pal/Content/Paks/` inside the container

UE4SS mods must be enabled via `mods.txt` inside the game volume (`game/Pal/Binaries/Win64/Mods/mods.txt`) with the format `ModFolderName : 1` (one per line). The entrypoint does not manage this file -- edit it manually.

## Architecture

- **Base image:** `cm2network/steamcmd:root` (Debian slim + SteamCMD, Valve-recommended)
- **Proton:** GE-Proton (GloriousEggroll) pinned via build arg, extracted into `compatibilitytools.d/`
- **Wine prefix:** Pre-seeded from Proton's `default_pfx` for fast first boot
- **UE4SS:** Okaetsu/RE-UE4SS `experimental-palworld` build with `MemberVariableLayout.ini`
- **Entrypoint:** SteamCMD install > UE4SS install > mod copy > PalWorldSettings.ini from env > Proton launch

Key paths inside the container:
- `/palworld/Pal/Binaries/Win64/PalServer-Win64-Test.exe` -- server executable
- `/palworld/Pal/Binaries/Win64/ue4ss/` -- UE4SS framework
- `/palworld/Pal/Binaries/Win64/Mods/` -- UE4SS mods
- `/palworld/Pal/Content/Paks/` -- .pak mods
- `/palworld/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini` -- server config
- `/home/steam/.steam/steam/compatibilitytools.d/` -- Proton installation
- `/home/steam/.steam/steam/steamapps/compatdata/2394010/` -- Wine prefix

## Common Issues

**"wine: RLIMIT_NICE is <= 20" in logs** -- Normal. This means the server booted successfully under Proton.

**UE4SS breaks after a Palworld update** -- The game's update cycle frequently breaks UE4SS memory hooks. Rename `dwmapi.dll` to `dwmapi.dll.bak` in the game volume to disable UE4SS while awaiting an updated release.

**WorldOption.sav overrides your settings** -- If the world was first created in-game, `WorldOption.sav` overrides `PalWorldSettings.ini` entirely. The entrypoint warns if this file is detected. Fix: back up and delete `WorldOption.sav`, or set your config before the world's first launch.

**Config changes not taking effect** -- The server overwrites `PalWorldSettings.ini` on shutdown. Always stop the server before editing the config file. Env var settings are safe -- the entrypoint re-applies them on each start.

**SteamCMD download failing with permission error** -- Usually means the mounted volume's permissions don't match the `steam` user inside the container. The entrypoint runs `chown steam:steam` on the volume before starting SteamCMD.

**No Edit button in Unraid** -- The container must be created from the Unraid GUI's "Add Container" flow using the template XML, not via `docker run` from the terminal. The template is installed in `/boot/config/plugins/dockerMan/templates-user/`.

**Alpine containers won't work** -- Wine/Proton requires glibc. Alpine's musl libc breaks `ws2_32.dll`, `dlclose`, and Wine build tools. Debian slim is the correct base.

**`bEnableInvaderEnemy=False` halves RAM** -- Disabling base raids roughly halves memory consumption over a session. Useful for RAM-constrained servers.

**Key typo warning** -- `PalStomachDecreaceRate`, `PalStaminaDecreaceRate`, `PlayerStomachDecreaceRate`, `PlayerStaminaDecreaceRate` are all spelled "Decreace" (Pocketpair's typo). Must match exactly or the setting is silently ignored.
