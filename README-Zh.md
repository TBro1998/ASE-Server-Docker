# Docker ARK 服务器

这是一个基于Docker的ARK: Survival Evolved游戏服务器，使用GE-Proton运行Windows版ARK服务器，支持ArkApi。  
包含了构建时最新的服务端文件和ArkApi文件。

## 灵感及部分代码来源
- [Ark-Survival-Ascended-Server](https://github.com/Acekorneya/Ark-Survival-Ascended-Server)
- [Ark_Mod_Downloader_v2](https://github.com/CobraColin/Ark_Mod_Downloader_v2)

## 声明
- *相比直接在Windows上运行的方式会多占用更多的磁盘空间
- 因为是在Linux上使用GE-Proton(基于Wine)模拟Windows系统的API运行Windows端的游戏服务器，所以内存占用可能会稍微增加
- 包含最新的服务端文件这种做法有利有弊，如果是开多通服务器会在一开始的部署阶段省去下载的等待时间，后续根据需要可以出一套无服务端文件的Docker镜像

## 已知问题
- 使用GE-Proto运行服务端，无法在容器的日志中查看服务端的输出信息
- Mods的下载安装流程不够完善

## 未来计划
- 测试在Windows直接运行服务器跟使用GE-Proton在linux上运行的性能差异，以及在linux上UDP性能是否会更优秀?
- 使用(umu-launcher)[https://github.com/Open-Wine-Components/umu-launcher]来替代GE-Proton运行ASE服务器是否会更合适?
- 开发一套基于Go+Vue的服务器管理系统?

## 使用方法

### 1. 进入docker目录
```bash
cd docker
```

### 2. 配置服务器参数

服务器参数通过 `docker-compose.yml` 文件中的环境变量进行配置。您可以修改以下参数：

- `GameModIds`: 要安装的mod ID列表，用逗号分隔
- `SERVER_ARGS`: 服务器启动参数，包括地图、端口和其他设置

在 `docker-compose.yml` 中的配置示例：
```yaml
environment:
  - GameModIds=895711211,669673294,1136125765
  - SERVER_ARGS="TheIsland?listen?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password?GameModIds=895711211,669673294,1136125765 -NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore"
```

要应用配置更改，请重启容器：
```bash
docker-compose down
docker-compose up -d
```

### 3. 可用地图

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

### 4. 数据持久化

为了保存游戏数据，建议挂载以下存储卷：

| 本地路径 | 容器路径 | 说明 |
|---------|---------|------|
| ./Saved | /home/steam/arkserver/ShooterGame/Saved | 服务器保存文件，包含Configs、Logs、SavedArks |
| ./Plugins | /home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins | ArkApi 插件文件存放位置 |
| ./ArkApiLogs | /home/steam/arkserver/ShooterGame/Binaries/Win64/logs | ArkApi 的日志文件 |

### 5. 使用Docker Compose 运行容器

项目包含了 docker-compose.yml 文件，包含所有必要的配置。  
使用Docker Compose更方便地管理容器：

```bash
# 构建并启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止容器
docker-compose down
```