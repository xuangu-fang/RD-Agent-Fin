#!/bin/bash
# 快速测试 Windows 代理连接

echo "=========================================="
echo "Windows 代理连接测试（WSL）"
echo "=========================================="
echo ""

# 获取 Windows 主机 IP
WINDOWS_IP=$(ip route show | grep -i default | awk '{ print $3}' | head -1)

if [ -z "$WINDOWS_IP" ]; then
    echo "❌ 无法检测 Windows 主机 IP"
    exit 1
fi

echo "✅ 检测到 Windows 主机 IP: $WINDOWS_IP"
echo ""

# 常见代理端口
PORTS=(7890 7891 10809 10808 1080 8080 8888)
FOUND_PROXY=false

echo "🔍 扫描常见代理端口..."
for port in "${PORTS[@]}"; do
    echo -n "  测试端口 $port... "
    if timeout 2 curl -s --proxy "http://$WINDOWS_IP:$port" "https://www.google.com" > /dev/null 2>&1; then
        echo "✅ 可用！"
        echo ""
        echo "=========================================="
        echo "✅ 找到可用的代理！"
        echo "=========================================="
        echo ""
        echo "代理地址: http://$WINDOWS_IP:$port"
        echo ""
        echo "📌 下一步："
        echo "运行以下命令配置 Docker："
        echo ""
        echo "  sudo bash scripts/setup_wsl_proxy.sh"
        echo ""
        echo "或者在配置时输入端口: $port"
        echo ""
        FOUND_PROXY=true
        break
    else
        echo "❌"
    fi
done

if [ "$FOUND_PROXY" = false ]; then
    echo ""
    echo "=========================================="
    echo "⚠️  未找到可用的代理"
    echo "=========================================="
    echo ""
    echo "可能的原因："
    echo "1. Windows 代理服务未运行"
    echo "2. 代理端口不在常见端口列表中"
    echo "3. 代理未启用'允许局域网连接'"
    echo "4. Windows 防火墙阻止了连接"
    echo ""
    echo "💡 解决方案："
    echo "1. 确认 Windows 代理正在运行"
    echo "2. 查看代理客户端显示的端口号"
    echo "3. 在代理客户端中启用'允许局域网连接'"
    echo "4. 手动测试："
    echo "   curl --proxy http://$WINDOWS_IP:YOUR_PORT https://www.google.com"
    echo ""
fi

