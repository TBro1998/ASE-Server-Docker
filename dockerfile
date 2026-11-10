FROM steamcmd/steamcmd:latest

# 游戏服务端的 Steam 信息。服务端文件不再预下载，由入口脚本在首次启动时下载到挂载的数据卷。
# 需要海洋 DLC 更新前的版本时，把 APP_UPDATE 改成 "376030 -beta preaquatica"
ENV STEAM_ID=376030
ENV APP_UPDATE=${STEAM_ID}
ENV STEAM_USER="anonymous"
ENV INSTALL_DIR='/home/steam/arkserver'

ENV STEAM_PATH=${HOME}/.steam/steam
ENV PROTON_VERSION=GE-Proton10-4
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH=${STEAM_PATH}
ENV STEAM_COMPAT_DATA_PATH=${STEAM_PATH}/steamapps/compatdata/${STEAM_ID}
ENV PROTON=${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/proton
ENV WINEDLLOVERRIDES="version=n,b;vcrun2019=n,b"

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y \
    vim \
    wget python3 \
    libfontconfig1 libfontconfig1:i386 libfreetype6 libfreetype6:i386 \
    dbus curl cabextract winbind \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Proton build from Glorious Eggroll
RUN mkdir -p ${STEAM_PATH} \
    && mkdir -p ${STEAM_PATH}/compatibilitytools.d/ \
    && mkdir -p /root/.config/protonfixes \
    && mkdir -p ${STEAM_PATH}/steamapps/compatdata/${STEAM_ID} \
    && wget -q -O - \
    https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz \
    | tar -xz -C ${STEAM_PATH}/compatibilitytools.d/ \
    && cp -r ${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/files/share/default_pfx ${STEAM_PATH}/steamapps/compatdata/${STEAM_ID} 

# Setup machine-id for Proton
RUN set -ex; \
    rm -f /etc/machine-id; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    rm -f /var/lib/dbus/machine-id; \
    dbus-uuidgen --ensure

COPY scripts/* /home/steam/
COPY ArkApi_3.56/* /home/steam/arkapi/
RUN chmod +x /home/steam/*.sh

WORKDIR /home/steam
ENTRYPOINT ["./start_server.sh"]