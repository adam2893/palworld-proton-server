#!/bin/bash
## =============================================================================
## Unraid template installer for Palworld Proton Server
## Copy-paste this entire block into the Unraid terminal (WebUI > Terminal).
## Then go to Docker tab > Add Container > select the template > Apply.
## This gives you the Edit button + WebUI icon in the Docker tab.
## =============================================================================

## --- 1. Remove any broken container from a previous run ---
docker rm -f palworld-proton-server 2>/dev/null || true

## --- 2. Create directory structure on the array ---
mkdir -p /mnt/user/appdata/palworld-proton-server/{game,mods/Win64,mods/pak}

## --- 3. Create Unraid template XML (appears in Add Container dropdown) ---
mkdir -p /boot/config/plugins/dockerMan/templates-user/
cat > /boot/config/plugins/dockerMan/templates-user/palworld-proton-server.xml << 'XMLEOF'
<?xml version="1.0"?>
<Containers>
  <Container>
    <Name>palworld-proton-server</Name>
    <Repository>ghcr.io/adam2893/palworld-proton-server:latest</Repository>
    <Network>bridge</Network>
    <Shell>bash</Shell>
    <Privileged>false</Privileged>
    <WebUI>http://[IP]:[PORT:8212]/v1/api/info</WebUI>
    <Restart>unless-stopped</Restart>
    <StopTimeout>30</StopTimeout>
    <ExtraParams>--security-opt=no-new-privileges:true --security-opt=seccomp=unconfined -v /etc/machine-id:/etc/machine-id:ro</ExtraParams>
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
    <Config Name="EXP Rate" Target="EXP_RATE" Mode="" Description="XP multiplier (1.0 = vanilla, blank = ini default)" Type="Variable" Value=""/>
    <Config Name="Pal Capture Rate" Target="PAL_CAPTURE_RATE" Mode="" Description="Capture multiplier (1.0 = vanilla)" Type="Variable" Value=""/>
    <Config Name="Egg Hatch Time" Target="PAL_EGG_HATCHING_TIME" Mode="" Description="Hours to hatch eggs (72 = vanilla)" Type="Variable" Value=""/>
    <Config Name="Work Speed Rate" Target="WORK_SPEED_RATE" Mode="" Description="How fast Pals work (1.0 = vanilla)" Type="Variable" Value=""/>
    <Config Name="Death Penalty" Target="DEATH_PENALTY" Mode="" Description="None, Item, ItemAndEquipment, All" Type="Variable" Value=""/>
    <Config Name="Enable Raids" Target="ENABLE_INVADER_ENEMY" Mode="" Description="Base raids (false halves RAM usage)" Type="Variable" Value=""/>
    <Config Name="Version Pin (Manifest ID)" Target="TARGET_MANIFEST_ID" Mode="" Description="Lock to specific Steam build (SteamDB app 2394010) — leave blank for latest" Type="Variable" Value=""/>
    <Config Name="Auto-Update on Start" Target="ALWAYS_UPDATE_ON_START" Mode="" Description="Run SteamCMD validation on every start" Type="Variable" Value="false"/>
    <Config Name="Timezone" Target="TZ" Mode="" Description="Timezone for backups and logs" Type="Variable" Value="America/New_York"/>
  </Container>
</Containers>
XMLEOF

echo ""
echo "============================================================"
echo "  Template created. Now:"
echo "============================================================"
echo ""
echo "  1. Go to Docker tab > Add Container"
echo "  2. Select template: palworld-proton-server"
echo "  3. Change ADMIN_PASSWORD from 'changeme'!"
echo "  4. Adjust any other settings (EXP rate, etc.)"
echo "  5. Click Apply"
echo ""
echo "  First boot takes 5-10 minutes (SteamCMD download + Wine)."
echo "  Watch: docker logs -f palworld-proton-server"
echo "  Success: 'wine: RLIMIT_NICE is <= 20' in logs"
echo ""
echo "  After it's running:"
echo "    WebUI: Click the icon in Docker tab"
echo "    RCON:  docker exec palworld-proton-server rcon-cli 'Save'"
echo "    Backup: docker exec palworld-proton-server backup"
echo ""
echo "  Mods go in: /mnt/user/appdata/palworld-proton-server/mods/"
echo "    UE4SS mods -> Win64/   |   .pak mods -> pak/"
echo "============================================================"
