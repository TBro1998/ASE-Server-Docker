#!/bin/bash

echo "###################################################"
echo "##### Start Ark Survival Evolved Server With ArkApi"
echo "##### $(date)"
echo "##### Public IP [$(curl -s https://ifconfig.me)]"
echo "###################################################"
#  -NoBattlEye -servergamelog -ServerAllowAnsel -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore" 

# Start ARK server
echo " [*] Starting ARK server..."
# cd $INSTALL_DIR/ShooterGame/Binaries/Win64
export PATH="$HOME/.local/bin:$PATH"
# Start the server
PROTONPATH=${PROTON_VERSION} \ 
umu-run ShooterGameServer.exe \
  ${SERVER_ARGS}

# 保持容器运行
# tail -f /dev/null
