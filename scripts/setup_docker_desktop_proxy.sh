#!/bin/bash
# Docker Desktop 代理配置脚本（WSL）

set -e

echo "=========================================="
echo "配置 Docker Desktop 使用 Windows 代理"
echo "=========================================="
echo ""

# 检测 Windows IP
WINDOWS_IP=$(ip route show | grep -i default | awk '{ print $3}' | head -1)
PROXY_PORT=7890  # 从测试结果中检测到的端口
PROXY_URL="http://$WINDOWS_IP:$PROXY_PORT"

echo "✅ 使用代理地址: $PROXY_URL"
echo ""

# 检查 Docker Desktop 配置文件位置
DOCKER_CONFIG_DIR="$HOME/.docker"
DOCKER_CONFIG_FILE="$DOCKER_CONFIG_DIR/config.json"

# 创建配置目录
mkdir -p "$DOCKER_CONFIG_DIR"

# 备份现有配置
if [ -f "$DOCKER_CONFIG_FILE" ]; then
    echo "⚠️  检测到已存在的 Docker 配置，将备份为 config.json.bak"
    cp "$DOCKER_CONFIG_FILE" "$DOCKER_CONFIG_FILE.bak"
fi

# 读取现有配置或创建新配置
if [ -f "$DOCKER_CONFIG_FILE" ]; then
    # 使用 jq 更新配置（如果可用）
    if command -v jq > /dev/null 2>&1; then
        echo "✅ 使用 jq 更新配置..."
        jq '.proxies.default.httpProxy = "'$PROXY_URL'" | .proxies.default.httpsProxy = "'$PROXY_URL'" | .proxies.default.noProxy = "localhost,127.0.0.1,docker.io"' "$DOCKER_CONFIG_FILE" > "$DOCKER_CONFIG_FILE.tmp" && mv "$DOCKER_CONFIG_FILE.tmp" "$DOCKER_CONFIG_FILE"
    else
        # 如果没有 jq，手动创建配置
        echo "⚠️  未安装 jq，将创建新的配置文件"
        cat > "$DOCKER_CONFIG_FILE" <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_URL",
      "httpsProxy": "$PROXY_URL",
      "noProxy": "localhost,127.0.0.1,docker.io"
    }
  }
}
EOF
    fi
else
    # 创建新配置
    echo "📝 创建新的 Docker 配置文件..."
    cat > "$DOCKER_CONFIG_FILE" <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_URL",
      "httpsProxy": "$PROXY_URL",
      "noProxy": "localhost,127.0.0.1,docker.io"
    }
  }
}
EOF
fi

echo "✅ Docker 配置文件已更新: $DOCKER_CONFIG_FILE"
echo ""

# 显示配置内容
echo "📋 当前配置内容："
cat "$DOCKER_CONFIG_FILE"
echo ""

echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "⚠️  重要：Docker Desktop 需要重启才能生效！"
echo ""
echo "📌 下一步："
echo "1. 在 Windows 中重启 Docker Desktop："
echo "   - 右键点击系统托盘中的 Docker 图标"
echo "   - 选择 'Quit Docker Desktop'"
echo "   - 重新打开 Docker Desktop"
echo ""
echo "2. 重启后，测试代理是否生效："
echo "   docker pull gcr.io/kaggle-gpu-images/python:latest"
echo ""
echo "3. 查看当前配置："
echo "   cat $DOCKER_CONFIG_FILE"
echo ""

