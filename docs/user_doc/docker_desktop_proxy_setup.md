# Docker Desktop 代理配置指南（WSL）

## 问题说明

在 WSL 中使用 Docker Desktop 时，Docker 服务不是通过 systemd 管理的，因此需要使用不同的配置方法。

## 快速配置（推荐）

运行自动化配置脚本：

```bash
bash /home/fsk/fang/RD-Agent/scripts/setup_docker_desktop_proxy.sh
```

脚本会自动：
1. 检测 Windows 主机 IP 和代理端口
2. 更新 Docker Desktop 的配置文件 (`~/.docker/config.json`)
3. 提示重启 Docker Desktop

## 手动配置步骤

### 步骤 1：找到 Docker 配置文件位置

Docker Desktop 的配置文件位于：
```
~/.docker/config.json
```

### 步骤 2：创建或更新配置文件

创建配置目录（如果不存在）：
```bash
mkdir -p ~/.docker
```

创建或编辑配置文件：
```bash
cat > ~/.docker/config.json <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "http://WINDOWS_IP:PROXY_PORT",
      "httpsProxy": "http://WINDOWS_IP:PROXY_PORT",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
EOF
```

**示例**（Windows IP 是 172.19.32.1，代理端口是 7890）：

```bash
cat > ~/.docker/config.json <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.19.32.1:7890",
      "httpsProxy": "http://172.19.32.1:7890",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
EOF
```

### 步骤 3：获取 Windows IP 地址

在 WSL 中运行：
```bash
ip route show | grep -i default | awk '{ print $3}' | head -1
```

### 步骤 4：重启 Docker Desktop

**重要**：配置完成后，必须在 Windows 中重启 Docker Desktop：
1. 右键点击系统托盘中的 Docker 图标
2. 选择 "Quit Docker Desktop"
3. 重新打开 Docker Desktop

### 步骤 5：验证配置

重启 Docker Desktop 后，测试代理是否生效：

```bash
# 查看配置
cat ~/.docker/config.json

# 测试拉取镜像
docker pull gcr.io/kaggle-gpu-images/python:latest
```

## 方法 2：通过 Docker Desktop 设置界面配置（推荐，用于 docker pull）

**重要**：`~/.docker/config.json` 中的代理配置主要用于容器内的代理环境变量，而 `docker pull` 等操作需要使用 Docker Desktop 的 GUI 配置。

### 配置步骤

1. **打开 Docker Desktop**
   - 确保 Docker Desktop 正在运行

2. **进入设置**：
   - 点击右上角的设置图标（齿轮图标 ⚙️）
   - 或者右键点击系统托盘中的 Docker 图标 -> Settings

3. **找到代理设置**：
   - 在左侧菜单中找到 **"Resources"** -> **"Proxies"**
   - 或者直接在设置中搜索 "Proxy"

4. **配置代理**：
   - 启用 **"Manual proxy configuration"**
   - 在 **"Web Server (HTTP)"** 中输入：`http://172.19.32.1:7890`
   - 在 **"Secure Web Server (HTTPS)"** 中输入：`http://172.19.32.1:7890`
     - 注意：根据您的实际 Windows IP 和代理端口调整
     - 在 WSL 中运行 `ip route show | grep default | awk '{print $3}'` 获取 Windows IP
   - 在 **"Bypass for"** 中输入：`localhost,127.0.0.1`
     - **重要**：不要在这里添加 `docker.io`，否则 Docker Hub 无法通过代理访问

5. **应用设置**：
   - 点击 **"Apply & Restart"** 按钮
   - Docker Desktop 会自动重启以应用新配置

6. **验证配置**：
   ```bash
   # 检查 Docker 代理配置
   docker info | grep -i proxy
   
   # 应该显示您配置的代理地址，而不是 http.docker.internal:3128
   
   # 测试拉取镜像
   docker pull pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime
   ```

### 获取 Windows IP 地址

在 WSL 中运行：
```bash
ip route show | grep -i default | awk '{ print $3}' | head -1
```

或者查看当前配置：
```bash
# 从现有配置中提取
grep -oP '"httpProxy":\s*"\K[^"]+' ~/.docker/config.json | cut -d: -f2 | cut -d/ -f3 | cut -d: -f1
```

## 常见问题

### Q: 配置文件已创建，但代理不生效？

A: 
1. **确认已重启 Docker Desktop**（这是最关键的步骤）
2. 检查代理地址是否正确
3. 确认 Windows 代理正在运行
4. 确认代理启用了"允许局域网连接"

### Q: 如何查看当前的代理配置？

A: 
```bash
cat ~/.docker/config.json
```

### Q: 如何删除代理配置？

A: 
```bash
# 备份原配置
cp ~/.docker/config.json ~/.docker/config.json.bak

# 删除代理部分（保留其他配置）
# 或者直接删除配置文件
rm ~/.docker/config.json
```

### Q: Docker Desktop 和 WSL 中的配置文件有什么区别？

A: 
- Docker Desktop 使用 `~/.docker/config.json`（用户级别配置）
- Linux 原生 Docker 使用 `/etc/systemd/system/docker.service.d/http-proxy.conf`（系统级别配置）
- 两者配置格式不同

### Q: 如何测试代理连接？

A: 
```bash
# 测试到 Windows 代理的连接
curl --proxy http://172.19.32.1:7890 https://www.google.com

# 测试 Docker 拉取镜像
docker pull gcr.io/kaggle-gpu-images/python:latest
```

## 验证配置成功

配置并重启 Docker Desktop 后，运行：

```bash
# 1. 检查配置
cat ~/.docker/config.json

# 2. 测试拉取镜像（应该会快很多）
time docker pull gcr.io/kaggle-gpu-images/python:latest

# 3. 运行 RD-Agent
rdagent data_science --competition arf-12-hours-prediction-task
```

如果下载速度明显提升，说明配置成功！

## 一键测试和配置

可以使用以下脚本快速测试和配置：

```bash
# 1. 测试代理连接
bash scripts/test_wsl_proxy.sh

# 2. 配置 Docker Desktop
bash scripts/setup_docker_desktop_proxy.sh

# 3. 在 Windows 中重启 Docker Desktop

# 4. 验证配置
docker pull gcr.io/kaggle-gpu-images/python:latest
```

