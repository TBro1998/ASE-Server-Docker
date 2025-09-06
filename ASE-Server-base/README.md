# ARK Server Base Docker Image

这个dockerfile可以构建ARK服务器的基础镜像，支持普通版本和beta preaquatica版本。

## 使用方法

### 构建普通版本（默认）
```bash
docker build -t ark-server-base .
```

### 构建beta preaquatica版本
```bash
docker build --build-arg USE_BETA=true -t ark-server-base-beta .
```

## 构建参数说明

- `USE_BETA`: 设置为`true`时构建beta preaquatica版本，默认为`false`（普通版本）

## 原有的两个dockerfile

- `steamcmd/dockerfile`: 普通版本
- `steamcmd-preaquatica/dockerfile`: beta preaquatica版本

现在可以使用统一的dockerfile替代这两个文件。