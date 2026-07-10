#!/bin/bash
## =============================================================================
## Unraid template installer for Palworld Proton Server
## Copy-paste this entire block into the Unraid terminal.
## Then: Docker tab > Add Container > select palworld-proton-server > Apply.
## =============================================================================

## --- 1. Remove any broken container from a previous run ---
docker rm -f palworld-proton-server 2>/dev/null || true

## --- 2. Create directory structure on the array ---
mkdir -p /mnt/user/appdata/palworld-proton-server/{game,mods/Win64,mods/pak}

## --- 3. Delete old broken templates, write correct one ---
## The file MUST be named my-palworld-proton-server.xml (my- prefix is required)
rm -f /boot/config/plugins/dockerMan/templates-user/palworld-proton-server.xml
mkdir -p /boot/config/plugins/dockerMan/templates-user/
cat > /boot/config/plugins/dockerMan/templates-user/my-palworld-proton-server.xml << 'XMLEOF'
<?xml version="1.0"?>
<Container version="2">
  <Name>palworld-proton-server</Name>
  <Repository>ghcr.io/adam2893/palworld-proton-server:latest</Repository>
  <Registry>https://ghcr.io</Registry>
  <Network>bridge</Network>
  <MyIP/>
  <Shell>bash</Shell>
  <Privileged>false</Privileged>
  <Support>https://github.com/adam2893/palworld-proton-server</Support>
  <Overview>
