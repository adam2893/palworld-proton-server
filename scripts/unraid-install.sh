#!/bin/bash
## =============================================================================
## Unraid one-shot installer for Palworld Proton Server
## Copy and paste this entire block into the Unraid terminal (WebUI > Terminal)
## After running, the container appears in the Docker tab — edit settings in the GUI.
## WebUI button opens the Palworld REST API (server info, players, metrics).
## =============================================================================

## --- 1. Create directory structure on the array ---
mkdir -p /mnt/user/appdata/palworld-proton-server/{game,mods/Win64,mods/pak}

## --- 2. Create Unraid template (enables GUI editing + WebUI button) ---
mkdir -p /boot/config/plugins/dockerMan/templates-user/
cat > /boot/config/plugins/dockerMan/templates-user/palworld-proton-server.xml << 'XMLEOF'
<?xml version="1.0"?>
<Containers>
  <Container>
    <Name>palworld-proton-server</Name>
    <Repository>ghcr.io/adam2893/palworld-proton-server:latest</Repository>
    <Network>bridge</Network>
    <Shell>bash</Shell>
    <WebUI>http://[IP]:[PORT:8212]/v1/api/info</WebUI>
    <Config Name="Game Port" Target="8211" Mode="udp" Description="Game port (UDP)" Type="Port" Value="8211"/>
    <Config Name="Query Port" Target="27015" Mode="udp" Description="Steam query port (UDP)" Type="Port" Value="27015"/>
    <Config Name="RCON Port" Target="25575" Mode="tcp" Description="RCON port (TCP) — do not expose publicly" Type="Port" Value="25575"/>
    <Config Name="REST API / WebUI Port" Target="8212" Mode="tcp" Description="REST API and WebUI port (TCP) — do not expose publicly" Type="Port" Value="8212"/>
    <Config Name="Server Data" Target="/palworld" Mode="rw" Description="Server data, saves, backups" Type="Path" Value="/mnt/user/appdata/palworld-proton-server/game"/>
    <Config Name="Mods" Target="/mods" Mode="rw" Description="Mod staging area (Win64/ and pak/ subdirs)" Type="Path" Value="/mnt/user/appdata/palworld-proton-server/mods"/>
    <Config Name="Server Name" Target="SERVER_NAME" Mode="" Description="Server name shown in browser" Type="Variable" Value="My Palworld Server"/>
    <Config Name="Server Description" Target="SERVER_DESCRIPTION" Mode="" Description="Server description" Type="Variable" Value=""/>
    <Config Name="Server Password" Target="SERVER_PASSWORD" Mode="" Description="Password to join (blank = open)" Type="Variable" Value=""/>
    <Config Name="Admin Password" Target="ADMIN_PASSWORD" Mode="" Description="Admin password for RCON/REST API" Type="Variable" Value="changeme"/>
    <Config Name="Max Players" Target="MAX_PLAYERS" Mode="" Description="Max concurrent players (1-32)" Type="Variable" Value="32"/>
    <Config Name="RCON Enabled" Target="RCON_ENABLED" Mode="" Description="Enable RCON remote console" Type="Variable" Value="true"/>
    <Config Name="REST API Enabled" Target="REST_API_ENABLED" Mode="" Description="Enable REST API (powers the WebUI button)" Type="Variable" Value="true"/>
    <Config Name="UE4SS Mods" Target="ENABLE_UE4SS" Mode="" Description="Enable UE4SS server-side mod framework" Type="Variable" Value="true"/>
    <Config Name="Backups Enabled" Target="BACKUP_ENABLED" Mode="" Description="Enable scheduled backups via supercronic" Type="Variable" Value="true"/>
    <Config Name="Backup Schedule" Target="BACKUP_CRON_EXPRESSION" Mode="" Description="Cron expression for backups (default: midnight daily)" Type="Variable" Value="0 0 * * *"/>
    <Config Name="Delete Old Backups" Target="DELETE_OLD_BACKUPS" Mode="" Description="Delete backups older than retention period" Type="Variable" Value="false"/>
    <Config Name="Backup Retention Days" Target="BACKUP_RETENTION_DAYS" Mode="" Description="Days to keep backups (if delete enabled)" Type="Variable" Value="30"/>
    <Config Name="Community Server" Target="COMMUNITY" Mode="" Description="Show in community server browser" Type="Variable" Value="false"/>
    <Config Name="Multithreading" Target="MULTITHREADING" Mode="" Description="Enable multi-threaded performance flags" Type="Variable" Value="true"/>
    <Config Name="Crossplay Platforms" Target="CROSSPLAY_PLATFORMS" Mode="" Description="Platforms allowed to connect" Type="Variable" Value="Steam,Xbox,PS5,Mac"/>
    <Config Name="Enable PvP" Target="ENABLE_PVP" Mode="" Description="Enable PvP trial mode (sets all 3 toggles)" Type="Variable" Value="false"/>
    <Config Name="EXP Rate" Target="EXP_RATE" Mode="" Description="XP multiplier (1.0 = vanilla)" Type="Variable" Value=""/>
    <Config Name="Pal Capture Rate" Target="PAL_CAPTURE_RATE" Mode="" Description="Capture multiplier (1.0 = vanilla)" Type="Variable" Value=""/>
    <Config Name="Egg Hatch Time" Target="PAL_EGG_HATCHING_TIME" Mode="" Description="Hours to hatch eggs (72 = vanilla)" Type="Variable" Value=""/>
    <Config Name="Death Penalty" Target="DEATH_PENALTY" Mode="" Description="None, Item, ItemAndEquipment, All" Type="Variable" Value=""/>
    <Config Name="Enable Raids" Target="ENABLE_INVADER_ENEMY" Mode="" Description="Base raids (false halves RAM)" Type="Variable" Value=""/>
    <Config Name="Version Pin (Manifest ID)" Target="TARGET_MANIFEST_ID" Mode="" Description="Lock to specific Steam build (SteamDB app 2394010). Blank = latest." Type="Variable" Value=""/>
    <Config Name="Auto-Update on Start" Target="ALWAYS_UPDATE_ON_START" Mode="" Description="Run SteamCMD validation on every start" Type="Variable" Value="false"/>
    <Config Name="Timezone" Target="TZ" Mode="" Description="Timezone for backups and logs" Type="Variable" Value="America/New_York"/>
  </Container>
