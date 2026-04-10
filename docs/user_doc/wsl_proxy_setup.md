# WSL 中使用 Windows 代理配置指南

## 问题背景

在 WSL (Windows Subsystem for Linux) 环境中，Docker 运行在 Linux 子系统中，但代理服务运行在 Windows 主机上。需要配置 Docker 通过 Windows 主机的代理来访问 gcr.io。

## 快速配置（推荐）

运行自动化配置脚本：

```bash
sudo bash /home/fsk/fang/RD-Agent/scripts/setup_wsl_proxy.sh
```

脚本会自动：
1. 检测 Windows 主机 IP 地址
2. 提示输入代理端口
3. 配置 Docker 使用 Windows 代理
4. 重启 Docker 服务

## 手动配置步骤

### 步骤 1：获取 Windows 主机 IP

在 WSL 中运行：

```bash
ip route show | grep -i default | awk '{ print $3}' | head -1
```

或者，在 Windows PowerShell 中运行：

```powershell
ipconfig | findstr IPv4
```

记录下主网卡的 IP 地址（通常是 `172.x.x.1` 或 `192.168.x.1`）。

### 步骤 2：查找 Windows 代理端口

查看你的代理客户端（Clash、V2Ray 等）的端口设置：
- **Clash**: 通常是 `7890`（HTTP）或 `7891`（SOCKS5）
- **V2Ray**: 通常是 `10809`（HTTP）或 `10808`（SOCKS5）
- **其他代理**: 查看代理软件的设置页面

### 步骤 3：配置 Docker 使用 Windows 代理

创建 Docker 代理配置文件：

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
```

创建配置文件（替换 `WINDOWS_IP` 和 `PROXY_PORT`）：

```bash
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://WINDOWS_IP:PROXY_PORT"
Environment="HTTPS_PROXY=http://WINDOWS_IP:PROXY_PORT"
Environment="NO_PROXY=localhost,127.0.0.1,docker.io"
EOF
```

**示例**（Windows IP 是 172.25.0.1，代理端口是 7890）：

```bash
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://172.25.0.1:7890"
Environment="HTTPS_PROXY=http://172.25.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,docker.io"
EOF
```

### 步骤 4：重启 Docker

如果使用 Docker daemon（Linux 原生）：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

如果使用 Docker Desktop：

1. 关闭 Docker Desktop
2. 重新打开 Docker Desktop

### 步骤 5：验证配置

测试代理是否生效：

```bash
# 查看 Docker 环境变量
sudo systemctl show --property=Environment docker

# 测试拉取镜像
docker pull gcr.io/kaggle-gpu-images/python:latest
```

## 常见代理客户端配置

### Clash for Windows

1. **查找 HTTP 端口**：
   - 打开 Clash
   - 查看 "端口" 设置，HTTP 端口通常是 `7890`

2. **确保允许局域网连接**：
   - 在 Clash 设置中启用 "Allow LAN"（允许局域网）
   - 这是必要的，否则 WSL 无法访问

### V2RayN

1. **查找 HTTP 端口**：
   - 打开 V2RayN
   - 查看 "参数设置" -> "本地监听端口"，HTTP 通常是 `10809`

2. **确保允许局域网连接**：
   - 在设置中启用 "允许来自局域网的连接"

### 其他代理客户端

查看代理客户端的设置，找到：
- HTTP 代理端口（不是 SOCKS5 端口）
- 确保启用"允许局域网连接"或"允许来自局域网的连接"

## 常见问题排查

### 问题 1：无法连接到 Windows 代理

**症状**：`curl: (7) Failed to connect to 172.x.x.1:7890`

**解决方案**：
1. 确认 Windows 代理正在运行
2. 确认代理端口正确
3. 在代理客户端中启用"允许局域网连接"
4. 检查 Windows 防火墙设置（可能需要允许该端口）

### 问题 2：Docker Desktop 无法使用代理

**症状**：配置后 Docker Desktop 仍然无法访问 gcr.io

**解决方案**：
1. Docker Desktop 可能需要重启（完全关闭后重新打开）
2. 检查 Docker Desktop 的设置中是否有代理配置选项
3. 尝试在 Docker Desktop 的设置中直接配置代理

### 问题 3：Windows IP 地址变化

**症状**：重启后代理失效

**解决方案**：
- WSL2 中，Windows 主机 IP 可能会变化
- 使用脚本自动检测：`ip route show | grep -i default | awk '{ print $3}'`
- 或者使用 Windows 主机名（如果支持）：`http://$(hostname).local:7890`

### 问题 4：SOCKS5 代理

如果代理只提供 SOCKS5（如 V2Ray 的 10808 端口），需要转换为 HTTP 代理：

**选项 A**：使用 `socat` 转换（在 WSL 中）：

```bash
# 安装 socat
sudo apt-get install -y socat

# 创建 HTTP 代理（后台运行）
socat TCP-LISTEN:8118,fork,reuseaddr SOCKS5:127.0.0.1:WINDOWS_IP:10808 &

# 然后在 Docker 配置中使用 http://127.0.0.1:8118
```

**选项 B**：使用代理客户端同时提供 HTTP 代理（推荐）

大多数代理客户端都支持同时提供 HTTP 和 SOCKS5 代理，只需启用 HTTP 代理即可。

## 验证配置成功

配置完成后，运行以下命令验证：

```bash
# 1. 检查 Docker 环境变量
sudo systemctl show --property=Environment docker

# 2. 测试代理连接
curl --proxy http://WINDOWS_IP:PROXY_PORT https://www.google.com

# 3. 测试 Docker 拉取镜像
time docker pull gcr.io/kaggle-gpu-images/python:latest
```

如果下载速度明显提升，说明配置成功！

## 一键测试脚本

创建一个测试脚本：

```bash
#!/bin/bash
WINDOWS_IP=$(ip route show | grep -i default | awk '{ print $3}' | head -1)
PROXY_PORT=7890  # 根据实际情况修改

echo "测试代理: http://$WINDOWS_IP:$PROXY_PORT"
curl --proxy "http://$WINDOWS_IP:$PROXY_PORT" -I https://www.google.com
```

保存为 `test_proxy.sh`，运行 `bash test_proxy.sh` 测试代理连接。

