#!/bin/bash
# Docker 下载状态诊断脚本

echo "=========================================="
echo "Docker 镜像下载诊断"
echo "=========================================="
echo ""

# 检查当前下载状态
echo "📊 检查当前镜像状态..."
docker images | grep -E "kaggle|REPOSITORY" || echo "未找到相关镜像"
echo ""

# 检查 Docker 代理配置
echo "🔍 检查 Docker 代理配置..."
if systemctl show docker 2>/dev/null | grep -q "HTTP_PROXY"; then
    echo "✅ 检测到 Docker 代理配置："
    systemctl show --property=Environment docker | grep -E "PROXY|NO_PROXY" | sed 's/Environment=/\n/g' | grep -E "PROXY|NO_PROXY"
else
    echo "⚠️  未检测到 Docker 代理配置"
    echo "   建议配置代理以加速 gcr.io 访问"
fi
echo ""

# 检查系统代理
echo "🔍 检查系统代理环境变量..."
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    echo "✅ 检测到系统代理："
    echo "   HTTP_PROXY=$HTTP_PROXY"
    echo "   HTTPS_PROXY=$HTTPS_PROXY"
else
    echo "⚠️  未检测到系统代理环境变量"
fi
echo ""

# 测试网络连接
echo "🌐 测试到 gcr.io 的网络连接..."
if timeout 5 curl -s -I https://gcr.io/v2/ > /dev/null 2>&1; then
    echo "✅ 可以连接到 gcr.io"
else
    echo "❌ 无法连接到 gcr.io（可能需要代理）"
fi
echo ""

# 检查常见的本地代理服务
echo "🔍 检查本地代理服务..."
PROXY_FOUND=false
for port in 7890 10809 1080 8080 8888; do
    if curl -s --connect-timeout 2 "http://127.0.0.1:$port" > /dev/null 2>&1; then
        echo "✅ 检测到代理服务运行在端口 $port"
        PROXY_FOUND=true
    fi
done

if [ "$PROXY_FOUND" = false ]; then
    echo "⚠️  未检测到本地代理服务"
fi
echo ""

# 提供建议
echo "=========================================="
echo "💡 优化建议"
echo "=========================================="
echo ""

if [ "$PROXY_FOUND" = true ]; then
    echo "✅ 检测到代理服务，建议配置 Docker 使用代理："
    echo "   sudo bash scripts/setup_docker_proxy.sh"
elif [ -n "$HTTP_PROXY" ]; then
    echo "✅ 检测到系统代理，建议配置 Docker 使用相同的代理："
    echo "   sudo bash scripts/setup_docker_proxy.sh"
else
    echo "⚠️  当前下载速度较慢的可能原因："
    echo "   1. 镜像很大（约 10GB+）"
    echo "   2. 网络连接到 gcr.io 较慢"
    echo ""
    echo "💡 解决方案："
    echo "   1. 配置代理（如果有）："
    echo "      sudo bash scripts/setup_docker_proxy.sh"
    echo ""
    echo "   2. 让下载继续运行（虽然慢但能完成）"
    echo ""
    echo "   3. 使用后台运行（screen/tmux）："
    echo "      screen -S docker-pull"
    echo "      docker pull gcr.io/kaggle-gpu-images/python:latest"
    echo ""
    echo "   4. 考虑使用替代镜像（见 Dockerfile.alternative）"
fi

echo ""

