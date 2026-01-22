#!/bin/bash
# 快速配置脚本 - 使用检测到的代理地址

set -e

echo "=========================================="
echo "配置 Docker 使用 Windows 代理"
echo "=========================================="
echo ""

# 检测 Windows IP
WINDOWS_IP=$(ip route show | grep -i default | awk '{ print $3}' | head -1)
PROXY_PORT=7890  # 从测试结果中检测到的端口
PROXY_URL="http://$WINDOWS_IP:$PROXY_PORT"

echo "✅ 使用代理地址: $PROXY_URL"
echo ""

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    echo ""
    echo "运行命令："
    echo "  sudo bash $0"
    exit 1
fi

# 创建 Docker 服务目录
mkdir -p /etc/systemd/system/docker.service.d

# 备份现有配置
if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
    echo "⚠️  检测到已存在的代理配置，将备份为 http-proxy.conf.bak"
    cp /etc/systemd/system/docker.service.d/http-proxy.conf /etc/systemd/system/docker.service.d/http-proxy.conf.bak
fi

# 创建代理配置
cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=localhost,127.0.0.1,docker.io"
EOF

echo "✅ 代理配置已创建"
echo ""

# 重启 Docker 服务
echo "🔄 重启 Docker 服务..."
if command -v systemctl > /dev/null 2>&1; then
    systemctl daemon-reload
    systemctl restart docker
    echo "✅ Docker 服务已重启"
else
    echo "⚠️  未检测到 systemctl，可能是 Docker Desktop"
    echo "   请手动重启 Docker Desktop"
fi
echo ""

# 验证配置
echo "🔍 验证代理配置..."
if command -v systemctl > /dev/null 2>&1; then
    ENV_VARS=$(systemctl show --property=Environment docker 2>/dev/null || echo "")
    if echo "$ENV_VARS" | grep -q "HTTP_PROXY"; then
        echo "✅ 代理配置成功！"
        echo ""
        echo "当前 Docker 环境变量："
        echo "$ENV_VARS" | sed 's/Environment=/\n/g' | grep -E "PROXY|NO_PROXY" | sed 's/ /\n/g'
    else
        echo "⚠️  无法验证代理配置"
    fi
else
    echo "ℹ️  如果使用 Docker Desktop，请重启 Docker Desktop 以使配置生效"
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "📌 下一步："
echo "1. 如果使用 Docker Desktop，请重启 Docker Desktop"
echo ""
echo "2. 测试代理是否生效："
echo "   docker pull gcr.io/kaggle-gpu-images/python:latest"
echo ""
echo "3. 验证配置："
echo "   sudo systemctl show --property=Environment docker"
echo ""

