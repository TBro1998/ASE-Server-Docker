# Docker ARK Server

[中文文档](README-Zh.md)

This is a Docker-based ARK: Survival Evolved game server with two images:

- `tbro98/ase-server:linux`: runs the native Linux server; smaller and lighter
- `tbro98/ase-server:proton`: runs the Windows server with GE-Proton and can load ArkApi plugins

The images only contain SteamCMD and the startup scripts (plus GE-Proton in the proton image). **They do not include the game server files or ArkApi.** On the first start, the entrypoint script downloads the server files into the mounted directory. Later starts and container rebuilds reuse them without downloading again.

To manage multiple servers through a web UI, see [ArkServerCommander](https://github.com/TBro1998/ArkServerCommander), which runs on this image.

## Inspiration and Code Sources
- [Ark-Survival-Ascended-Server](https://github.com/Acekorneya/Ark-Survival-Ascended-Server)
- [Ark_Mod_Downloader_v2](https://github.com/CobraColin/Ark_Mod_Downloader_v2)

## Disclaimer
- Uses more disk space than running directly on Windows
- The proton image uses GE-Proton (based on Wine) to emulate Windows system APIs on Linux, so memory usage may be slightly higher; use the linux image when you do not need ArkApi
- The server files are large, and the first start has to wait for the download; how long depends on your network. Each container downloads its own copy, so disk usage multiplies when running several servers

## Known Issues
- With the proton image, the server's own output does not appear in the container logs (script output such as downloads and mod installation does)
- Installed mods are not updated when the Workshop version changes; reinstall them manually (see "Updating the server and mods" below)
- Once the server files are installed, the game server is not updated automatically on start

## Future Plans
- Test the performance difference between running the server directly on Windows and running it with GE-Proton on Linux, and whether UDP performance is better on Linux
- Would [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) be a better fit than GE-Proton for running the ASE server?

## Usage

### 1. Deploy with Docker Compose

#### Option 1: Use the existing configuration
```bash
cd docker
docker-compose up -d
```

#### Option 2: Create your own configuration file

You can also write your own `docker-compose.yml`:

```yaml
services:
  servers:
    # Without ArkApi, use tbro98/ase-server:linux (native Linux server) and drop the Plugins and ArkApiLogs mounts
    image: tbro98/ase-server:proton
    container_name: ase-server
    restart: unless-stopped
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
      - "7778:7778/udp"
      - "7778:7778/tcp"
      - "27015:27015/udp"
      - "27015:27015/tcp"
      - "32330:32330/udp"
      - "32330:32330/tcp"
    environment:
      - TZ=Asia/Shanghai
      # Uncomment to use the pre-aquatica branch
      # - APP_UPDATE=376030 -beta preaquatica
      - GameModIds=
      - SERVER_ARGS=TheIsland?listen?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password?GameModIds= -NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore
    volumes:
      # Server files, downloaded here on the first start
      - ./ServerFiles:/home/steam/arkserver
      - ./Saved:/home/steam/arkserver/ShooterGame/Saved
      - ./Plugins:/home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins
      - ./ArkApiLogs:/home/steam/arkserver/ShooterGame/Binaries/Win64/logs
    # You can also skip the port bindings and use a bridge network
    #networks:
    #  - ark-network

# networks:
#   ark-network:
#     driver: bridge
```

The first start downloads the server files. Follow the progress with `docker-compose logs -f`. When `Starting ARK server...` appears, the download and installation are finished and the server is starting.

### 2. Docker Image Version

The same dockerfile builds two images:

| Tag                           | Description                                             |
| ----------------------------- | ------------------------------------------------------- |
| `linux`, `<version>-linux`    | Native Linux server                                     |
| `proton`, `<version>-proton`  | Windows server under GE-Proton, can load ArkApi         |

`latest` is no longer updated; it stays at the last version that bundled ArkApi.

Both images can share one server files directory: `.install_complete` records the platform it was installed for, and after switching images the next start validates the files and only downloads that platform's binaries. Saves, configs and mods are kept. The Linux server reads `Saved/Config/LinuxServer`; the startup script turns it into a symlink to `WindowsServer` so both platforms share one config.

The game branch is selected by the `APP_UPDATE` environment variable:

| `APP_UPDATE`                 | Description                              |
| ---------------------------- | ---------------------------------------- |
| `376030` (default)           | Standard version (after the aquatica DLC update) |
| `376030 -beta preaquatica`   | Version before the aquatica DLC update   |

`APP_UPDATE` only applies when the server files are downloaded. To switch an installed server to another branch, delete `.install_complete` from the server files directory, then restart the container.

### 3. Configure Server Parameters

Server parameters are set through environment variables in `docker-compose.yml`:

- `GameModIds`: comma-separated list of mod IDs to install
- `SERVER_ARGS`: server startup arguments, including map, ports and other settings, split on spaces
- `APP_UPDATE`: the game branch to download, see the previous section
- `TZ`: container time zone

Example:
```yaml
environment:
  - GameModIds=895711211,669673294,1136125765
  - SERVER_ARGS=TheIsland?listen?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password?GameModIds=895711211,669673294,1136125765 -NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore
```

> In the list syntax (`- KEY=value`), do not wrap the value in quotes; the quotes become part of the value.

`SERVER_ARGS` is split on spaces, so arguments such as the server name cannot contain spaces. When you need spaces, pass the arguments as the container command instead. Each item is passed as a separate argument, and `SERVER_ARGS` is ignored when a command is given:
```yaml
command:
  - "TheIsland?listen?SessionName=My ARK Server?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password"
  - "-NoBattlEye"
  - "-servergamelog"
  - "-nosteamclient"
  - "-game"
  - "-server"
  - "-log"
```

To apply configuration changes, recreate the container:
```bash
docker-compose up -d --force-recreate
```

The server files live in the mounted directory, so recreating the container does not download them again. Mods newly added to `GameModIds` are downloaded on the next start; mods already installed are skipped.

### 4. Updating the Server and Mods

The install state is kept in two files in the server files directory (`./ServerFiles` in the example above):

| File                 | Purpose                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `.install_complete`  | Server files are installed. While it exists, the game server download and update are skipped on start |
| `.installed_mods`    | Installed mod IDs, one per line. Mods listed here are skipped on start |

- **Update the game server**: delete `.install_complete` and restart the container. SteamCMD updates and validates the existing files instead of downloading from scratch
- **Update a mod**: remove that mod ID's line from `.installed_mods` and restart the container
- **ArkApi** (proton image only): no longer bundled. Extract an ArkApi archive (version.dll, msdia140.dll, config.json, ...) into `ShooterGame/Binaries/Win64` in the server files directory; ArkServerCommander installs and updates it for you

### 5. Available Maps

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

### 6. Data Persistence

Mounting the following directories is recommended:

| Local Path    | Container Path                                                    | Description                                            |
| ------------- | ----------------------------------------------------------------- | ------------------------------------------------------ |
| ./ServerFiles | /home/steam/arkserver                                             | Server files, ArkApi (proton image) and install markers. Without this mount, every container rebuild downloads the server again |
| ./Saved       | /home/steam/arkserver/ShooterGame/Saved                           | Server save files, including Config, Logs, SavedArks   |
| ./Plugins     | /home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins   | ArkApi plugins (proton image only)                     |
| ./ArkApiLogs  | /home/steam/arkserver/ShooterGame/Binaries/Win64/logs             | ArkApi logs (proton image only)                        |

`Saved`, `Plugins` and `ArkApiLogs` are nested inside the server files directory; mounting them separately makes them easier to back up and edit.

### 7. Common Commands

```bash
# Pull the image and start the container
docker-compose up -d

# View logs (shows download progress on the first start)
docker-compose logs -f

# Stop the container
docker-compose down

# Recreate the container after updating the image
docker-compose pull && docker-compose up -d
```

### 8. Building the Image Yourself

```bash
docker build -f dockerfile --target linux -t tbro98/ase-server:linux .
docker build -f dockerfile --target proton -t tbro98/ase-server:proton .
```

Pushing a `v*` tag triggers GitHub Actions to build both images and push the `linux` and `proton` tags plus the versioned `<version>-linux` and `<version>-proton` tags.
