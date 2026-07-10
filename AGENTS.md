# AGENTS.md

> Palworld dedicated server running the Windows binary via GE-Proton inside Docker,
> enabling UE4SS server-side mods (Lua/DLL) that only work on Windows.

## Commands

- **Build image:** `docker compose build`
- **Start server:** `docker compose up -d && docker compose logs -f`
- **Stop server:** `docker compose down` (30s grace period for clean save)
- **Rebuild after Dockerfile change:** `docker compose build --no-cache`
- **Force server update:** `docker compose exec palworld-server bash -c 'ALWAYS_UPDATE_ON_START=true /entrypoint.sh'` or set `ALWAYS_UPDATE_ON_START=true` in `.env` and restart
- **RCON console:** `docker compose exec palworld-server rcon-cli "Save"` (requires `RCON_ENABLED=true`)
- **Manual backup:** `docker compose exec palworld-server backup` (saves world via RCON first if enabled)
- **RCON commands:** `docker exec palworld-server rcon-cli "Broadcast Hello"` / `"Shutdown 30 Restarting"` / `"ShowPlayers"` / `"Info"`

## Architecture

**Why Proton:** UE4SS (the mod framework for Palworld) only supports Windows. The
Linux-native Palworld server cannot run UE4SS mods. This container downloads the
**Windows** server binary via SteamCMD (`+@sSteamCmdForcePlatformType windows`) and
runs it through GE-Proton (GloriousEggroll's custom Proton build) on Linux.

**Container flow:**
1. `cm2network/steamcmd:root` base image (Debian slim + SteamCMD, Valve-recommended)
2. GE-Proton downloaded and extracted into `compatibilitytools.d/` during build
3. Wine prefix pre-seeded from Proton's `default_pfx` for fast first boot
4. `entrypoint.sh` runs: SteamCMD install → UE4SS install → mod copy → Proton launch

**Key paths inside container:**
- `/palworld/` — server data (volume-mounted, persistent)
- `/palworld/Pal/Binaries/Win64/PalServer-Win64-Test.exe` — Windows server executable
- `/palworld/Pal/Binaries/Win64/dwmapi.dll` — UE4SS loader DLL
- `/palworld/Pal/Binaries/Win64/ue4ss/` — UE4SS framework files
- `/palworld/Pal/Binaries/Win64/Mods/` — UE4SS Lua/DLL mods
- `/palworld/Pal/Content/Paks/` — .pak file mods
- `/palworld/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini` — server config
- `/home/steam/.steam/steam/compatibilitytools.d/` — Proton installation
- `/home/steam/.steam/steam/steamapps/compatdata/2394010/` — Wine prefix

**Key environment variables (Proton):**
- `STEAM_COMPAT_CLIENT_INSTALL_PATH` — Steam install path (tells Proton where Steam lives)
- `STEAM_COMPAT_DATA_PATH` — Wine prefix location (per-app compatdata)
- `PROTON` — path to the `proton` executable (invoked as `$PROTON run <exe>`)

**Ports:**
- `8211/udp` — game port
- `27015/udp` — Steam query port
- `25575/tcp` — RCON (don't expose publicly)
- `8212/tcp` — REST API (don't expose publicly)

## Palworld 1.0 (July 10, 2026)

Palworld 1.0 is the full release, exiting Early Access. Key server-relevant changes:

- **PalWorldSettings.ini:** 119 total option keys (88 pre-1.0 unchanged + 31 new).
  New categories include voice chat settings, PvP kill drops, and building limits.
  Existing configs need zero migration — all pre-1.0 keys are intact.
- **Crossplay:** `CrossplayPlatforms=(Steam,Xbox,PS5,Mac)` in PalWorldSettings.ini.
  Set via `CROSSPLAY_PLATFORMS` env var. Full crossplay across all platforms.
- **PvP mode:** New trial feature. Requires ALL THREE toggles on together:
  `bIsPvP`, `bEnablePlayerToPlayerDamage`, `bEnableDefenseOtherGuildPlayer`.
  Setting only `bIsPvP=True` does nothing. Use `ENABLE_PVP=true` env var.
- **Server clustering:** Binary contains `ClusterNode`/`ClusterGroupIndex` fields
  but NO supported config path exists yet. Not usable in 1.0 — watch for future patches.
- **Memory leak fix:** The 24h uptime memory leak that plagued early access dedicated
  servers is fixed in 1.0.
- **RAM requirements increased:** 16GB minimum for small servers (1-8 players),
  32GB recommended for community servers. The map roughly doubles in size.
- **WorldOption.sav override:** If the world was first created in-game,
  `WorldOption.sav` overrides `PalWorldSettings.ini` entirely. The entrypoint
  warns if this file is detected. Fix: back up and delete WorldOption.sav, or
  set config before the world's first launch.
- **Key typo:** `PalStomachDecreaceRate`, `PalStaminaDecreaceRate`,
  `PlayerStomachDecreaceRate`, `PlayerStaminaDecreaceRate` — all spelled "Decreace"
  (Pocketpair's typo). Must match exactly or the setting is silently ignored.

## Conventions

- **Mod staging:** Place UE4SS mods in `mods/Win64/` and .pak mods in `mods/pak/` on
  the host. The entrypoint copies them into the server tree on each start.
- **UE4SS version:** Uses the Okaetsu/RE-UE4SS `experimental-palworld` build, which
  includes `MemberVariableLayout.ini` — required for Palworld 0.4.15+ due to engine
  edits that shifted memory layouts. The official UE4SS-RE releases lack this fix.
  The Okaetsu release was updated on July 10, 2026 (Palworld 1.0 launch day) but
  does not explicitly confirm 1.0 compatibility — test before relying on it.
- **UE4SS settings:** `GuiConsoleEnabled=0`, `GuiConsoleVisible=0`,
  `bUseUObjectArrayCache=false`, `GraphicsAPI=dx11` — set automatically by entrypoint.
- **Proton version:** Pinned via `PROTON_VERSION` build arg in `docker-compose.yml`.
  Default is `GE-Proton10-26` (Dec 2025, most stable/downloaded). `GE-Proton11-1`
  (Jun 2026) is the latest but is a Proton 11 rebase — test before production use.
- **Version pinning:** Set `TARGET_MANIFEST_ID` to lock the server to a specific Steam
  build. This prevents game updates from breaking UE4SS mods. Find manifest IDs on
  SteamDB (app 2394010). Leave blank to always get the latest.
- **Backups:** Set `BACKUP_ENABLED=true` to enable scheduled backups via supercronic.
  Backups are saved to `game/backups/`. The backup script saves the world via RCON
  before tarring SaveGames. Manual backup: `docker exec palworld-server backup`.
- **Gameplay env vars:** The entrypoint applies gameplay rates (EXP_RATE,
  PAL_CAPTURE_RATE, etc.) to PalWorldSettings.ini on each start. All are optional —
  leave blank in .env to use ini defaults. For the full 119-key reference, see
  https://gamesomg.com/palworld-server-settings-explained/

## Gotchas

- **SteamCMD Windows flag:** `+@sSteamCmdForcePlatformType windows` is mandatory.
  Without it, SteamCMD downloads the Linux server binary and UE4SS won't work.
- **"wine: RLIMIT_NICE is <= 20" in logs:** This is normal — it indicates the server
  has successfully booted under Proton. Not an error.
- **UE4SS breaks on Palworld updates:** Palworld's aggressive update cycle frequently
  breaks UE4SS hooks. 1.0 recompiles the executable, breaking static memory pointers.
  If the server crashes after a game patch, rename `dwmapi.dll` to `dwmapi.dll.bak`
  to disable UE4SS while awaiting an updated release.
- **1.0 mod compatibility:** Old mods WILL break on 1.0. Must DELETE old mod files
  (not just disable) to avoid crashes and save corruption. Re-enable only mods
  their authors confirm are 1.0-compatible. Test vanilla first, then add mods
  one at a time.
- **mods.txt format:** UE4SS mods are enabled via `Pal/Binaries/Win64/Mods/mods.txt`
  with the format `ModFolderName : 1` (one per line). The entrypoint does not manage
  this file — edit it manually inside the `game/` volume.
- **PalWorldSettings.ini:** The Windows server uses `WindowsServer/` config dir, not
  `LinuxServer/`. The entrypoint copies `DefaultPalWorldSettings.ini` on first run.
  Edit settings directly in `game/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini`.
  For gameplay rates (EXP, capture, egg hatch, etc.) and the full 119-key reference,
  see: https://gamesomg.com/palworld-server-settings-explained/
- **Config reset on shutdown:** The server overwrites `PalWorldSettings.ini` on
  shutdown. Always stop the server completely before editing the config, or changes
  are lost. The entrypoint applies env vars on each start, so env-managed settings
  are safe — but manual ini edits must be done while the server is stopped.
- **BaseCampWorkerMaxNum ignored:** This setting has no effect via
  `PalWorldSettings.ini` on dedicated servers. Workaround: generate a
  `WorldOption.sav` with the desired value (tool: github.com/legoduded/palworld-worldoptions).
  Note: once `WorldOption.sav` is present, it overrides `PalWorldSettings.ini` entirely.
- **bEnableInvaderEnemy=False halves RAM:** Disabling base raids roughly halves
  memory consumption over a session. Useful for RAM-constrained servers.
- **PublicPort only advertises:** `PublicPort` in the ini advertises the external
  port to the browser — it does NOT change the listen port. The listen port comes
  from the `-port` launch arg (set via `PORT` env var).
- **Image size:** ~1.7GB (140MB base + ~7MB rcon-cli/supercronic + packages + ~1.5GB Proton).
  The Palworld server itself (~12-15GB for 1.0) downloads at runtime to the mounted
  volume, not into the image.
- **No xvfb needed:** The Palworld dedicated server runs headless under Proton without
  a virtual framebuffer, as long as UE4SS GUI console is disabled. (UE servers may
  init D3D at startup, but Palworld handles this headless — confirmed by practice.)
- **Alpine incompatible:** Wine/Proton requires glibc. Alpine's musl libc breaks
  `ws2_32.dll`, `dlclose`, and Wine build tools. Debian slim is the correct base.
- **seccomp=unconfined:** Proton/Wine uses ptrace syscalls that Docker's default
  seccomp profile blocks. The docker-compose.yml sets `seccomp=unconfined` for this.
- **First boot:** Takes 5-10 minutes (SteamCMD download + Wine prefix setup). Subsequent
  starts are faster if `ALWAYS_UPDATE_ON_START=false` (default).
