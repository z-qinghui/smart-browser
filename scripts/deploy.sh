#!/bin/bash
set -e

echo "=========================================="
echo "  OpenClaw 反爬虫浏览器自动化部署脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 jq 依赖
check_jq() {
    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}⚠ jq 未安装，部分功能可能受限${NC}"
        echo "  安装命令：apt-get install jq"
        if [ "$OPENCLAW_MODE" = "host" ] && command -v apt-get &>/dev/null; then
            echo "  正在自动安装 jq..."
            apt-get install -y jq 2>/dev/null || echo -e "${YELLOW}⚠ jq 安装失败${NC}"
        fi
    fi
}

# 检查是否在 OpenClaw 容器内
check_openclaw_env() {
    if [ -d "/home/node/.openclaw" ]; then
        echo -e "${GREEN}✓ 检测到 OpenClaw 环境${NC}"
        OPENCLAW_MODE="container"
    else
        echo -e "${YELLOW}⚠ 当前不在 OpenClaw 容器内，将部署到宿主机${NC}"
        OPENCLAW_MODE="host"
    fi
}

# 检查 Docker
check_docker() {
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}✓ Docker 已安装：$(docker --version)${NC}"
    else
        echo -e "${RED}✗ Docker 未安装${NC}"
        echo "  请先安装 Docker："
        echo "  curl -fsSL https://get.docker.com | sh"
        exit 1
    fi

    if command -v docker-compose &>/dev/null || docker compose version &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker Compose 已安装${NC}"
    else
        echo -e "${YELLOW}⚠ Docker Compose 未安装，将使用 docker run 方式${NC}"
    fi
}

# 安装系统依赖（仅宿主机模式）
install_dependencies() {
    if [ "$OPENCLAW_MODE" = "host" ]; then
        echo ""
        echo "正在安装系统依赖..."

        if command -v apt-get &>/dev/null; then
            apt-get update
            apt-get install -y \
                chromium \
                fonts-noto \
                fonts-wqy-zenhei \
                fonts-wqy-microhei \
                curl \
                jq || {
                    echo -e "${YELLOW}⚠ 部分依赖安装失败，继续执行...${NC}"
                }
        elif command -v yum &>/dev/null; then
            yum install -y \
                chromium \
                google-noto-fonts \
                curl \
                jq || {
                    echo -e "${YELLOW}⚠ 部分依赖安装失败，继续执行...${NC}"
                }
        else
            echo -e "${YELLOW}⚠ 未知的包管理器，请手动安装依赖${NC}"
        fi
    fi
}

# 创建目录结构
create_directories() {
    echo ""
    echo "创建目录结构..."

    if [ "$OPENCLAW_MODE" = "container" ]; then
        BASE_DIR="/home/node/.openclaw"
    else
        BASE_DIR="$HOME/.openclaw"
    fi

    mkdir -p "$BASE_DIR/data"
    mkdir -p "$BASE_DIR/chrome-data"
    mkdir -p "$BASE_DIR/workspace/skills"

    # 复制 Skill 到目标位置
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TARGET_DIR="$BASE_DIR/workspace/skills/openclaw-anti-bot"

    if [ "$SCRIPT_DIR" != "$TARGET_DIR" ]; then
        echo "复制 Skill 到 $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
        cp -r "$SCRIPT_DIR/"* "$TARGET_DIR/"
    fi

    echo -e "${GREEN}✓ 目录结构已创建${NC}"
}

# 生成 docker-compose.yml（仅宿主机模式）
generate_docker_compose() {
    if [ "$OPENCLAW_MODE" = "host" ]; then
        echo ""
        echo "生成 docker-compose.yml..."

        BASE_DIR="$HOME/.openclaw"

        cat > "$BASE_DIR/docker-compose.yml" <<'EOF'
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw
    restart: always
    network_mode: host
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    volumes:
      - ./data:/home/node/.openclaw
      - ./chrome-data:/home/node/.chrome-data
      - ./workspace/skills/openclaw-anti-bot:/opt/skills/anti-bot:ro
    environment:
      - TZ=Asia/Shanghai
      - CDP_CHROME_HOST=127.0.0.1
      - CDP_CHROME_PORT=9222
    shm_size: 2gb
    command: >
      bash -c "
        chromium --headless=new --remote-debugging-port=9222 --no-sandbox --disable-dev-shm-usage --user-data-dir=/home/node/.chrome-data &
        sleep 5 &&
        openclaw gateway start
      "
EOF
        echo -e "${GREEN}✓ docker-compose.yml 已生成${NC}"
    fi
}

# 生成 .env 文件
generate_env() {
    BASE_DIR="${BASE_DIR:-$HOME/.openclaw}"

    if [ ! -f "$BASE_DIR/.env" ]; then
        echo ""
        echo "生成 .env 配置文件..."

        cat > "$BASE_DIR/.env" <<EOF
# OpenClaw 配置
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || echo "change-me-$(date +%s)")

# 飞书配置（可选）
FEISHU_APP_ID=
FEISHU_APP_SECRET=

