FROM tbro98/ase-server-base:steamcmd

ENV STEAM_PATH=${HOME}/.steam/steam
ENV WINEDLLOVERRIDES="version=n,b;vcrun2019=n,b"
ENV WINEPREFIX=/home/steam/.wine
ENV DISPLAY=:0

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y \
    vim \
    wget python3 \
    libfontconfig1 libfontconfig1:i386 libfreetype6 libfreetype6:i386 \
    dbus curl cabextract winbind \
    wine wine32 wine64 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup machine-id for Wine
RUN set -ex; \
    rm -f /etc/machine-id; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    rm -f /var/lib/dbus/machine-id; \
    dbus-uuidgen --ensure

# Initialize Wine
RUN wine wineboot --init

COPY scripts/* /home/steam/
COPY ArkApi_3.56/* /home/steam/arkserver/ShooterGame/Binaries/Win64/
RUN chmod +x /home/steam/*.sh

WORKDIR /home/steam
ENTRYPOINT ["./start_server.sh"]