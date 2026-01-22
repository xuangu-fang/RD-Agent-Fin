#!/bin/bash
# WSL 中配置 Windows 代理的脚本

set -e

echo "=========================================="
echo "WSL 中配置 Windows 代理（用于 Docker）"
echo "=========================================="
echo ""

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 获取 Windows 主机 IP（WSL2 中）
echo "🔍 检测 Windows 主机 IP 地址..."
WINDOWS_IP=$(ip route show | grep -i default | awk '{ print $3}' | head -1)

if [ -z "$WINDOWS_IP" ]; then
    echo "⚠️  无法自动检测 Windows 主机 IP"
    echo "请手动输入 Windows 主机 IP（通常可以在 Windows 中运行 ipconfig 查看）"
    read -p "Windows 主机 IP: " WINDOWS_IP
fi

echo "✅ 检测到 Windows 主机 IP: $WINDOWS_IP"
echo ""

# 常见代理端口
echo "请输入 Windows 代理的端口号："
echo "  常见端口："
echo "  - Clash: 7890"
echo "  - V2Ray: 10809"
echo "  - 其他代理: 请查看 Windows 代理设置"
echo ""
read -p "代理端口 (默认 7890): " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-7890}

# 构建代理地址
PROXY_URL="http://$WINDOWS_IP:$PROXY_PORT"

echo ""
echo "📝 配置代理地址: $PROXY_URL"
echo ""

# 测试代理连接
echo "🔍 测试代理连接..."
if timeout 3 curl -s --proxy "$PROXY_URL" "https://www.google.com" > /dev/null 2>&1; then
    echo "✅ 代理连接测试成功！"
else
    echo "⚠️  代理连接测试失败，但将继续配置"
    echo "   请确认："
    echo "   1. Windows 代理服务正在运行"
    echo "   2. 代理端口正确（当前: $PROXY_PORT）"
    echo "   3. Windows 防火墙允许来自 WSL 的连接"
fi
echo ""

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
        echo "$ENV_VARS" | sed 's/Environment=/\n/g' | grep -E "PROXY|NO_PROXY"
    else
        echo "⚠️  无法验证代理配置（可能是 Docker Desktop）"
    fi
else
    echo "ℹ️  如果使用 Docker Desktop，请重启 Docker Desktop 以使配置生效"
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "📌 重要提示："
echo "1. Windows 代理必须正在运行"
echo "2. 如果使用 Docker Desktop，请重启 Docker Desktop"
echo "3. Windows 防火墙可能需要允许 WSL 访问代理端口"
echo ""
echo "📌 下一步："
echo "1. 测试代理是否生效："
echo "   docker pull gcr.io/kaggle-gpu-images/python:latest"
echo ""
echo "2. 如果下载仍然很慢，请检查："
echo "   - Windows 代理是否正常运行"
echo "   - Windows 代理端口是否正确（当前: $PROXY_PORT）"
echo "   - Windows 防火墙设置"
echo ""
echo "3. 查看 Windows 代理设置方法："
echo "   - 运行 'ipconfig' 查看 Windows IP"
echo "   - 查看代理客户端显示的端口号"
echo ""

