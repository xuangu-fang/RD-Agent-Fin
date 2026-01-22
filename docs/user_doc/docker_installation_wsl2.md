# WSL2 中安装和配置 Docker 指南

## 问题说明

在 WSL2 环境中运行 `rdagent data_science` 命令时，如果出现以下错误：

```
DockerException: Error while fetching server API version: ('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))
```

这通常意味着 Docker 未安装或 Docker daemon 未运行。

## 解决方案

### 方法 1：使用 Docker Desktop for Windows（推荐）

这是 WSL2 中最简单的方法：

#### 步骤 1：安装 Docker Desktop

1. 在 Windows 中下载 Docker Desktop：
   - 访问：https://www.docker.com/products/docker-desktop/
   - 下载并安装 Docker Desktop for Windows

2. 安装完成后，启动 Docker Desktop

#### 步骤 2：配置 WSL Integration

1. 打开 Docker Desktop
2. 进入 **Settings**（设置）
3. 选择 **Resources** -> **WSL Integration**
4. 确保以下选项已启用：
   - ✅ **Enable integration with my default WSL distro**
   - ✅ 启用您当前使用的 WSL 发行版（例如：Ubuntu-24.04）

5. 点击 **Apply & Restart**

#### 步骤 3：验证安装

在 WSL2 终端中运行：

```bash
# 检查 Docker 命令
docker --version

# 检查 Docker 连接
docker ps

# 测试运行容器
docker run hello-world
```

如果所有命令都能正常运行，说明 Docker 已正确安装。

### 方法 2：在 WSL2 中安装 Docker Engine（高级用户）

如果您不想使用 Docker Desktop，可以在 WSL2 中直接安装 Docker Engine：

#### 步骤 1：安装 Docker Engine

```bash
# 更新包索引
sudo apt-get update

# 安装必要的依赖
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加 Docker 官方 GPG 密钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 设置仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 步骤 2：启动 Docker 服务

```bash
# 启动 Docker 服务
sudo systemctl start docker

# 设置开机自启
sudo systemctl enable docker

# 验证 Docker 运行状态
sudo systemctl status docker
```

#### 步骤 3：配置用户权限（无需 sudo）

```bash
# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新加载组权限（或重新登录）
newgrp docker

# 验证（应该不需要 sudo）
docker run hello-world
```

## 诊断工具

如果遇到问题，可以使用诊断脚本：

```bash
bash scripts/diagnose_docker_connection.sh
```

该脚本会检查：
- Docker 命令是否安装
- Docker socket 是否存在
- Docker daemon 是否可连接
- 用户权限是否正确
- 代理配置情况

## 常见问题

### 问题 1：`docker: command not found`

**原因**：Docker 未安装或未正确配置 WSL Integration

**解决方案**：
- 如果使用 Docker Desktop：确保在设置中启用了 WSL Integration
- 如果使用 Docker Engine：按照上面的方法 2 安装

### 问题 2：`Cannot connect to the Docker daemon`

**原因**：Docker daemon 未运行

**解决方案**：
- Docker Desktop：确保 Docker Desktop 在 Windows 中正在运行
- Docker Engine：运行 `sudo systemctl start docker`

### 问题 3：`Permission denied while trying to connect to the Docker daemon socket`

**原因**：当前用户不在 docker 组中

**解决方案**：
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 问题 4：Docker Desktop 在 WSL2 中无法使用

**原因**：WSL Integration 未正确配置

**解决方案**：
1. 打开 Docker Desktop 设置
2. 进入 Resources -> WSL Integration
3. 确保您的 WSL 发行版已启用
4. 点击 Apply & Restart
5. 重启 WSL2 终端

## 配置代理（可选）

如果需要通过代理访问 Docker 镜像仓库，请参考：
- [Docker Desktop 代理配置](docker_desktop_proxy_setup.md)
- [WSL 代理配置](wsl_proxy_setup.md)

## 下一步

安装并验证 Docker 后，您可以：

1. 运行健康检查：
   ```bash
   rdagent health-check --check-docker
   ```

2. 运行数据科学任务：
   ```bash
   rdagent data_science --competition arf-12-hours-prediction-task
   ```

## 参考链接

- [Docker Desktop 官方文档](https://docs.docker.com/desktop/install/windows-install/)
- [Docker Engine 安装指南](https://docs.docker.com/engine/install/ubuntu/)
- [WSL2 与 Docker Desktop 集成](https://docs.docker.com/desktop/wsl/)
