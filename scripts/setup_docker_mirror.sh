#!/bin/bash
# Docker 镜像加速配置脚本
# 用于解决在中国访问 gcr.io 等镜像源缓慢的问题

set -e

echo "=========================================="
echo "Docker 镜像加速配置脚本"
echo "=========================================="
echo ""

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 方案 1: 配置 Docker 镜像加速器
echo "📦 配置 Docker 镜像加速器..."
mkdir -p /etc/docker

# 检查是否已有配置文件
if [ -f /etc/docker/daemon.json ]; then
    echo "⚠️  检测到已存在的 /etc/docker/daemon.json，将备份为 daemon.json.bak"
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

# 创建或更新配置文件
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

echo "✅ Docker 镜像加速器配置完成"
echo ""

# 重启 Docker 服务
echo "🔄 重启 Docker 服务..."
systemctl daemon-reload
systemctl restart docker

echo "✅ Docker 服务已重启"
echo ""

# 验证配置
echo "🔍 验证配置..."
docker info | grep -A 10 "Registry Mirrors" || echo "⚠️  无法验证镜像加速器配置（可能需要重启 Docker）"
echo ""

echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "⚠️  重要提示："
echo "1. Docker 镜像加速器主要加速 Docker Hub 的镜像"
echo "2. 对于 gcr.io 等第三方镜像仓库，建议使用代理或 VPN"
echo "3. 如果仍然无法访问 gcr.io，可以考虑："
echo "   - 使用代理：配置 Docker 的 HTTP_PROXY 环境变量"
echo "   - 使用 VPN：确保系统级别的 VPN 连接正常"
echo "   - 手动拉取：在其他机器上拉取镜像后导入"
echo ""
echo "下一步："
echo "尝试运行以下命令来测试镜像拉取："
echo "  docker pull gcr.io/kaggle-gpu-images/python:latest"
echo "或者直接运行 RD-Agent："
echo "  rdagent data_science --competition arf-12-hours-prediction-task"
echo ""

