# Docker ARK 服务器

这是一个基于Docker的ARK: Survival Evolved游戏服务器，使用GE-Proton运行Windows版ARK服务器，支持ArkApi。

## 使用方法

### 构建镜像

```bash
docker build -t arkserver .
```

### 运行容器

### 使用Docker Compose

项目包含了`docker-compose.yml`文件和`server.cfg`文件，可以使用Docker Compose更方便地管理容器：

```bash
# 构建并启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止容器
docker-compose down
```

#### 使用server.cfg文件配置

项目根目录下的`server.cfg`文件包含了所有可配置的环境变量：

```
# ARK服务器配置
MAP=TheIsland
SERVER_PASSWORD=
ADMIN_PASSWORD=Admin
MAX_PLAYERS=70
UPDATE_SERVER=false
UPDATE_MODS=false
MODIDS="1,2,3"
SERVER_ARGS="-NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore" 
```

只需编辑`server.cfg`文件中的值，然后重新启动容器即可应用新的配置：


## 可用地图

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

## 数据持久化

为了保存游戏数据，建议挂载存储卷：
  - ./server.cfg:/home/steam/server.cfg # *必须，配置服务器启动参数的文件
  - ./Saved:/home/steam/arkserver/ShooterGame/Saved   # 服务器保存文件，包含Configs、Logs、SavedArks
  - ./Plugins:/home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins # ArkApi 插件文件存放位置
  - ./ArkApiLogs:/home/steam/arkserver/ShooterGame/Binaries/Win64/logs  # ArkApi 的日志文件
