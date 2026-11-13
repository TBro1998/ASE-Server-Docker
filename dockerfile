FROM steamcmd/steamcmd:latest

# 游戏服务端的 Steam 信息。服务端文件不再预下载，由入口脚本在首次启动时下载到挂载的数据卷。
# 需要海洋 DLC 更新前的版本时，把 APP_UPDATE 改成 "376030 -beta preaquatica"
ENV STEAM_ID=376030
ENV APP_UPDATE=${STEAM_ID}
ENV STEAM_USER="anonymous"
ENV INSTALL_DIR='/home/steam/arkserver'
# 随镜像发布的 ArkApi 版本，对应仓库里的 ArkApi_<版本> 目录；入口脚本会把它写进服务端文件卷，管理端据此显示版本
ENV ARKAPI_VERSION=3.56

ENV STEAM_PATH=${HOME}/.steam/steam
ENV PROTON_VERSION=GE-Proton11-12
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH=${STEAM_PATH}
ENV STEAM_COMPAT_DATA_PATH=${STEAM_PATH}/steamapps/compatdata/${STEAM_ID}
ENV PROTON=${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/proton
# version=n,b：优先加载 ArkApi 的 version.dll；mshtml=d：不装 wine-gecko（镜像里已删除）。
# 不能禁用 mscoree：ShooterGameServer.exe 直接导入它，禁用后无法启动（Wine 内置的 mscoree 不需要 wine-mono 也能加载）
ENV WINEDLLOVERRIDES="version=n,b;mshtml=d"
# 关闭 NVAPI（镜像里已删除）。不设置时 proton 脚本会去复制 NVAPI 的 DLL，缺失会直接报错。
# 不要设置 PROTON_USE_WINED3D：实测用 wined3d 时游戏进程会在初始化阶段卡住，必须保留 DXVK/VKD3D-Proton
ENV PROTON_DISABLE_NVAPI=1

RUN dpkg --add-architecture i386 \
    && apt-get update \
    # --no-install-recommends：libvulkan1 默认会带上 mesa-vulkan-drivers 和 LLVM（约 250 MB），服务器用不上
    && apt-get install -y --no-install-recommends \
    wget python3 \
    libfontconfig1 libfontconfig1:i386 libfreetype6 libfreetype6:i386 \
    dbus curl cabextract winbind \
    # GE-Proton 11 的 proton 脚本启动时就会加载 libvulkan.so.1，缺了会直接报错退出（只需要加载器，不需要显卡）
    libvulkan1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Proton build from Glorious Eggroll
# 从 GE-Proton11-4 起 x86_64 包名带 -x86_64 后缀，解压出的顶层目录也带后缀，
# 这里去掉顶层目录，统一解压到 compatibilitytools.d/${PROTON_VERSION}
RUN mkdir -p ${STEAM_PATH} \
    && mkdir -p ${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION} \
    && mkdir -p /root/.config/protonfixes \
    && mkdir -p ${STEAM_PATH}/steamapps/compatdata/${STEAM_ID} \
    && wget -q -O - \
    https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}-x86_64.tar.gz \
    | tar -xz --strip-components=1 -C ${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION} \
    # 精简：删掉专用服务器用不上的组件，必须和解压在同一层，否则镜像体积不会变小
    # - wine-mono（.NET）、wine-gecko（IE 内核）
    # - 图形相关：D7VK、NVAPI、NVIDIA 库。DXVK 和 VKD3D-Proton 不能删，proton 启动时必定复制它们
    # - 字体（proton 会遍历这个目录，所以保留空目录）、语音合成数据
    # 原先这里把 default_pfx 复制到 compatdata 下，但 proton 用的是 compatdata/<id>/pfx，复制过去不会被用到，
    # 首次运行时 proton 会自己从 files/share/default_pfx 创建 prefix
    && cd ${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/files \
    && rm -rf share/wine/mono share/wine/gecko \
    lib/wine/d7vk lib/wine/nvapi lib/wine/nvidia-libs \
    share/espeak-ng-data share/libtashkeel_model.ort \
    && find share/fonts -mindepth 1 -delete

# Setup machine-id for Proton
RUN set -ex; \
    rm -f /etc/machine-id; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    rm -f /var/lib/dbus/machine-id; \
    dbus-uuidgen --ensure

COPY scripts/* /home/steam/
COPY ArkApi_${ARKAPI_VERSION}/* /home/steam/arkapi/
RUN chmod +x /home/steam/*.sh

WORKDIR /home/steam
ENTRYPOINT ["./start_server.sh"]