# CDP 配置
CDP_CHROME_HOST=127.0.0.1
CDP_CHROME_PORT=9222
CDP_PROXY_PORT=3456
EOF
        echo -e "${GREEN}✓ .env 已生成${NC}"
    else
        echo -e "${YELLOW}⚠ .env 已存在，跳过生成${NC}"
    fi
}

# 启动 Chrome（容器内模式）
start_chrome_container() {
    if [ "$OPENCLAW_MODE" = "container" ]; then
        echo ""
        echo "启动 Chrome（无头模式）..."

        CHROME_PATH="/home/node/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome"
        CHROME_DATA="/home/node/.chrome-data"

        mkdir -p "$CHROME_DATA"

        # 检查是否已有运行实例
        if curl -s http://127.0.0.1:9222/json/version &>/dev/null; then
            echo -e "${GREEN}✓ Chrome 已在运行${NC}"
        else
            if [ -f "$CHROME_PATH" ]; then
                "$CHROME_PATH" \
                    --headless=new \
                    --remote-debugging-port=9222 \
                    --remote-debugging-address=0.0.0.0 \
                    --no-sandbox \
                    --disable-dev-shm-usage \
                    --user-data-dir="$CHROME_DATA" \
                    --disable-gpu &>/dev/null &

                sleep 3

                if curl -s http://127.0.0.1:9222/json/version &>/dev/null; then
                    echo -e "${GREEN}✓ Chrome 启动成功${NC}"
                else
                    echo -e "${YELLOW}⚠ Chrome 启动可能失败，请检查日志${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ 未找到 Chrome 二进制文件，跳过启动${NC}"
                echo "  请确保 OpenClaw 镜像已安装 Playwright Chrome"
            fi
        fi
    fi
}

# 启动 CDP Proxy
start_cdp_proxy() {
    echo ""
    echo "启动 CDP Proxy..."

    PROXY_SCRIPT="$BASE_DIR/workspace/skills/openclaw-anti-bot/scripts/cdp-proxy.mjs"

    if [ -f "$PROXY_SCRIPT" ]; then
        # 检查是否已有运行实例
        if curl -s http://127.0.0.1:3456/health &>/dev/null; then
            echo -e "${GREEN}✓ CDP Proxy 已在运行${NC}"
        else
            CDP_CHROME_HOST=127.0.0.1 CDP_CHROME_PORT=9222 \
                node "$PROXY_SCRIPT" &>/dev/null &

            sleep 2

            if curl -s http://127.0.0.1:3456/health &>/dev/null; then
                echo -e "${GREEN}✓ CDP Proxy 启动成功${NC}"
            else
                echo -e "${YELLOW}⚠ CDP Proxy 启动可能失败，请检查日志${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ CDP Proxy 脚本不存在，跳过启动${NC}"
    fi
}

# 验证安装
verify_installation() {
    echo ""
    echo "=========================================="
    echo "  验证安装"
    echo "=========================================="
    echo ""

    # 检查 Chrome
    echo -n "检查 Chrome: "
    if curl -s http://127.0.0.1:9222/json/version &>/dev/null; then
        VERSION=$(curl -s http://127.0.0.1:9222/json/version | jq -r '.Browser' 2>/dev/null || echo "未知")
        echo -e "${GREEN}✓ $VERSION${NC}"
    else
        echo -e "${RED}✗ 未运行或无法访问${NC}"
    fi

    # 检查 CDP Proxy
    echo -n "检查 CDP Proxy: "
    if curl -s http://127.0.0.1:3456/health &>/dev/null; then
        STATUS=$(curl -s http://127.0.0.1:3456/health | jq -r '.status' 2>/dev/null || echo "未知")
        echo -e "${GREEN}✓ $STATUS${NC}"
    else
        echo -e "${RED}✗ 未运行或无法访问${NC}"
    fi

    # 检查 Skill 文件
    echo -n "检查 Skill 文件: "
    if [ -f "$BASE_DIR/workspace/skills/openclaw-anti-bot/SKILL.md" ]; then
        echo -e "${GREEN}✓ 已安装${NC}"
    else
        echo -e "${RED}✗ 未找到${NC}"
    fi
}

# 打印使用说明
print_usage() {
    echo ""
    echo "=========================================="
    echo "  部署完成！"
    echo "=========================================="
    echo ""
    echo "下一步操作："
    echo ""
    echo "1. 首次使用需要登录微信/小红书"
    echo "   - 在浏览器打开 http://<宿主机 IP>:9222"
    echo "   - 访问公众号文章链接并扫码登录"
    echo ""
    echo "2. 测试访问公众号文章"
    echo "   curl -s 'http://localhost:3456/new?url=ARTICLE_URL'"
    echo ""
    echo "3. 读取平台使用指南"
    echo "   cat $BASE_DIR/workspace/skills/openclaw-anti-bot/site-patterns/weixin.md"
    echo ""
    echo "4. 查看完整文档"
    echo "   cat $BASE_DIR/workspace/skills/openclaw-anti-bot/SKILL.md"
    echo ""
}

# 主流程
main() {
    check_jq
    check_openclaw_env
    check_docker
    install_dependencies
    create_directories
    generate_docker_compose
    generate_env
    start_chrome_container
    start_cdp_proxy
    verify_installation
    print_usage
}

main "$@"
