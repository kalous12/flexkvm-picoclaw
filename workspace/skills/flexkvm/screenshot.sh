#!/bin/bash
# flexkvm-screenshot - 使用 FlexKVM 进行屏幕截图
# 保存路径：/root/.picoclaw/flexkvm/image

set -e

# 配置
FLEXKVM_CLI="/root/.picoclaw/flexkvm/bin/flexkvm_cli"
SAVE_DIR="/root/.picoclaw/flexkvm/image"

# 确保保存目录存在
mkdir -p "$SAVE_DIR"

# 生成文件名（固定为 screenshot.jpg，可覆盖）
FILENAME="screenshot.jpg"

# 完整路径
FULL_PATH="${SAVE_DIR}/${FILENAME}"

# 检查 flexkvm_cli 是否存在
if [ ! -f "$FLEXKVM_CLI" ]; then
    echo "错误：flexkvm_cli 未找到：$FLEXKVM_CLI"
    exit 1
fi

# 执行截图
echo "正在截图..."
"$FLEXKVM_CLI" video --snapshot "$FULL_PATH"

# 验证截图是否成功
if [ -f "$FULL_PATH" ]; then
    FILESIZE=$(ls -lh "$FULL_PATH" | awk '{print $5}')
    echo "截图成功！"
    echo "保存路径：$FULL_PATH"
    echo "文件大小：$FILESIZE"
    echo "$FULL_PATH"
else
    echo "截图失败"
    exit 1
fi
