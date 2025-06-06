#!/bin/bash

echo "###################################################"
echo "##### 首次运行初始化脚本"
echo "##### $(date)"
echo "###################################################"


# 读取配置文件
if [ -f "server.cfg" ]; then
    source server.cfg
fi

# 更新Steam客户端
echo " [*] 更新Steam客户端"
steamcmd +app_update +quit

# 更新游戏服务器
echo " [*] 更新ARK服务器"
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir $INSTALL_DIR +login $STEAM_USER +app_update $STEAM_ID validate +quit 

echo " [i] ARK服务器更新完成"

if [ "${MODIDS}" != "" ]; then
    echo " [*] 开始下载和安装mod"
    # 为每个mod创建下载目录
    for modid in $(echo $MODIDS | tr ',' ' '); do
        echo " [*] 下载mod: $modid"
        steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir $INSTALL_DIR +login anonymous +workshop_download_item 346110 $modid +quit
        
        echo " [*] 安装mod: $modid"
        python3 Ark_Mod_Install.py --workingdir $INSTALL_DIR --modid $modid --namefile
    done
else
    echo " [i] 跳过mod更新"
fi

echo "首次运行初始化完成"

# 删除自身
echo " [i] 删除首次运行脚本"
rm -f "$0"