</Containers>
XMLEOF

## --- 3. Pull and run the container ---
docker run -d \
  --name=palworld-proton-server \
  --restart=unless-stopped \
  --stop-timeout=30 \
  --security-opt=no-new-privileges:true \
  --security-opt=seccomp=unconfined \
  --label net.unraid.docker.webui="http://[IP]:[PORT:8212]/v1/api/info" \
  --label net.unraid.docker.managed="true" \
  -p 8211:8211/udp \
  -p 27015:27015/udp \
  -p 25575:25575/tcp \
  -p 8212:8212/tcp \
  -v /mnt/user/appdata/palworld-proton-server/game:/palworld \
  -v /mnt/user/appdata/palworld-proton-server/mods:/mods \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e SERVER_NAME="My Palworld Server" \
  -e ADMIN_PASSWORD="changeme" \
  -e MAX_PLAYERS=32 \
  -e RCON_ENABLED=true \
  -e REST_API_ENABLED=true \
  -e ENABLE_UE4SS=true \
  -e BACKUP_ENABLED=true \
  -e BACKUP_CRON_EXPRESSION="0 0 * * *" \
  -e COMMUNITY=false \
  -e MULTITHREADING=true \
  -e CROSSPLAY_PLATFORMS="Steam,Xbox,PS5,Mac" \
  -e ENABLE_PVP=false \
  -e ALWAYS_UPDATE_ON_START=false \
  -e TZ="America/New_York" \
  ghcr.io/adam2893/palworld-proton-server:latest

echo ""
echo "============================================================"
echo "  Palworld Proton Server deployed!"
echo "============================================================"
echo ""
echo "  Container:  palworld-proton-server"
echo "  Image:      ghcr.io/adam2893/palworld-proton-server:latest"
echo "  Data:       /mnt/user/appdata/palworld-proton-server/game/"
echo "  Mods:       /mnt/user/appdata/palworld-proton-server/mods/"
echo ""
echo "  Ports:"
echo "    8211/udp  - Game port"
echo "    27015/udp - Steam query"
echo "    25575/tcp - RCON (do not expose publicly)"
echo "    8212/tcp  - REST API / WebUI (do not expose publicly)"
echo ""
echo "  WebUI: Click the icon in the Unraid Docker tab,"
echo "         or browse to http://[UNRAID_IP]:8212/v1/api/info"
echo "         (auth: admin password you set above)"
echo ""
echo "  RCON:  docker exec palworld-proton-server rcon-cli 'Save'"
echo "  Backup: docker exec palworld-proton-server backup"
echo ""
echo "  First boot takes 5-10 minutes (SteamCMD download + Wine prefix)."
echo "  Watch logs: docker logs -f palworld-proton-server"
echo "  Look for 'wine: RLIMIT_NICE' = server booted successfully."
echo ""
echo "  IMPORTANT: Change ADMIN_PASSWORD from 'changeme'!"
echo "  Go to Docker tab > click palworld-proton-server > Edit"
echo "============================================================"
