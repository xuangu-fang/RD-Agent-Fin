# Docker 镜像加速配置指南

## 问题描述

在使用 RD-Agent 时，如果遇到 Docker 镜像构建缓慢的问题，特别是从 `gcr.io/kaggle-gpu-images/python:latest` 拉取镜像时，这通常是因为：

1. **Google Container Registry (gcr.io) 在中国访问受限**：gcr.io 在中国大陆地区访问速度很慢或无法访问
2. **网络连接问题**：默认的 Docker Hub 镜像源可能较慢

## 解决方案

### 方案 1：配置 Docker 镜像加速器（推荐）

配置 Docker 使用国内镜像加速器，可以显著提升镜像拉取速度。

#### 步骤 1：创建或编辑 Docker daemon 配置文件

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF
```

#### 步骤 2：重启 Docker 服务

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### 步骤 3：验证配置

```bash
docker info | grep -A 10 "Registry Mirrors"
```

**注意**：Docker 镜像加速器主要用于加速 Docker Hub 的镜像，对于 gcr.io 等第三方镜像仓库可能效果有限。

### 方案 2：使用代理访问 gcr.io

如果你有可用的代理，可以配置 Docker 使用代理来访问 gcr.io：

#### 步骤 1：配置 Docker 代理

创建 Docker 服务目录：

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
```

创建代理配置文件：

```bash
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<-'EOF'
[Service]
Environment="HTTP_PROXY=http://your-proxy-host:port"
Environment="HTTPS_PROXY=http://your-proxy-host:port"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
```

将 `your-proxy-host:port` 替换为你的实际代理地址。

#### 步骤 2：重启 Docker 服务

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 方案 3：手动拉取镜像（如果已经有镜像文件）

如果你已经在其他环境中拉取了该镜像，可以：

1. **导出镜像**（在其他机器上）：
```bash
docker save gcr.io/kaggle-gpu-images/python:latest -o kaggle-python.tar
```

2. **导入镜像**（在当前机器上）：
```bash
docker load -i kaggle-python.tar
```

### 方案 4：使用替代的基础镜像（需要修改 Dockerfile）

如果以上方案都无法解决，可以考虑修改 Dockerfile 使用替代的基础镜像。

**警告**：修改 Dockerfile 可能会影响功能的兼容性，请谨慎操作。

可以尝试使用 Kaggle 官方提供的其他镜像源，或者使用 PyTorch 官方镜像作为替代。

## 验证解决方案

配置完成后，可以尝试手动拉取镜像来验证：

```bash
docker pull gcr.io/kaggle-gpu-images/python:latest
```

或者直接运行 RD-Agent 命令：

```bash
rdagent data_science --competition arf-12-hours-prediction-task
```

## 其他建议

1. **使用 VPN 或代理**：如果有稳定的 VPN 或代理服务，这是最直接的解决方案
2. **使用镜像站**：一些第三方镜像站可能提供了 gcr.io 的镜像缓存
3. **耐心等待**：如果网络连接不稳定但可以访问，可能需要较长时间才能完成下载

## 常见问题

### Q: 配置了镜像加速器后仍然很慢怎么办？

A: Docker 镜像加速器主要加速 Docker Hub 的镜像。对于 gcr.io，建议使用代理或 VPN。

### Q: 如何查看 Docker 构建的详细日志？

A: 在构建时添加详细输出：
```bash
docker build --progress=plain -t local_ds:latest /path/to/dockerfile
```

### Q: 能否跳过镜像构建直接使用已有镜像？

A: 如果镜像已经存在，Docker 会跳过构建步骤。你可以先手动拉取或导入镜像。

