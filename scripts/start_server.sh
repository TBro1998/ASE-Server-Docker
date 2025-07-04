#!/bin/bash

echo "###################################################"
echo "##### Start Ark Survival Evolved Server With ArkApi"
echo "##### $(date)"
echo "##### Public IP [$(curl -s https://ifconfig.me)]"
echo "###################################################"

# Check if this is the first startup
FIRST_STARTUP_FLAG="/home/steam/.first_startup_complete"

if [ ! -f "$FIRST_STARTUP_FLAG" ]; then
    echo " [*] First startup detected - performing initial setup..."
    
    # Update Steam client
    echo " [*] Updating Steam client"
    steamcmd +app_update +quit
    
    # Update game server
    echo " [*] Updating ARK server"
    steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir $INSTALL_DIR +login $STEAM_USER +app_update $STEAM_ID validate +quit 
    echo " [i] ARK server update completed"

    if  [ "${GameModIds}" != "" ]; then
        MOD_DOWNLOAD_DIR="/home/steam/download"
        echo " [*] Starting mod download and installation"
        # Calculate total number of mods
        total_mods=$(echo $GameModIds | tr ',' '\n' | wc -l)
        current_mod=0
        # Create download directory for each mod
        for modid in $(echo $GameModIds | tr ',' ' '); do
            echo "--------------------------------"
            current_mod=$((current_mod + 1))
            mkdir -p $MOD_DOWNLOAD_DIR/$modid
            echo " [*] Downloading mod: $modid (${current_mod}/${total_mods})"
            steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir $MOD_DOWNLOAD_DIR/$modid +login anonymous +workshop_download_item 346110 $modid +quit
            
            echo " [*] Installing mod: $modid (${current_mod}/${total_mods})"
            python3 Ark_Mod_Install.py --workingdir $MOD_DOWNLOAD_DIR/$modid --modid $modid --namefile --installdir $INSTALL_DIR
            echo "--------------------------------"
        done
    else
        echo " [i] Skipping mod update"
    fi
    
    # Create flag file to mark first startup as complete
    touch "$FIRST_STARTUP_FLAG"
    echo " [i] First startup setup completed"
else
    echo " [i] Skipping initial setup - not first startup"
fi

# Start server with proton
SERVER_CMD="$PROTON run ShooterGameServer.exe \
  ${SERVER_ARGS}"

#  -NoBattlEye -servergamelog -ServerAllowAnsel -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore" 

# Start ARK server
echo " [*] Starting ARK server..."
cd $INSTALL_DIR/ShooterGame/Binaries/Win64

# Start the server
$SERVER_CMD 

# 保持容器运行
# tail -f /dev/null
