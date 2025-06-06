# Docker ARK 服务器

这是一个基于Docker的ARK: Survival Evolved游戏服务器，使用GE-Proton运行Windows版ARK服务器，支持ArkApi。  
包含了构建时最新的服务端文件和ArkApi文件。  

## 灵感及部分代码来源：
[Ark-Survival-Ascended-Server](https://github.com/Acekorneya/Ark-Survival-Ascended-Server)
[Ark_Mod_Downloader_v2](https://github.com/CobraColin/Ark_Mod_Downloader_v2)

## 声明
  - 因为是在Linux上使用GE-Proton(基于Wine)模拟Windows系统的API运行Windows端的游戏服务器，所以内存占用可能会稍微增加。
  - 包含最新的服务端文件这种做法有利有弊，如果是开多通服务器会在一开始的部署阶段省去下载的等待时间，后续根据需要可以出一套无服务端文件的Docker镜像。
  - 相比直接在Windows上运行会多占用更多的磁盘空间。

## 未来计划
  - 测试在Windows直接运行服务器跟使用GE-Proton在linux上运行的性能差异，以及在linux上UDP性能是否会更优秀。
  - 开发一套基于Go+Vue的服务器管理系统？

## 使用方法

### 配置server.cfg文件

项目根目录下的`server.cfg`文件包含了所有可配置的环境变量：

```
# 地图
MAP=TheIsland
# 服务器进入密码
SERVER_PASSWORD=
# 服务器管理员密码
ADMIN_PASSWORD=Admin
# 最大玩家数
MAX_PLAYERS=70
# 启动前更新服务器，设置为 true 开启
UPDATE_SERVER=false
# 启动前更新Mods，设置为 true 开启
UPDATE_MODS=false
# Mods 列表，逗号分隔
MODIDS="1,2,3"
# 服务器启动参数
SERVER_ARGS="-NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore" 
```

只需编辑`server.cfg`文件中的值，然后重新启动容器即可应用新的配置：



### 可用地图

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

### 数据持久化

为了保存游戏数据，建议挂载存储卷：
  - ./server.cfg:/home/steam/server.cfg # *必须，配置服务器启动参数的文件
  - ./Saved:/home/steam/arkserver/ShooterGame/Saved   # 服务器保存文件，包含Configs、Logs、SavedArks
  - ./Plugins:/home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins # ArkApi 插件文件存放位置
  - ./ArkApiLogs:/home/steam/arkserver/ShooterGame/Binaries/Win64/logs  # ArkApi 的日志文件

### 使用Docker Compose 运行容器

项目包含了`docker-compose.yml`文件和`server.cfg`文件，可以使用Docker Compose更方便地管理容器：

```bash
# 构建并启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止容器
docker-compose down
```