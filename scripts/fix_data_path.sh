#!/bin/bash
# 数据目录检查和修复脚本

set -e

echo "=========================================="
echo "RD-Agent 数据目录检查和修复"
echo "=========================================="
echo ""

PROJECT_ROOT="/home/fsk/fang/RD-Agent"
cd "$PROJECT_ROOT"

# 1. 检查环境变量配置
echo "1️⃣ 检查环境变量配置..."
DS_LOCAL_DATA_PATH=$(dotenv get DS_LOCAL_DATA_PATH 2>/dev/null || echo "")
if [ -z "$DS_LOCAL_DATA_PATH" ]; then
    echo "⚠️  DS_LOCAL_DATA_PATH 未设置"
    echo "   正在设置..."
    dotenv set DS_LOCAL_DATA_PATH "$(pwd)/git_ignore_folder/ds_data"
    DS_LOCAL_DATA_PATH="$(pwd)/git_ignore_folder/ds_data"
    echo "✅ 已设置为: $DS_LOCAL_DATA_PATH"
else
    echo "✅ DS_LOCAL_DATA_PATH: $DS_LOCAL_DATA_PATH"
    # 检查是否是相对路径，如果是则转换为绝对路径
    if [[ "$DS_LOCAL_DATA_PATH" != /* ]]; then
        echo "⚠️  检测到相对路径，转换为绝对路径..."
        ABS_PATH="$(pwd)/$DS_LOCAL_DATA_PATH"
        dotenv set DS_LOCAL_DATA_PATH "$ABS_PATH"
        DS_LOCAL_DATA_PATH="$ABS_PATH"
        echo "✅ 已更新为: $DS_LOCAL_DATA_PATH"
    fi
fi
echo ""

# 2. 检查数据目录
echo "2️⃣ 检查数据目录..."
if [ ! -d "$DS_LOCAL_DATA_PATH" ]; then
    echo "⚠️  数据目录不存在: $DS_LOCAL_DATA_PATH"
    echo "   正在创建..."
    mkdir -p "$DS_LOCAL_DATA_PATH"
    echo "✅ 已创建"
else
    echo "✅ 数据目录存在: $DS_LOCAL_DATA_PATH"
fi
echo ""

# 3. 检查竞赛数据
COMPETITION="arf-12-hours-prediction-task"
echo "3️⃣ 检查竞赛数据: $COMPETITION"
COMPETITION_PATH="$DS_LOCAL_DATA_PATH/$COMPETITION"

if [ ! -d "$COMPETITION_PATH" ]; then
    echo "⚠️  竞赛目录不存在: $COMPETITION_PATH"
    
    # 检查是否有 zip 文件
    ZIP_FILE="$DS_LOCAL_DATA_PATH/${COMPETITION}.zip"
    if [ -f "$ZIP_FILE" ]; then
        echo "✅ 找到 zip 文件: $ZIP_FILE"
        echo "   正在解压..."
        unzip -q "$ZIP_FILE" -d "$DS_LOCAL_DATA_PATH"
        echo "✅ 解压完成"
    else
        echo "❌ 未找到 zip 文件: $ZIP_FILE"
        echo ""
        echo "📌 请手动下载数据："
        echo "   wget https://github.com/SunsetWolf/rdagent_resource/releases/download/ds_data/arf-12-hours-prediction-task.zip"
        echo "   unzip arf-12-hours-prediction-task.zip -d $DS_LOCAL_DATA_PATH"
        exit 1
    fi
else
    echo "✅ 竞赛目录存在: $COMPETITION_PATH"
fi
echo ""

# 4. 验证目录结构
echo "4️⃣ 验证目录结构..."
if [ -d "$COMPETITION_PATH" ]; then
    echo "   目录内容:"
    ls -la "$COMPETITION_PATH" | head -10
    echo ""
    
    # 检查必要文件
    REQUIRED_FILES=("description.md" "sample.py")
    MISSING_FILES=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$COMPETITION_PATH/$file" ]; then
            MISSING_FILES+=("$file")
        fi
    done
    
    if [ ${#MISSING_FILES[@]} -eq 0 ]; then
        echo "✅ 必要文件都存在"
    else
        echo "⚠️  缺少文件: ${MISSING_FILES[*]}"
    fi
fi
echo ""

# 5. 测试 Python 环境变量加载
echo "5️⃣ 测试 Python 环境变量加载..."
TEST_RESULT=$(python3 <<EOF
import os
from pathlib import Path
from dotenv import load_dotenv

# 加载 .env 文件
load_dotenv(".env")

local_data_path = os.getenv("DS_LOCAL_DATA_PATH", "")
if local_data_path:
    expected = Path(local_data_path) / "arf-12-hours-prediction-task"
    exists = expected.exists()
    print(f"DS_LOCAL_DATA_PATH: {local_data_path}")
    print(f"Expected path: {expected}")
    print(f"Exists: {exists}")
    exit(0 if exists else 1)
else:
    print("DS_LOCAL_DATA_PATH 未设置")
    exit(1)
EOF
)

if [ $? -eq 0 ]; then
    echo "✅ Python 环境变量加载测试通过"
    echo "$TEST_RESULT"
else
    echo "❌ Python 环境变量加载测试失败"
    echo "$TEST_RESULT"
fi
echo ""

echo "=========================================="
echo "检查完成！"
echo "=========================================="
echo ""
echo "📌 下一步："
echo "   运行: rdagent data_science --competition arf-12-hours-prediction-task"
echo ""

