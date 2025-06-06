# Docker ARK Server

This is a Docker-based ARK: Survival Evolved game server that uses GE-Proton to run the Windows version of the ARK server, with ArkApi support.

## Usage

### Building the Image

```bash
docker build -t arkserver .
```

### Running the Container

### Using Docker Compose

The project includes a `docker-compose.yml` file and a `server.cfg` file, making it easier to manage the container using Docker Compose:

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

#### Configuring with server.cfg

The `server.cfg` file in the project root directory contains all configurable environment variables:

```
# ARK Server Configuration
MAP=TheIsland
SERVER_PASSWORD=
ADMIN_PASSWORD=Admin
MAX_PLAYERS=70
UPDATE_SERVER=false
UPDATE_MODS=false
MODIDS="1,2,3"
SERVER_ARGS="-NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore" 
```

Simply edit the values in the `server.cfg` file and restart the container to apply the new configuration:

## Available Maps

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

## Data Persistence

To save game data, it is recommended to mount the following volumes:
  - ./server.cfg:/home/steam/server.cfg # *Required, configuration file for server startup parameters
  - ./Saved:/home/steam/arkserver/ShooterGame/Saved   # Server save files, including Configs, Logs, SavedArks
  - ./Plugins:/home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins # ArkApi plugin files location
  - ./ArkApiLogs:/home/steam/arkserver/ShooterGame/Binaries/Win64/logs  # ArkApi log files
