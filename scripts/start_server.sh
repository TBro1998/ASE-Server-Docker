#!/bin/bash

# SERVER_PLATFORM 由镜像设置：linux 镜像运行原生 Linux 版服务端，proton 镜像用 GE-Proton 运行 Windows 版（可加载 ArkApi）
SERVER_PLATFORM="${SERVER_PLATFORM:-windows}"

echo "###################################################"
echo "##### Start Ark Survival Evolved Server ($SERVER_PLATFORM)"
echo "##### $(date)"
echo "##### Public IP [$(curl -s https://ifconfig.me)]"
echo "###################################################"

# 游戏本体和 Mod 都放在挂载的数据卷（$INSTALL_DIR）里，镜像本身不包含服务端文件。
# 安装完成标记也放在卷里，容器重建后不会重新下载。标记里记录安装时的平台（linux / windows，
# 旧版本写的是空文件，视为 windows），换用另一个镜像后平台不同，会重新 validate，下载这个平台的主程序
INSTALL_FLAG="$INSTALL_DIR/.install_complete"
INSTALLED_MODS_FILE="$INSTALL_DIR/.installed_mods"
if [ "$SERVER_PLATFORM" = "linux" ]; then
    BIN_DIR="$INSTALL_DIR/ShooterGame/Binaries/Linux"
    SERVER_EXE="$BIN_DIR/ShooterGameServer"
else
    BIN_DIR="$INSTALL_DIR/ShooterGame/Binaries/Win64"
    SERVER_EXE="$BIN_DIR/ShooterGameServer.exe"
fi

mkdir -p "$INSTALL_DIR"

# 下载阶段也要响应 docker stop：bash 要等前台命令结束才处理信号，steamcmd 下载可能持续很久，
# 所以耗时命令用 run 放到单独的进程组里后台运行并 wait，收到 SIGTERM 时结束整个进程组后退出，
# 不必等 30 秒超时被强杀。安装标记只在成功后写入，中断的下载下次启动时会继续
CHILD_PID=""
on_stop() {
    echo " [*] Stop signal received, aborting..."
    if [ -n "$CHILD_PID" ]; then
        kill -TERM -- "-$CHILD_PID" 2>/dev/null
        wait "$CHILD_PID" 2>/dev/null
    fi
    exit 143
}
trap on_stop TERM INT

run() {
    setsid "$@" &
    CHILD_PID=$!
    wait "$CHILD_PID"
    local code=$?
    CHILD_PID=""
    return $code
}

INSTALLED_PLATFORM=""
if [ -f "$INSTALL_FLAG" ]; then
    INSTALLED_PLATFORM=$(tr -d '[:space:]' < "$INSTALL_FLAG")
    INSTALLED_PLATFORM="${INSTALLED_PLATFORM:-windows}"
fi

if [ ! -f "$INSTALL_FLAG" ] || [ ! -f "$SERVER_EXE" ] || [ "$INSTALLED_PLATFORM" != "$SERVER_PLATFORM" ]; then
    if [ -f "$INSTALL_FLAG" ] && [ "$INSTALLED_PLATFORM" != "$SERVER_PLATFORM" ]; then
        echo " [*] Server files were installed for $INSTALLED_PLATFORM - validating for $SERVER_PLATFORM, only the differences are downloaded..."
    else
        echo " [*] Server files not found in $INSTALL_DIR - downloading, this takes a while..."
    fi

    # Update Steam client
    echo " [*] Updating Steam client"
    run steamcmd +app_update +quit

    # Download game server（APP_UPDATE 可能带 -beta 参数，按空格拆开传给 steamcmd）
    echo " [*] Updating ARK server"
    run steamcmd +@sSteamCmdForcePlatformType "$SERVER_PLATFORM" +force_install_dir "$INSTALL_DIR" +login "$STEAM_USER" +app_update $APP_UPDATE validate +quit
    if [ ! -f "$SERVER_EXE" ]; then
        echo " [!] ARK server download failed: $SERVER_EXE not found"
        exit 1
    fi
    echo "$SERVER_PLATFORM" > "$INSTALL_FLAG"
    echo " [i] ARK server update completed"
else
    echo " [i] Server files already installed - skipping download"
fi

