FROM tbro98/arkserver-base:steamcmd

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
    && wget -O - \
    https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz \
    | tar -xz -C ${STEAM_PATH}/compatibilitytools.d/ \
    && cp -r ${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/files/share/default_pfx ${STEAM_PATH}/steamapps/compatdata/${STEAM_ID} 

# Setup machine-id for Proton
RUN set -ex; \
    rm -f /etc/machine-id; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    rm -f /var/lib/dbus/machine-id; \
    dbus-uuidgen --ensure

# # Setup and pre-initialize Wine environment for AsaApi
# RUN set -ex; \
#     # Create Wine prefix structure
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/windows/system32; \
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files/Common\ Files; \
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Common\ Files; \
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/Temp; \
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/dosdevices; \
#     # Create device mappings
#     ln -sf "../drive_c" ${STEAM_COMPAT_DATA_PATH}/pfx/dosdevices/c:; \
#     ln -sf "/dev/null" ${STEAM_COMPAT_DATA_PATH}/pfx/dosdevices/d::; \
#     ln -sf "/dev/null" ${STEAM_COMPAT_DATA_PATH}/pfx/dosdevices/e::; \
#     ln -sf "/dev/null" ${STEAM_COMPAT_DATA_PATH}/pfx/dosdevices/f::; \
#     # Create VC++ structure
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2019/BuildTools/VC/Redist/MSVC/14.29.30133/x64/Microsoft.VC142.CRT; \
#     mkdir -p ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2019/BuildTools/VC/Redist/MSVC/14.29.30133/x86/Microsoft.VC142.CRT; \
#     # Create VC++ dummy files
#     touch ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2019/BuildTools/VC/Redist/MSVC/14.29.30133/x64/Microsoft.VC142.CRT/msvcp140.dll; \
#     touch ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2019/BuildTools/VC/Redist/MSVC/14.29.30133/x64/Microsoft.VC142.CRT/vcruntime140.dll; \
#     touch ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2019/BuildTools/VC/Redist/MSVC/14.29.30133/x86/Microsoft.VC142.CRT/msvcp140.dll; \
#     touch ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2019/BuildTools/VC/Redist/MSVC/14.29.30133/x86/Microsoft.VC142.CRT/vcruntime140.dll; \
#     # Create wine registry files
#     echo "WINE REGISTRY Version 2" > ${STEAM_COMPAT_DATA_PATH}/pfx/system.reg; \
#     echo ";; All keys relative to \\\\Machine" >> ${STEAM_COMPAT_DATA_PATH}/pfx/system.reg; \
#     echo "#arch=win64" >> ${STEAM_COMPAT_DATA_PATH}/pfx/system.reg; \
#     echo "" >> ${STEAM_COMPAT_DATA_PATH}/pfx/system.reg; \
#     echo "WINE REGISTRY Version 2" > ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     echo ";; All keys relative to \\\\User\\\\S-1-5-21-0-0-0-1000" >> ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     echo "#arch=win64" >> ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     echo "[Software\\\\Wine\\\\DllOverrides]" >> ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     echo "\"*version\"=\"native,builtin\"" >> ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     echo "\"vcrun2019\"=\"native,builtin\"" >> ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     echo "" >> ${STEAM_COMPAT_DATA_PATH}/pfx/user.reg; \
#     # Create tracked_files
#     touch ${STEAM_COMPAT_DATA_PATH}/tracked_files

# # Download and pre-install VC++ Redistributable
# RUN set -ex; \
#     mkdir -p /tmp/vcredist; \
#     cd /tmp/vcredist; \
#     wget -q https://aka.ms/vs/16/release/vc_redist.x64.exe; \
#     wget -q https://aka.ms/vs/16/release/vc_redist.x86.exe; \
#     # Run winetricks to pre-install vcrun2019 using Proton's winetricks
#     ${PROTON} run ${STEAM_PATH}/compatibilitytools.d/${PROTON_VERSION}/files/bin/winetricks -q vcrun2019 || true; \
#     # Install directly as fallback using Proton
#     ${PROTON} run /tmp/vcredist/vc_redist.x64.exe /quiet /norestart || true; \
#     ${PROTON} run /tmp/vcredist/vc_redist.x86.exe /quiet /norestart || true; \
#     rm -rf /tmp/vcredist

COPY scripts/* /home/steam/
COPY ArkApi_3.56/* /home/steam/arkserver/ShooterGame/Binaries/Win64/
RUN chmod +x /home/steam/*.sh

WORKDIR /home/steam
ENTRYPOINT ["./start_server.sh"]