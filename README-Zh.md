# Docker ARK 服务器

[English](README.md)

这是一个基于 Docker 的 ARK: Survival Evolved 游戏服务器，使用 GE-Proton 运行 Windows 版 ARK 服务器，支持 ArkApi。

镜像里只有 SteamCMD、GE-Proton、启动脚本和 ArkApi，**不包含游戏服务端文件**。容器首次启动时，入口脚本会把服务端文件下载到挂载的目录里，之后的启动和容器重建都直接复用，不会重新下载。

需要通过 Web 界面管理多台服务器，可以使用 [ArkServerCommander](https://github.com/TBro1998/ArkServerCommander)，它使用的就是本镜像。

## 灵感及部分代码来源
- [Ark-Survival-Ascended-Server](https://github.com/Acekorneya/Ark-Survival-Ascended-Server)
- [Ark_Mod_Downloader_v2](https://github.com/CobraColin/Ark_Mod_Downloader_v2)

## 声明
- 相比直接在 Windows 上运行，会多占用一些磁盘空间
- 因为是在 Linux 上使用 GE-Proton（基于 Wine）模拟 Windows 系统 API 运行 Windows 版服务端，内存占用可能会稍微增加
- 服务端文件较大，首次启动要等它下载完成，耗时取决于网络。每个容器各下载一份，开多台服务器时磁盘占用会成倍增加

## 已知问题
- 使用 GE-Proton 运行服务端，无法在容器日志中看到服务端自身的输出（下载、Mod 安装等脚本输出可以看到）
- 已安装的 Mod 不会随创意工坊更新，需要手动触发重新安装（见下文"更新服务端和 Mod"）
- 服务端文件安装完成后，启动时不会自动更新游戏本体

## 未来计划
- 测试在 Windows 直接运行服务器与在 Linux 上使用 GE-Proton 运行的性能差异，以及在 Linux 上 UDP 性能是否更好
- 使用 [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) 替代 GE-Proton 运行 ASE 服务器是否更合适

## 使用方法

### 1. 使用 Docker Compose 部署

#### 方式一：使用现有配置文件
```bash
cd docker
docker-compose up -d
```

#### 方式二：创建自定义配置文件

也可以自己创建 `docker-compose.yml`：
```yaml
services:
  servers:
    image: tbro98/ase-server:latest
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
      # 需要海洋 DLC 更新前的版本时取消注释
      # - APP_UPDATE=376030 -beta preaquatica
      - GameModIds=
      - SERVER_ARGS=TheIsland?listen?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password?GameModIds= -NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore
    volumes:
      # 服务端文件，首次启动时下载到这里
      - ./ServerFiles:/home/steam/arkserver
      - ./Saved:/home/steam/arkserver/ShooterGame/Saved
      - ./Plugins:/home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins
      - ./ArkApiLogs:/home/steam/arkserver/ShooterGame/Binaries/Win64/logs
    # 也可以不绑定端口，直接桥接网络
    #networks:
    #  - ark-network

# networks:
#   ark-network:
#     driver: bridge
```

首次启动会下载服务端文件，可以用 `docker-compose logs -f` 查看进度，看到 `Starting ARK server...` 表示下载和安装已完成，服务端开始启动。

### 2. Docker 镜像版本

只提供一个镜像：`tbro98/ase-server`。`latest` 是最新版本，另有按版本号打的标签（如 `v0.35`）。

游戏分支由环境变量 `APP_UPDATE` 决定：

| `APP_UPDATE`                   | 说明                         |
| ------------------------------ | ---------------------------- |
| `376030`（默认）               | 正式版本（海洋 DLC 更新后）  |
| `376030 -beta preaquatica`     | 海洋 DLC 更新前的版本        |

`APP_UPDATE` 只在下载服务端文件时生效。已经安装过的服务器要切换分支，需要先删除服务端文件目录里的 `.install_complete`，再重启容器。

### 3. 配置服务器参数

服务器参数通过 `docker-compose.yml` 里的环境变量配置：

- `GameModIds`：要安装的 Mod ID，用逗号分隔
- `SERVER_ARGS`：服务器启动参数，包括地图、端口和其他设置，按空格拆分
- `APP_UPDATE`：下载的游戏分支，见上一节
- `TZ`：容器时区

示例：
```yaml
environment:
  - GameModIds=895711211,669673294,1136125765
  - SERVER_ARGS=TheIsland?listen?Port=7777?QueryPort=27015?MaxPlayers=70?RCONEnabled=True?RCONPort=32330?ServerAdminPassword=password?GameModIds=895711211,669673294,1136125765 -NoBattlEye -servergamelog -structurememopts -UseStructureStasisGrid -SecureSendArKPayload -UseItemDupeCheck -UseSecureSpawnRules -nosteamclient -game -server -log -MinimumTimeBetweenInventoryRetrieval=3600 -newsaveformat -usestore
```

> 列表写法（`- KEY=value`）里不要给值加引号，引号会被当成值的一部分。

`SERVER_ARGS` 按空格拆分，服务器名称等参数里不能有空格。需要空格时改用容器启动命令传参，每一项就是一个独立参数，传入后 `SERVER_ARGS` 会被忽略：
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

要应用配置更改，请重建容器：
```bash
docker-compose up -d --force-recreate
```

服务端文件保存在挂载的目录里，重建容器不会重新下载；`GameModIds` 里新增的 Mod 会在下次启动时下载，已经装过的会跳过。

### 4. 更新服务端和 Mod

安装状态记录在服务端文件目录（上例中的 `./ServerFiles`）里的两个文件中：

| 文件                 | 作用                                                     |
| -------------------- | -------------------------------------------------------- |
| `.install_complete`  | 服务端文件已安装。存在时启动跳过游戏本体的下载和更新     |
| `.installed_mods`    | 已安装的 Mod ID，每行一个。列在这里的 Mod 启动时跳过     |

- **更新游戏本体**：删除 `.install_complete` 后重启容器，SteamCMD 会在已有文件上更新并校验，不会从头下载
- **更新某个 Mod**：从 `.installed_mods` 里删掉该 Mod ID 所在的行，重启容器
- **ArkApi**：随镜像发布，每次启动都会同步到服务端目录，更新镜像即可升级；已存在的 `config.json` 不会被覆盖

### 5. 可用地图

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

### 6. 数据持久化

建议挂载以下目录：

| 本地路径      | 容器路径                                                          | 说明                                                   |
| ------------- | ----------------------------------------------------------------- | ------------------------------------------------------ |
| ./ServerFiles | /home/steam/arkserver                                             | 服务端文件、ArkApi 和安装标记。不挂载的话，每次重建容器都会重新下载 |
| ./Saved       | /home/steam/arkserver/ShooterGame/Saved                           | 服务器保存文件，包含 Config、Logs、SavedArks           |
| ./Plugins     | /home/steam/arkserver/ShooterGame/Binaries/Win64/ArkApi/Plugins   | ArkApi 插件存放位置                                    |
| ./ArkApiLogs  | /home/steam/arkserver/ShooterGame/Binaries/Win64/logs             | ArkApi 日志                                            |

`Saved`、`Plugins`、`ArkApiLogs` 嵌套挂载在服务端文件目录下面，单独挂出来方便备份和修改。

### 7. 常用命令

```bash
# 拉取镜像并启动容器
docker-compose up -d

# 查看日志（首次启动可以看到下载进度）
docker-compose logs -f

# 停止容器
docker-compose down

# 更新镜像后重建容器
docker-compose pull && docker-compose up -d
```

### 8. 自行构建镜像

```bash
docker build -f dockerfile -t tbro98/ase-server:latest .
```

推送 `v*` 标签时，GitHub Actions 会自动构建镜像并推送 `latest` 和对应版本号的标签。
