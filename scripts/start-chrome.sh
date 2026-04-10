#!/bin/bash
# Chrome 启动脚本（容器内模式）

set -e

CHROME_DATA="${CHROME_DATA:-/home/node/.chrome-data}"
CDP_PORT="${CDP_PORT:-9222}"

# 自动发现 Chrome 路径
find_chrome() {
    local paths=(
        "/home/node/.cache/ms-playwright/chromium-*/chrome-linux64/chrome"
        "/home/node/.cache/ms-playwright/chrome-*/chrome-linux64/chrome"
        "/usr/bin/chromium"
        "/usr/bin/chromium-browser"
        "/usr/bin/google-chrome"
        "/usr/bin/google-chrome-stable"
    )
    for pattern in "${paths[@]}"; do
        local result=$(ls $pattern 2>/dev/null | head -1)
        if [ -f "$result" ]; then
            echo "$result"
            return 0
        fi
    done
    return 1
}

CHROME_PATH=$(find_chrome) || {
    echo "✗ 未找到 Chrome 二进制文件"
    echo ""
    echo "可能原因："
    echo "1. 当前不在 OpenClaw 容器内"
    echo "2. Playwright Chrome 未安装"
    echo ""
    echo "解决方案："
    echo "- 在 OpenClaw 容器内运行此脚本"
    echo "- 或手动安装 Chromium: apt-get install chromium"
    exit 1
}

echo "正在启动 Chrome ($(basename "$CHROME_PATH"))..."

# 创建数据目录
mkdir -p "$CHROME_DATA"

# 检查是否已有运行实例
if curl -s "http://127.0.0.1:$CDP_PORT/json/version" &>/dev/null; then
    echo "✓ Chrome 已在运行"
    exit 0
fi

# 检查 Chrome 二进制文件
if [ ! -f "$CHROME_PATH" ]; then
    echo "✗ Chrome 二进制文件不存在：$CHROME_PATH"
    echo ""
    echo "可能原因："
    echo "1. 当前不在 OpenClaw 容器内"
    echo "2. Playwright Chrome 未安装"
    echo ""
    echo "解决方案："
    echo "- 在 OpenClaw 容器内运行此脚本"
    echo "- 或手动安装 Chromium: apt-get install chromium"
    exit 1
fi

# 清理残留进程
pkill -f "chrome-linux64/chrome" 2>/dev/null || true

# 清理 Singleton 锁文件
rm -f "$CHROME_DATA"/Singleton* 2>/dev/null || true

# 启动 Chrome
"$CHROME_PATH" \
    --headless=new \
    --remote-debugging-port="$CDP_PORT" \
    --remote-debugging-address=0.0.0.0 \
    --no-sandbox \
    --disable-dev-shm-usage \
    --user-data-dir="$CHROME_DATA" \
    --disable-gpu \
    --disable-software-rasterizer \
    &>/dev/null &

CHROME_PID=$!
echo "Chrome 进程 ID: $CHROME_PID"

# 等待启动
echo -n "等待 Chrome 启动..."
for i in {1..10}; do
    sleep 1
    if curl -s "http://127.0.0.1:$CDP_PORT/json/version" &>/dev/null; then
        echo "✓ 成功"
        echo ""
        echo "Chrome 已启动，监听端口 $CDP_PORT"
        echo "用户数据目录：$CHROME_DATA"
        echo ""
        echo "验证命令："
        echo "  curl -s http://127.0.0.1:$CDP_PORT/json/version"
        exit 0
    fi
    echo -n "."
done

echo "✗ 超时"
echo ""
echo "Chrome 可能启动失败，请检查："
echo "1. 日志：dmesg | tail"
echo "2. 进程：ps aux | grep chrome"
exit 1
