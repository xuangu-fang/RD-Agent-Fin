# Docker Desktop 代理配置详解

## 代理配置的作用范围

Docker Desktop 的代理配置**主要影响 Docker 容器内的网络访问**，而不是宿主机（WSL/Windows）的网络流量。

### 配置位置

配置文件位置：`~/.docker/config.json`

当前配置：
```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.19.32.1:7890",
      "httpsProxy": "http://172.19.32.1:7890",
      "noProxy": "localhost,127.0.0.1,docker.io"
    }
  }
}
```

## 哪些流量会走代理？

### ✅ 会走代理的流量

1. **Docker 容器内的 HTTP/HTTPS 请求**
   - 容器内应用发起的网络请求（如 `docker pull`、`pip install`、`wget` 等）
   - 这些请求会通过配置的代理访问外网

2. **Docker 构建时的网络请求**
   - `docker build` 时的 `RUN apt-get update`、`RUN pip install` 等
   - 下载基础镜像时的网络请求

3. **容器间通信**（如果配置了代理）
   - 容器访问外部 API 的请求

### ❌ 不会走代理的流量

1. **宿主机（WSL）的网络流量**
   - 在 WSL 终端中直接运行的命令（如 `curl`、`wget`）
   - Python 脚本在宿主机上运行时
   - 这些流量**不会**走 Docker 代理

2. **noProxy 列表中的地址**
   - `localhost` - 本地回环地址
   - `127.0.0.1` - 本地回环地址
   - `docker.io` - Docker Hub（如果不需要代理访问）

3. **Docker 守护进程的本地操作**
   - Docker 守护进程本身的操作（如管理容器、镜像等）

## 配置说明

### httpProxy 和 httpsProxy

- `httpProxy`: HTTP 流量使用的代理
- `httpsProxy`: HTTPS 流量使用的代理
- 当前都配置为 `http://172.19.32.1:7890`（Windows 主机的代理）

### noProxy

`noProxy` 是一个逗号分隔的列表，指定哪些地址**不走代理**：

- `localhost` - 本地主机
- `127.0.0.1` - 本地回环
- `docker.io` - Docker Hub（如果 Docker Hub 不需要代理）

**注意**：如果 `docker.io` 也需要代理访问，应该从 `noProxy` 中移除。

## 如何验证代理是否生效？

### 1. 在容器内测试代理

```bash
# 启动一个测试容器
docker run --rm -it alpine sh

# 在容器内测试
apk add curl
curl -I https://www.google.com
```

如果配置正确，这个请求应该能通过代理成功访问。

### 2. 测试 Docker pull

```bash
# 拉取镜像（应该会走代理）
docker pull gcr.io/kaggle-gpu-images/python:latest
```

### 3. 检查容器内的环境变量

Docker Desktop 会自动将代理配置注入到容器中：

```bash
docker run --rm alpine env | grep -i proxy
```

应该能看到：
- `HTTP_PROXY=http://172.19.32.1:7890`
- `HTTPS_PROXY=http://172.19.32.1:7890`
- `NO_PROXY=localhost,127.0.0.1,docker.io`

## 如果需要让宿主机也走代理

如果需要在 WSL 中也使用代理（不仅限于 Docker 容器），需要额外配置：

### 方法 1：设置系统环境变量

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
export HTTP_PROXY=http://172.19.32.1:7890
export HTTPS_PROXY=http://172.19.32.1:7890
export NO_PROXY=localhost,127.0.0.1
```

### 方法 2：使用代理配置文件

创建 `~/.proxyrc`：

```bash
export HTTP_PROXY=http://172.19.32.1:7890
export HTTPS_PROXY=http://172.19.32.1:7890
export NO_PROXY=localhost,127.0.0.1
```

然后在需要时加载：
```bash
source ~/.proxyrc
```

## 常见问题

### Q: Docker 容器内的应用无法访问外网？

A: 
1. 检查代理配置是否正确
2. 确认 Windows 代理服务正在运行
3. 检查 Windows 防火墙设置
4. 确认代理地址和端口正确

### Q: 容器内访问 localhost 是否走代理？

A: 不会，`localhost` 和 `127.0.0.1` 在 `noProxy` 列表中，不会走代理。

### Q: 如何让 Docker Hub 也走代理？

A: 从 `noProxy` 中移除 `docker.io`：

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.19.32.1:7890",
      "httpsProxy": "http://172.19.32.1:7890",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
```

### Q: 如何禁用代理？

A: 删除或注释掉 `~/.docker/config.json` 中的 `proxies` 配置，或设置代理为空字符串。

## 总结

- ✅ **Docker 容器内的网络流量**会走代理
- ❌ **宿主机的网络流量**不会走代理（需要单独配置）
- ⚠️ **noProxy 列表中的地址**不会走代理
- 🔄 修改配置后需要**重启 Docker Desktop** 才能生效

