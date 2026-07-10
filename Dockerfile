## =============================================================================
## Palworld Dedicated Server — Windows server via Proton in Docker
## Lightweight image for running server-side mods (UE4SS)
## =============================================================================
FROM cm2network/steamcmd:root

## ---- Minimal packages required by Proton/Wine + UE4SS -----------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6 \
        unzip \
        procps \
        gosu \
        python3 \
    && rm -rf /var/lib/apt/lists/*

## ---- RCON CLI (gorcon/rcon-cli) ---------------------------------------------
## ~2MB static binary. Enables: docker exec palworld-server rcon-cli "Save"
ARG RCON_VERSION=0.10.3
RUN curl -sL "https://github.com/gorcon/rcon-cli/releases/download/v${RCON_VERSION}/rcon-${RCON_VERSION}-amd64_linux.tar.gz" \
        | tar -xzf - -C /tmp/ \
    && mv "/tmp/rcon-${RCON_VERSION}-amd64_linux/rcon" /usr/local/bin/rcon-cli \
    && chmod +x /usr/local/bin/rcon-cli \
    && rm -rf /tmp/rcon-*

## ---- Supercronic (cron scheduler for containers) ----------------------------
## ~5MB binary. Enables scheduled backups and reboots without a full cron daemon.
ARG SUPERCRONIC_VERSION=0.2.46
RUN curl -sL "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
        -o /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic

## ---- GE-Proton (GloriousEggroll custom Proton for Steam Play) --------------
## Latest stable with massive adoption: GE-Proton10-26 (Dec 2025, 326K+ downloads)
## GE-Proton11-1 (Jun 2026) is available but is a major Proton 11 rebase — test before production use.
ARG PROTON_VERSION=GE-Proton10-26
ARG APPID=2394010

ENV STEAM_HOME=/home/steam \
    STEAM_PATH=/home/steam/.steam/steam \
    APPID=${APPID} \
    PROTON_VERSION=${PROTON_VERSION}

WORKDIR ${STEAM_PATH}

## Download + extract Proton in a single layer (tarball doesn't persist in image)
RUN mkdir -p compatibilitytools.d \
    && curl -sL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" \
       | tar -xzf - -C compatibilitytools.d/ \
    && chown -R steam:steam /home/steam

## ---- Proton environment variables -------------------------------------------
## These tell Proton where Steam lives and where to put the Wine prefix
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH=${STEAM_PATH} \
    STEAM_COMPAT_DATA_PATH=${STEAM_PATH}/steamapps/compatdata/${APPID} \
    PROTON=${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/proton \
    STEAMCMD=/home/steam/steamcmd/steamcmd.sh \
    SERVER_DIR=/palworld \
    SteamAppId=${APPID} \
    WINEDEBUG=-all

## Pre-seed the Wine prefix from Proton's default_pfx so first boot is fast
RUN mkdir -p "${STEAM_COMPAT_DATA_PATH}" \
    && cp -r "compatibilitytools.d/${PROTON_VERSION}/files/share/default_pfx"/* "${STEAM_COMPAT_DATA_PATH}/" \
    && chown -R steam:steam "${STEAM_COMPAT_DATA_PATH}"

## ---- Server data directory (mounted as volume at runtime) ------------------
RUN mkdir -p ${SERVER_DIR} && chown steam:steam ${SERVER_DIR}

## ---- Entrypoint + backup scripts --------------------------------------------
COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh
COPY --chmod=755 scripts/backup.sh /usr/local/bin/backup

VOLUME ["/palworld"]

## Game (UDP 8211) | Query (UDP 27015) | RCON (TCP 25575) | REST API (TCP 8212)
EXPOSE 8211/udp 27015/udp 25575/tcp 8212/tcp

## Healthcheck: detect if the Windows server process is running under Proton.
## PalServer-Win64-Test.exe runs inside a wineserver process, so we check for it.
HEALTHCHECK --start-period=5m --interval=30s --timeout=10s --retries=3 \
    CMD pgrep -f "PalServer-Win64-Test" > /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