Palworld dedicated server running the Windows binary via GE-Proton inside Docker.
Enables UE4SS server-side mods (Lua/DLL) that only work on Windows.
Includes RCON CLI, scheduled backups via supercronic, and healthcheck.
First boot takes 5-10 minutes (SteamCMD download + Wine prefix setup).
  </Overview>
  <Category>GameServers:</Category>
  <WebUI>http://[IP]:[PORT:8212]/v1/api/info</WebUI>
  <TemplateURL/>
  <Icon>https://raw.githubusercontent.com/adam2893/palworld-proton-server/main/icon.png</Icon>
  <ExtraParams>--security-opt=no-new-privileges:true --security-opt=seccomp=unconfined -v /etc/machine-id:/etc/machine-id:ro</ExtraParams>
  <PostArgs/>
  <DonateText></DonateText>
  <DonateLink></DonateLink>
  <Requires></Requires>

  <Config Name="Game Port" Target="8211" Default="8211" Mode="udp" Description="Game port (UDP)" Type="Port" Display="always" Required="true" Mask="false">8211</Config>
  <Config Name="Query Port" Target="27015" Default="27015" Mode="udp" Description="Steam query port (UDP)" Type="Port" Display="always" Required="true" Mask="false">27015</Config>
  <Config Name="RCON Port" Target="25575" Default="25575" Mode="tcp" Description="RCON port (TCP)" Type="Port" Display="always" Required="true" Mask="false">25575</Config>
  <Config Name="REST API / WebUI Port" Target="8212" Default="8212" Mode="tcp" Description="REST API port (TCP)" Type="Port" Display="always" Required="true" Mask="false">8212</Config>
  <Config Name="Server Data" Target="/palworld" Default="/mnt/user/appdata/palworld-proton-server/game" Mode="rw" Description="Server data, saves, backups" Type="Path" Display="always" Required="true" Mask="false">/mnt/user/appdata/palworld-proton-server/game</Config>
  <Config Name="Mods" Target="/mods" Default="/mnt/user/appdata/palworld-proton-server/mods" Mode="rw" Description="Mod staging (Win64/ and pak/ subdirs)" Type="Path" Display="always" Required="false" Mask="false">/mnt/user/appdata/palworld-proton-server/mods</Config>
  <Config Name="Server Name" Target="SERVER_NAME" Default="My Palworld Server" Mode="" Description="Server name in browser" Type="Variable" Display="always" Required="false" Mask="false">My Palworld Server</Config>
  <Config Name="Server Password" Target="SERVER_PASSWORD" Default="" Mode="" Description="Password to join (blank = open)" Type="Variable" Display="always" Required="false" Mask="true"></Config>
  <Config Name="Admin Password" Target="ADMIN_PASSWORD" Default="changeme" Mode="" Description="Admin password for RCON/REST" Type="Variable" Display="always" Required="true" Mask="true">changeme</Config>
  <Config Name="Max Players" Target="MAX_PLAYERS" Default="32" Mode="" Description="Max players (1-32)" Type="Variable" Display="always" Required="false" Mask="false">32</Config>
  <Config Name="RCON Enabled" Target="RCON_ENABLED" Default="true" Mode="" Description="Enable RCON" Type="Variable" Display="always" Required="false" Mask="false">true</Config>
  <Config Name="REST API Enabled" Target="REST_API_ENABLED" Default="true" Mode="" Description="Enable REST API (WebUI)" Type="Variable" Display="always" Required="true" Mask="false">true</Config>
  <Config Name="UE4SS Mods" Target="ENABLE_UE4SS" Default="true" Mode="" Description="Enable UE4SS mod framework" Type="Variable" Display="always" Required="false" Mask="false">true</Config>
  <Config Name="Backups" Target="BACKUP_ENABLED" Default="true" Mode="" Description="Scheduled backups" Type="Variable" Display="always" Required="false" Mask="false">true</Config>
  <Config Name="Backup Schedule" Target="BACKUP_CRON_EXPRESSION" Default="0 0 * * *" Mode="" Description="Cron for backups" Type="Variable" Display="advanced" Required="false" Mask="false">0 0 * * *</Config>
  <Config Name="Community Server" Target="COMMUNITY" Default="false" Mode="" Description="Show in community browser" Type="Variable" Display="advanced" Required="false" Mask="false">false</Config>
  <Config Name="Multithreading" Target="MULTITHREADING" Default="true" Mode="" Description="Multi-threaded perf flags" Type="Variable" Display="advanced" Required="false" Mask="false">true</Config>
  <Config Name="Crossplay" Target="CROSSPLAY_PLATFORMS" Default="Steam,Xbox,PS5,Mac" Mode="" Description="Platforms allowed" Type="Variable" Display="advanced" Required="false" Mask="false">Steam,Xbox,PS5,Mac</Config>
  <Config Name="Enable PvP" Target="ENABLE_PVP" Default="false" Mode="" Description="PvP trial mode" Type="Variable" Display="advanced" Required="false" Mask="false">false</Config>
  <Config Name="EXP Rate" Target="EXP_RATE" Default="" Mode="" Description="XP multiplier (1.0=vanilla)" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Pal Capture Rate" Target="PAL_CAPTURE_RATE" Default="" Mode="" Description="Capture multiplier" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Egg Hatch Time" Target="PAL_EGG_HATCHING_TIME" Default="" Mode="" Description="Hours to hatch (72=vanilla)" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Work Speed" Target="WORK_SPEED_RATE" Default="" Mode="" Description="Pal work speed" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Death Penalty" Target="DEATH_PENALTY" Default="" Mode="" Description="None/Item/ItemAndEquipment/All" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Enable Raids" Target="ENABLE_INVADER_ENEMY" Default="" Mode="" Description="Base raids (false=halves RAM)" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Version Pin" Target="TARGET_MANIFEST_ID" Default="" Mode="" Description="Lock to Steam manifest (SteamDB 2394010)" Type="Variable" Display="advanced" Required="false" Mask="false"></Config>
  <Config Name="Timezone" Target="TZ" Default="America/New_York" Mode="" Description="Timezone" Type="Variable" Display="always" Required="false" Mask="false">America/New_York</Config>
</Container>
XMLEOF

echo ""
echo "============================================================"
echo "  Template installed. Now:"
echo "============================================================"
echo ""
echo "  1. Go to Docker tab > Add Container"
echo "  2. Select: palworld-proton-server"
echo "  3. Change ADMIN_PASSWORD!"
echo "  4. Click Apply"
echo ""
echo "  First boot: 5-10 mins (SteamCMD + Wine)"
echo "  Logs: docker logs -f palworld-proton-server"
echo "  Success: 'wine: RLIMIT_NICE is <= 20'"
echo ""
echo "  WebUI: Click globe icon (REST API on port 8212)"
echo "  RCON:  docker exec palworld-proton-server rcon-cli 'Save'"
echo "  Backup: docker exec palworld-proton-server backup"
echo "============================================================"
