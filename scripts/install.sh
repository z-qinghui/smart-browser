#!/bin/bash
# smart-browser 一键安装脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  smart-browser 一键安装"
echo "=========================================="

# 检测环境
if [ -d "/home/node/.openclaw" ]; then
    MODE="container"
    echo -e "${YELLOW}检测到 OpenClaw 容器环境${NC}"
    echo "VNC 服务应在宿主机运行，容器内仅需 CDP Proxy"
elif command -v docker &>/dev/null; then
    MODE="docker"
    echo -e "${GREEN}检测到 Docker 环境${NC}"
else
    MODE="standalone"
    echo -e "${GREEN}检测到宿主机环境，使用独立模式${NC}"
fi

case "$MODE" in
  standalone)
    echo ""
    echo "正在安装系统依赖..."

    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y \
            tigervnc-standalone-server \
            websockify \
            nginx \
            chromium-browser \
            fonts-noto \
            fonts-wqy-zenhei \
            fonts-wqy-microhei \
            nodejs \
            npm \
            jq \
            xfce4 \
            xfce4-goodies \
            fcitx5 \
            fcitx5-pinyin \
            socat || {
            echo -e "${YELLOW}部分依赖安装失败，继续执行...${NC}"
        }
    else
        echo -e "${YELLOW}未知的包管理器，请手动安装依赖${NC}"
        exit 1
    fi

    echo ""
    echo "正在启动 VNC 服务..."
    bash vnc/rc.chrome-vnc.sh

    echo ""
    echo "正在启动 CDP Proxy..."
    CDP_CHROME_HOST=127.0.0.1 CDP_CHROME_PORT=9222 \
        node scripts/cdp-proxy.mjs &

    echo ""
    echo "=========================================="
    echo "  安装完成！"
    echo "=========================================="
    echo ""
    echo "VNC 访问：http://localhost:6080/vnc.html"
    echo "默认密码：admin2026"
    echo "CDP Proxy: http://localhost:3456"
    ;;

  docker)
    echo ""
    echo "使用 Docker Compose 启动服务..."
    echo "运行：docker-compose up -d"
    ;;

  container)
    echo ""
    echo "OpenClaw 环境中，请确保宿主机 VNC 服务已运行"
    echo "CDP Proxy 将自动连接宿主机 Chrome:9222"
    ;;
esac

echo ""
echo "运行 ./scripts/check-deps.sh 验证安装"
