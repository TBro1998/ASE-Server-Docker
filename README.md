# Docker ARK Server

[中文文档](README-Zh.md)  

This is a Docker-based ARK: Survival Evolved game server that uses GE-Proton to run the Windows version of the ARK server, with ArkApi support.  
It includes the latest server files and ArkApi files at build time.

## Inspiration and Code Sources
- [Ark-Survival-Ascended-Server](https://github.com/Acekorneya/Ark-Survival-Ascended-Server)
- [Ark_Mod_Downloader_v2](https://github.com/CobraColin/Ark_Mod_Downloader_v2)

## Disclaimer
- *Compared to running directly on Windows, it will occupy more disk space
- Since we're using GE-Proton (based on Wine) to simulate Windows system APIs on Linux to run the Windows version of the game server, memory usage might be slightly higher
- Including the latest server files has its pros and cons. While it saves download time during initial deployment for multi-server setups, we may release a Docker image without server files in the future based on needs

## Known Issues
- When running the server with GE-Proton, server output information cannot be viewed in the container logs
- The Mods download/update process is not perfect

## Future Plans
- Test performance differences between running the server directly on Windows versus using GE-Proton on Linux, and whether UDP performance is better on Linux
- Would it be more suitable to use [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) to replace GE-Proton for running ASE server?
- Develop a server management system based on Go+Vue?

## Usage

### 1. Enter the docker directory
```bash
cd docker
```

### 2. Configure server parameters

Server parameters are configured through environment variables in the `docker-compose.yml` file. You can modify the following parameters:

- `GameModIds`: Comma-separated list of mod IDs to install
- `SERVER_ARGS`: Server startup arguments including map, ports, and other settings

Example configuration in `docker-compose.yml`:
```yaml
environment:
  - GameModIds=895711211,669673294,1136125765
  - SERVER_ARGS="TheIsland?listen?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password?GameModIds=895711211,669673294,1136125765 -NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore"
```

To apply configuration changes, restart the container:
```bash
docker-compose down
docker-compose up -d
```

### 3. Available Maps

- TheIsland
- TheCenter
- ScorchedEarth_P
- Ragnarok
- Aberration_P
- Extinction
- Valguero_P
- Genesis
- CrystalIsles
- Genesis2
- LostIsland

### 4. Data Persistence

To save game data, it is recommended to mount the following volumes:

| Local Path | Container Path | Description |
|------------|----------------|-------------|
| ./Saved | /home/steam/arkserver/ShooterGame/Saved | Server save files, including Configs, Logs, SavedArks |
| ./Plugins | /home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins | ArkApi plugin files location |
| ./ArkApiLogs | /home/steam/arkserver/ShooterGame/Binaries/Win64/logs | ArkApi log files |

### 5. Using Docker Compose

The project includes a `docker-compose.yml` file with all necessary configuration.  
Using Docker Compose makes it easier to manage the container:

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```
