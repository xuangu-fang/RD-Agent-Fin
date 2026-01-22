#!/bin/bash
# Docker 连接诊断脚本

echo "=========================================="
echo "Docker 连接诊断"
echo "=========================================="
echo ""

# 检查 Docker 命令是否存在
echo "1️⃣ 检查 Docker 命令..."
if command -v docker > /dev/null 2>&1; then
    echo "✅ Docker 命令已安装"
    docker --version
else
    echo "❌ Docker 命令未找到"
    echo ""
    echo "💡 解决方案："
    echo "   在 WSL2 中，您需要安装 Docker Desktop for Windows："
    echo "   1. 在 Windows 中下载并安装 Docker Desktop"
    echo "      https://www.docker.com/products/docker-desktop/"
    echo "   2. 安装后，在 Docker Desktop 设置中启用 'Use the WSL 2 based engine'"
    echo "   3. 在 'Resources' -> 'WSL Integration' 中启用您的 WSL 发行版"
    echo "   4. 重启 Docker Desktop"
    echo ""
    exit 1
fi
echo ""

# 检查 Docker socket
echo "2️⃣ 检查 Docker socket..."
if [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket 存在: /var/run/docker.sock"
    ls -l /var/run/docker.sock
else
    echo "❌ Docker socket 不存在: /var/run/docker.sock"
    echo ""
    echo "💡 可能的原因："
    echo "   1. Docker Desktop 未启动（在 Windows 中检查 Docker Desktop 是否运行）"
    echo "   2. WSL Integration 未启用（在 Docker Desktop 设置中启用）"
    echo "   3. Docker Desktop 需要重启"
    echo ""
    echo "💡 解决方案："
    echo "   1. 在 Windows 中打开 Docker Desktop"
    echo "   2. 进入 Settings -> Resources -> WSL Integration"
    echo "   3. 确保您的 WSL 发行版已启用"
    echo "   4. 点击 'Apply & Restart'"
    echo ""
    exit 1
fi
echo ""

# 检查 Docker daemon 连接
echo "3️⃣ 检查 Docker daemon 连接..."
if docker ps > /dev/null 2>&1; then
    echo "✅ Docker daemon 连接正常"
    echo ""
    echo "当前运行的容器："
    docker ps
else
    echo "❌ 无法连接到 Docker daemon"
    ERROR_MSG=$(docker ps 2>&1)
    echo "错误信息: $ERROR_MSG"
    echo ""
    echo "💡 可能的原因和解决方案："
    echo ""
    echo "   如果使用 Docker Desktop："
    echo "   1. 确保 Docker Desktop 正在 Windows 中运行"
    echo "   2. 检查 Docker Desktop 系统托盘图标是否显示为运行状态"
    echo "   3. 在 Docker Desktop 设置中启用 WSL Integration"
    echo "   4. 重启 Docker Desktop"
    echo ""
    echo "   如果使用 Docker Engine（Linux 原生）："
    echo "   1. 检查 Docker 服务状态: sudo systemctl status docker"
    echo "   2. 启动 Docker 服务: sudo systemctl start docker"
    echo "   3. 确保当前用户在 docker 组中: sudo usermod -aG docker \$USER"
    echo "   4. 重新登录或运行: newgrp docker"
    echo ""
    exit 1
fi
echo ""

# 检查用户权限
echo "4️⃣ 检查 Docker 权限..."
if docker run --rm hello-world > /dev/null 2>&1; then
    echo "✅ 当前用户可以使用 Docker（无需 sudo）"
else
    echo "⚠️  当前用户可能需要 sudo 才能使用 Docker"
    echo ""
    echo "💡 解决方案："
    echo "   将当前用户添加到 docker 组："
    echo "   sudo usermod -aG docker \$USER"
    echo "   然后重新登录或运行: newgrp docker"
    echo ""
fi
echo ""

# 检查代理配置
echo "5️⃣ 检查 Docker 代理配置..."
if [ -f ~/.docker/config.json ]; then
    echo "✅ 找到 Docker 配置文件: ~/.docker/config.json"
    if grep -q "proxies" ~/.docker/config.json 2>/dev/null; then
        echo "✅ 检测到代理配置"
        echo ""
        echo "当前代理配置："
        cat ~/.docker/config.json | grep -A 5 "proxies" || echo "   (无法解析)"
    else
        echo "ℹ️  未检测到代理配置"
        echo "   如果需要配置代理，请运行："
        echo "   bash scripts/setup_docker_desktop_proxy.sh"
    fi
else
    echo "ℹ️  未找到 Docker 配置文件"
    echo "   如果需要配置代理，请运行："
    echo "   bash scripts/setup_docker_desktop_proxy.sh"
fi
echo ""

echo "=========================================="
echo "诊断完成"
echo "=========================================="
echo ""
echo "如果所有检查都通过，您应该可以正常运行："
echo "  rdagent data_science --competition arf-12-hours-prediction-task"
echo ""
