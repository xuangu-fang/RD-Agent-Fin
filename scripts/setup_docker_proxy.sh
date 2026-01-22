#!/bin/bash
# Docker 代理配置脚本（针对 gcr.io 加速）

set -e

echo "=========================================="
echo "Docker 代理配置脚本（gcr.io 加速）"
echo "=========================================="
echo ""

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 检测常见的代理端口
detect_proxy() {
    echo "🔍 正在检测可用的代理..."
    
    # 常见代理端口
    PROXY_PORTS=(7890 10809 1080 8080 8888)
    
    for port in "${PROXY_PORTS[@]}"; do
        if curl -s --connect-timeout 2 "http://127.0.0.1:$port" > /dev/null 2>&1; then
            echo "✅ 检测到代理运行在端口 $port"
            echo "http://127.0.0.1:$port"
            return 0
        fi
    done
    
    return 1
}

# 提示用户输入代理信息
PROXY_URL=""
if detect_proxy; then
    DETECTED_PROXY=$(detect_proxy)
    read -p "检测到代理 $DETECTED_PROXY，是否使用？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PROXY_URL="$DETECTED_PROXY"
    fi
fi

if [ -z "$PROXY_URL" ]; then
    echo "请输入代理地址（例如：http://127.0.0.1:7890 或 http://proxy.example.com:8080）"
    echo "如果使用 Clash，通常是：http://127.0.0.1:7890"
    echo "如果使用 V2Ray，通常是：http://127.0.0.1:10809"
    read -p "代理地址: " PROXY_URL
    
    if [ -z "$PROXY_URL" ]; then
        echo "❌ 未提供代理地址，退出"
        exit 1
    fi
fi

echo ""
echo "📝 配置代理: $PROXY_URL"
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
systemctl daemon-reload
systemctl restart docker

echo "✅ Docker 服务已重启"
echo ""

# 验证配置
echo "🔍 验证代理配置..."
ENV_VARS=$(systemctl show --property=Environment docker)
if echo "$ENV_VARS" | grep -q "HTTP_PROXY"; then
    echo "✅ 代理配置成功！"
    echo ""
    echo "当前 Docker 环境变量："
    echo "$ENV_VARS" | sed 's/Environment=/\n/g' | grep -E "PROXY|NO_PROXY"
else
    echo "⚠️  无法验证代理配置"
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "📌 下一步："
echo "1. 测试代理是否生效："
echo "   docker pull gcr.io/kaggle-gpu-images/python:latest"
echo ""
echo "2. 如果下载仍然很慢，请检查："
echo "   - 代理服务是否正常运行"
echo "   - 代理地址是否正确"
echo "   - 代理是否支持 HTTPS 连接"
echo ""
echo "3. 查看当前配置："
echo "   sudo systemctl show --property=Environment docker"
echo ""

