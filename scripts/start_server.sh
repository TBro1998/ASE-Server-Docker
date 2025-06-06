#!/bin/bash

echo "###################################################"
echo "##### Start Ark Survival Evolved Server With ArkApi"
echo "##### $(date)"
echo "##### 公网IP [$(curl -s https://ifconfig.me)]"
echo "###################################################"

# 创建mod下载目录
MOD_DOWNLOAD_DIR="/home/steam/download"

# 读取配置文件
if [ -f "server.cfg" ]; then
    echo " [i] 读取配置"
    cat server.cfg
    source server.cfg
fi

# 检查是否是首次运行
if [ -f "first_run.sh" ]; then
    echo " [i] 检测到首次运行脚本，执行初始化..."
    ./first_run.sh
    echo " [i] 首次运行初始化完成，已删除初始化脚本"
fi

if [ "${UPDATE_SERVER}" = "true" ]; then
    # 更新游戏服务器
    echo " [*] 更新ARK服务器"
    steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir $INSTALL_DIR +login $STEAM_USER +app_update $STEAM_ID validate +quit 
    echo " [i] ARK服务器更新完成"
fi

if [ "${UPDATE_MODS}" = "true" ] && [ "${MODIDS}" != "" ]; then
   echo " [*] 开始下载和安装mod"
    # 计算mod总数
    total_mods=$(echo $MODIDS | tr ',' '\n' | wc -l)
    current_mod=0
    
    # 为每个mod创建下载目录
    for modid in $(echo $MODIDS | tr ',' ' '); do
        current_mod=$((current_mod + 1))
        mkdir -p $MOD_DOWNLOAD_DIR/$modid
        echo " [*] 下载mod: $modid (${current_mod}/${total_mods})"
        steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir $MOD_DOWNLOAD_DIR/$modid +login anonymous +workshop_download_item 346110 $modid +quit
        
        echo " [*] 安装mod: $modid (${current_mod}/${total_mods})"
        python3 Ark_Mod_Install.py --workingdir $MOD_DOWNLOAD_DIR/$modid --modid $modid --namefile --installdir $INSTALL_DIR
    done
else
    echo " [i] 跳过mod更新"
fi

# 显示配置信息
echo "最大玩家数量: ${MAX_PLAYERS:-70}"
echo "进服密码: ${SERVER_PASSWORD:-}"
echo "管理员密码: ${ADMIN_PASSWORD:-}"

# Start server with proton
SERVER_CMD="$PROTON run ShooterGameServer.exe \
  ${MAP:-TheIsland}?listen?Port=${PORT:-7777}?QueryPort=${QUERYPORT:-27015}?MaxPlayers=${MAX_PLAYERS:-70}?AllowCrateSpawnsOnTopOfStructures=True \
  ${SERVER_ARGS}"

#  -NoBattlEye -servergamelog -ServerAllowAnsel -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore" 

# 启动ARK服务器
echo " [*] 启动ARK服务器..."
cd $INSTALL_DIR/ShooterGame/Binaries/Win64 
export PROTON_LOG=1
# Start the server
$SERVER_CMD &
SERVER_PID=$!

# Capture logs
# tail -f "${INSTALL_DIR}/ShooterGame/Saved/Logs/server.log" &
# tail -f "${INSTALL_DIR}/ShooterGame/Binaries/Win64/logs/server.log" &

# Monitor server process
wait $SERVER_PID
exit $?
# 保持容器运行
# tail -f /dev/null