# Mod：两个平台都用 Windows 版的 Mod 文件（WindowsNoEditor），Linux 版服务端同样能加载，切换平台不用重新下载。
# 只下载还没装过的，已装的记录在卷里的 .installed_mods，每行 "Mod ID 安装时间（Unix 秒）"，
# 管理端据此判断创意工坊上是否有更新；旧版本写的行只有 Mod ID，同样视为已安装
if [ -n "${GameModIds}" ]; then
    MOD_DOWNLOAD_DIR="/home/steam/download"
    touch "$INSTALLED_MODS_FILE"
    mod_list=$(echo "$GameModIds" | tr ',' ' ')
    total_mods=$(echo $mod_list | wc -w)
    current_mod=0
    for modid in $mod_list; do
        current_mod=$((current_mod + 1))
        if grep -qE "^${modid}( |$)" "$INSTALLED_MODS_FILE"; then
            echo " [i] Mod $modid already installed (${current_mod}/${total_mods})"
            continue
        fi
        echo "--------------------------------"
        mkdir -p "$MOD_DOWNLOAD_DIR/$modid"
        echo " [*] Downloading mod: $modid (${current_mod}/${total_mods})"
        run steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$MOD_DOWNLOAD_DIR/$modid" +login "$STEAM_USER" +workshop_download_item 346110 "$modid" +quit

        echo " [*] Installing mod: $modid (${current_mod}/${total_mods})"
        if run python3 Ark_Mod_Install.py --workingdir "$MOD_DOWNLOAD_DIR/$modid" --modid "$modid" --namefile --installdir "$INSTALL_DIR"; then
            echo "$modid $(date +%s)" >> "$INSTALLED_MODS_FILE"
        else
            echo " [!] Failed to install mod $modid, will retry on next start"
        fi
        rm -rf "$MOD_DOWNLOAD_DIR/$modid"
        echo "--------------------------------"
    done
else
    echo " [i] Skipping mod update"
fi

# ArkApi 不随镜像发布：由管理端安装到 ShooterGame/Binaries/Win64（version.dll 等），proton 镜像启动时自动加载；
# Linux 版服务端不支持 ArkApi

if [ "$SERVER_PLATFORM" = "linux" ]; then
    # Linux 版服务端读写 Config/LinuxServer，Windows 版是 Config/WindowsServer。管理端只维护 WindowsServer，
    # 这里把 LinuxServer 做成指向它的符号链接，两个平台共用同一份配置；已有的真实目录先把文件合并过去（不覆盖已有的）
    CONFIG_DIR="$INSTALL_DIR/ShooterGame/Saved/Config"
    mkdir -p "$CONFIG_DIR/WindowsServer"
    if [ ! -L "$CONFIG_DIR/LinuxServer" ]; then
        if [ -d "$CONFIG_DIR/LinuxServer" ]; then
            cp -a --update=none "$CONFIG_DIR/LinuxServer/." "$CONFIG_DIR/WindowsServer/"
            rm -rf "$CONFIG_DIR/LinuxServer"
        fi
        ln -s WindowsServer "$CONFIG_DIR/LinuxServer"
    fi

    # 游戏进程通过 Steam 游戏服务器接口加载 ~/.steam/sdk64/steamclient.so，基础镜像通常已经建好，缺失时补上
    if [ ! -e "$HOME/.steam/sdk64/steamclient.so" ]; then
        for candidate in "$HOME/.local/share/Steam/steamcmd/linux64/steamclient.so" "$HOME/.steam/steamcmd/linux64/steamclient.so" "$INSTALL_DIR/linux64/steamclient.so"; do
            if [ -f "$candidate" ]; then
                mkdir -p "$HOME/.steam/sdk64"
                ln -sf "$candidate" "$HOME/.steam/sdk64/steamclient.so"
                break
            fi
        done
    fi

    # 服务端会同时打开大量文件，默认的文件描述符上限可能不够
    ulimit -n 100000 2>/dev/null || true
fi

# 优先使用容器启动命令里传入的参数，每个参数保持独立，服务器名称里的空格不会被拆开；
# 没有传入时（旧版管理端）回退到 SERVER_ARGS，按空格拆分
if [ "$#" -gt 0 ]; then
    SERVER_ARGV=("$@")
else
    read -r -a SERVER_ARGV <<< "${SERVER_ARGS}"
fi

# Start ARK server
echo " [*] Starting ARK server..."
cd "$BIN_DIR"

# 放到后台运行并转发信号：docker stop 发出的 SIGTERM 会转给游戏进程，让它有机会正常退出；
# 不转发的话信号停在这个脚本里，只能等超时后被 SIGKILL
if [ "$SERVER_PLATFORM" = "linux" ]; then
    ./ShooterGameServer "${SERVER_ARGV[@]}" &
else
    "$PROTON" run ShooterGameServer.exe "${SERVER_ARGV[@]}" &
fi
SERVER_PID=$!
trap 'echo " [*] Stopping ARK server..."; kill -TERM "$SERVER_PID" 2>/dev/null' TERM INT
wait "$SERVER_PID"
EXIT_CODE=$?
# 收到信号时 wait 会提前返回，这里再等游戏进程真正退出
trap - TERM INT
if kill -0 "$SERVER_PID" 2>/dev/null; then
    wait "$SERVER_PID"
    EXIT_CODE=$?
fi
exit "$EXIT_CODE"
