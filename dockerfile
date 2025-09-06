FROM tbro98/ase-server-base:latest
# Build information
LABEL "description"="Run Ark Survival Evolved Server With ArkApi"
LABEL "maintainer"="tbro98 <tbro5201314@gmail.com>"

ENV PROTON_VERSION="GE-Proton10-15"

# 添加i386架构支持并安装所有依赖
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    vim \
    wget curl tar ca-certificates gnupg2 \
    lib32gcc-s1 lib32stdc++6 libsdl2-2.0-0:i386 libc6:i386 \
    git make python3 python3-pip scdoc cargo rustc pkg-config \
    libssl-dev libdbus-1-dev libpython3-dev python3-dev \
    jq unzip nano gzip iproute2 procps sudo dbus\
    locales \
    software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
#&& \
# 创建machine-id文件
# mkdir -p /etc && \
# dbus-uuidgen > /etc/machine-id && \
# chmod 444 /etc/machine-id

# 安装umu-launcher所需的Python依赖
RUN pip3 install --break-system-packages urllib3 truststore build hatchling installer pyzstd wheel setuptools python-xlib

# 下载并安装umu-launcher
RUN git clone https://github.com/Open-Wine-Components/umu-launcher.git && \
    cd umu-launcher && \
    ./configure.sh --prefix=/usr --use-system-pyzstd --use-system-urllib && \
    make && \
    make install && \
    cd .. && \
    rm -rf umu-launcher


# 下载Proton
RUN mkdir -p /root/.local/share/Steam/compatibilitytools.d && \
    curl -sL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" -o proton.tar.gz && \
    tar -xzf proton.tar.gz -C /root/.local/share/Steam/compatibilitytools.d && \
    rm proton.tar.gz

COPY scripts/* /root/
COPY ArkApi_3.56/* /root/arkserver/ShooterGame/Binaries/Win64/
RUN chmod +x /root/*.sh

WORKDIR /root
ENTRYPOINT ["./start_server.sh"]