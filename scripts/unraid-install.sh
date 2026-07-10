#!/bin/bash
## =============================================================================
## Unraid template installer for Palworld Proton Server
## Copy-paste this entire block into the Unraid terminal (WebUI > Terminal).
## Then go to Docker tab > Add Container > select the template > Apply.
## =============================================================================

## --- 1. Remove any broken container from a previous run ---
docker rm -f palworld-proton-server 2>/dev/null || true

## --- 2. Create directory structure on the array ---
mkdir -p /mnt/user/appdata/palworld-proton-server/{game,mods/Win64,mods/pak}

## --- 3. Create Unraid template XML ---
mkdir -p /boot/config/plugins/dockerMan/templates-user/
cat > /boot/config/plugins/dockerMan/templates-user/palworld-proton-server.xml << 'XMLEOF'
<?xml version="1.0"?>
<Containers>
  <Container>
    <Name>palworld-proton-server</Name>
    <Repository>ghcr.io/adam2893/palworld-proton-server:latest</Repository>
    <Network>bridge</Network>
    <MyIP/>
    <Shell>bash</Shell>
    <Privileged>false</Privileged>
    <WebUI>http://[IP]:[PORT:8212]/v1/api/info</WebUI>
    <Banner/>
    <Description>Palworld Windows dedicated server via Proton — UE4SS mod support, RCON, scheduled backups.</Description>
    <Registry>https://ghcr.io</Registry>
    <ExtraParams>--security-opt=no-new-privileges:true --security-opt=seccomp=unconfined -v /etc/machine-id:/etc/machine-id:ro</ExtraParams>
    <Config Name="Game Port" Target="8211" Default="8211" Mode="udp" Description="Game port (UDP)" Type="Port" Display="always" Required="true" Mask="false">8211</Config>
    <Config Name="Query Port" Target="27015" Default="27015" Mode="udp" Description="Steam query port (UDP)" Type="Port" Display="always" Required="true" Mask="false">27015</Config>
    <Config Name="RCON Port" Target="25575" Default="25575" Mode="tcp" Description="RCON port (TCP) — do not expose publicly" Type="Port" Display="always" Required="true" Mask="false">25575</Config>
    <Config Name="REST API / WebUI Port" Target="8212" Default="8212" Mode="tcp" Description="REST API and WebUI port (TCP) — do not expose publicly" Type="Port" Display="always" Required="true" Mask="false">8212</Config>
    <Config Name="Server Data" Target="/palworld" Default="/mnt/user/appdata/palworld-proton-server/game" Mode="rw" Description="Server data, saves, backups" Type="Path" Display="always" Required="true" Mask="false">/mnt/user/appdata/palworld-proton-server/game</Config>
    <Config Name="Mods" Target="/mods" Default="/mnt/user/appdata/palworld-proton-server/mods" Mode="rw" Description="Mod staging area (Win64/ and pak/ subdirs)" Type="Path" Display="always" Required="false" Mask="false">/mnt/user/appdata/palworld-proton-server/mods</Config>
    <Config Name="Server Name" Target="SERVER_NAME" Default="My Palworld Server" Mode="" Description="Server name shown in browser" Type="Variable" Display="always" Required="false" Mask="false">My Palworld Server</Config>
    <Config Name="Server Description" Target="SERVER_DESCRIPTION" Default="" Mode="" Description="Server description" Type="Variable" Display="always" Required="false" Mask="false"/>
    <Config Name="Server Password" Target="SERVER_PASSWORD" Default="" Mode="" Description="Password to join (blank = open)" Type="Variable" Display="always" Required="false" Mask="true"/>
    <Config Name="Admin Password" Target="ADMIN_PASSWORD" Default="changeme" Mode="" Description="Admin password for RCON/REST API" Type="Variable" Display="always" Required="true" Mask="true">changeme</Config>
    <Config Name="Max Players" Target="MAX_PLAYERS" Default="32" Mode="" Description="Max concurrent players (1-32)" Type="Variable" Display="always" Required="false" Mask="false">32</Config>
    <Config Name="RCON Enabled" Target="RCON_ENABLED" Default="true" Mode="" Description="Enable RCON remote console" Type="Variable" Display="always" Required="false" Mask="false">true</Config>
    <Config Name="REST API Enabled" Target="REST_API_ENABLED" Default="true" Mode="" Description="Enable REST API (powers the WebUI button)" Type="Variable" Display="always" Required="true" Mask="false">true</Config>
    <Config Name="UE4SS Mods" Target="ENABLE_UE4SS" Default="true" Mode="" Description="Enable UE4SS server-side mod framework" Type="Variable" Display="always" Required="false" Mask="false">true</Config>
    <Config Name="Backups Enabled" Target="BACKUP_ENABLED" Default="true" Mode="" Description="Enable scheduled backups via supercronic" Type="Variable" Display="always" Required="false" Mask="false">true</Config>
    <Config Name="Backup Schedule" Target="BACKUP_CRON_EXPRESSION" Default="0 0 * * *" Mode="" Description="Cron expression for backups (default: midnight daily)" Type="Variable" Display="advanced" Required="false" Mask="false">0 0 * * *</Config>
    <Config Name="Delete Old Backups" Target="DELETE_OLD_BACKUPS" Default="false" Mode="" Description="Delete backups older than retention period" Type="Variable" Display="advanced" Required="false" Mask="false">false</Config>
    <Config Name="Backup Retention Days" Target="BACKUP_RETENTION_DAYS" Default="30" Mode="" Description="Days to keep backups (if delete enabled)" Type="Variable" Display="advanced" Required="false" Mask="false">30</Config>
    <Config Name="Community Server" Target="COMMUNITY" Default="false" Mode="" Description="Show in community server browser" Type="Variable" Display="advanced" Required="false" Mask="false">false</Config>
    <Config Name="Multithreading" Target="MULTITHREADING" Default="true" Mode="" Description="Enable multi-threaded performance flags" Type="Variable" Display="advanced" Required="false" Mask="false">true</Config>
    <Config Name="Crossplay Platforms" Target="CROSSPLAY_PLATFORMS" Default="Steam,Xbox,PS5,Mac" Mode="" Description="Platforms allowed to connect" Type="Variable" Display="advanced" Required="false" Mask="false">Steam,Xbox,PS5,Mac</Config>
    <Config Name="Enable PvP" Target="ENABLE_PVP" Default="false" Mode="" Description="Enable PvP trial mode (sets all 3 toggles)" Type="Variable" Display="advanced" Required="false" Mask="false">false</Config>
    <Config Name="EXP Rate" Target="EXP_RATE" Default="" Mode="" Description="XP multiplier (1.0 = vanilla, blank = ini default)" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Pal Capture Rate" Target="PAL_CAPTURE_RATE" Default="" Mode="" Description="Capture multiplier (1.0 = vanilla)" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Egg Hatch Time" Target="PAL_EGG_HATCHING_TIME" Default="" Mode="" Description="Hours to hatch eggs (72 = vanilla)" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Work Speed Rate" Target="WORK_SPEED_RATE" Default="" Mode="" Description="How fast Pals work (1.0 = vanilla)" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Death Penalty" Target="DEATH_PENALTY" Default="" Mode="" Description="None, Item, ItemAndEquipment, All" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Enable Raids" Target="ENABLE_INVADER_ENEMY" Default="" Mode="" Description="Base raids (false halves RAM usage)" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Version Pin (Manifest ID)" Target="TARGET_MANIFEST_ID" Default="" Mode="" Description="Lock to specific Steam build (SteamDB app 2394010) — blank for latest" Type="Variable" Display="advanced" Required="false" Mask="false"/>
    <Config Name="Auto-Update on Start" Target="ALWAYS_UPDATE_ON_START" Default="false" Mode="" Description="Run SteamCMD validation on every start" Type="Variable" Display="advanced" Required="false" Mask="false">false</Config>
    <Config Name="Timezone" Target="TZ" Default="America/New_York" Mode="" Description="Timezone for backups and logs" Type="Variable" Display="always" Required="false" Mask="false">America/New_York</Config>
  </Container>
</Containers>
XMLEOF

echo ""
echo "============================================================"
echo "  Template installed. Now:"
echo "============================================================"
echo ""
echo "  1. Go to Docker tab > Add Container"
echo "  2. Select template: palworld-proton-server"
echo "  3. Change ADMIN_PASSWORD from 'changeme'!"
echo "  4. Adjust any other settings"
echo "  5. Click Apply"
echo ""
echo "  First boot takes 5-10 mins (SteamCMD download + Wine)"
echo "  Watch: docker logs -f palworld-proton-server"
echo "  Success: 'wine: RLIMIT_NICE is <= 20' in logs"
echo ""
echo "  After running:"
echo "    WebUI: Click the globe icon in Docker tab"
echo "    RCON:  docker exec palworld-proton-server rcon-cli 'Save'"
echo "    Backup: docker exec palworld-proton-server backup"
echo ""
echo "  Mods -> /mnt/user/appdata/palworld-proton-server/mods/"
echo "    UE4SS -> Win64/   |   .pak -> pak/"
echo "============================================================"
