#!/bin/bash

echo "###################################################"
echo "##### Start Ark Survival Evolved Server With ArkApi"
echo "##### $(date)"
echo "##### Public IP [$(curl -s https://ifconfig.me)]"
echo "###################################################"

# 游戏本体、Mod 和 ArkApi 都放在挂载的数据卷（$INSTALL_DIR）里，镜像本身不包含服务端文件。
# 安装完成标记也放在卷里，容器重建后不会重新下载
INSTALL_FLAG="$INSTALL_DIR/.install_complete"
INSTALLED_MODS_FILE="$INSTALL_DIR/.installed_mods"
BIN_DIR="$INSTALL_DIR/ShooterGame/Binaries/Win64"
SERVER_EXE="$BIN_DIR/ShooterGameServer.exe"
ARKAPI_SRC="/home/steam/arkapi"

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

if [ ! -f "$INSTALL_FLAG" ] || [ ! -f "$SERVER_EXE" ]; then
    echo " [*] Server files not found in $INSTALL_DIR - downloading, this takes a while..."

    # Update Steam client
    echo " [*] Updating Steam client"
    run steamcmd +app_update +quit

    # Download game server
    echo " [*] Updating ARK server"
    run steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$INSTALL_DIR" +login "$STEAM_USER" +app_update "$APP_UPDATE" validate +quit
    if [ ! -f "$SERVER_EXE" ]; then
        echo " [!] ARK server download failed: $SERVER_EXE not found"
        exit 1
    fi
    touch "$INSTALL_FLAG"
    echo " [i] ARK server update completed"
else
    echo " [i] Server files already installed - skipping download"
fi

# Mod：只下载还没装过的，已装的记录在卷里的 .installed_mods，每行 "Mod ID 安装时间（Unix 秒）"，
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

# ArkApi 随镜像发布，每次启动同步到卷里，镜像升级后插件框架也跟着升级；用户改过的 config.json 不覆盖
if [ -d "$ARKAPI_SRC" ]; then
    mkdir -p "$BIN_DIR/ArkApi/Plugins"
    for f in "$ARKAPI_SRC"/*; do
        name=$(basename "$f")
        if [ "$name" = "config.json" ] && [ -e "$BIN_DIR/$name" ]; then
            continue
        fi
        cp -a "$f" "$BIN_DIR/"
    done
    if [ -n "$ARKAPI_VERSION" ]; then
        echo "$ARKAPI_VERSION" > "$INSTALL_DIR/.arkapi_version"
    fi
fi

# Start server with proton
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
"$PROTON" run ShooterGameServer.exe "${SERVER_ARGV[@]}" &
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
