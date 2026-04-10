#!/bin/bash
# 环境检查脚本 - 检查 CDP 模式可用性

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
CHROME_HOST="${CHROME_HOST:-127.0.0.1}"
CHROME_PORT="${CHROME_PORT:-9222}"
CDP_PROXY_PORT="${CDP_PROXY_PORT:-3456}"

echo "=========================================="
echo "  OpenClaw 反爬虫浏览器环境检查"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# 检查 Node.js
check_nodejs() {
    echo -n "检查 Node.js: "

    if ! command -v node &>/dev/null; then
        echo -e "${RED}✗ 未安装${NC}"
        echo "  请安装 Node.js 22+"
        ((FAIL_COUNT++))
        return 1
    fi

    VERSION=$(node -v)
    MAJOR=$(echo "$VERSION" | cut -d. -f1 | tr -d 'v')

    if [ "$MAJOR" -ge 22 ]; then
        echo -e "${GREEN}✓ $VERSION${NC}"
        ((PASS_COUNT++))
    else
        echo -e "${YELLOW}⚠ $VERSION（建议升级到 22+）${NC}"
        ((PASS_COUNT++))
    fi
}

# 检查 Chrome 远程调试端口
check_chrome() {
    echo -n "检查 Chrome ($CHROME_HOST:$CHROME_PORT): "

    if curl -s "http://$CHROME_HOST:$CHROME_PORT/json/version" &>/dev/null; then
        INFO=$(curl -s "http://$CHROME_HOST:$CHROME_PORT/json/version")
        BROWSER=$(echo "$INFO" | jq -r '.Browser' 2>/dev/null || echo "未知")
        echo -e "${GREEN}✓ $BROWSER${NC}"
        ((PASS_COUNT++))
    else
        echo -e "${RED}✗ 无法连接${NC}"
        echo ""
        echo "  解决方案："
        echo "  1. 容器内模式：运行以下命令启动 Chrome"
        echo "     bash scripts/start-chrome.sh"
        echo ""
        echo "  2. 宿主机模式：运行以下命令启动 Chrome"
        echo "     chromium --headless=new --remote-debugging-port=$CHROME_PORT --no-sandbox &"
        echo ""
        ((FAIL_COUNT++))
        return 1
    fi
}

# 检查 CDP Proxy
check_cdp_proxy() {
    echo -n "检查 CDP Proxy (端口 $CDP_PROXY_PORT): "

    if curl -s "http://127.0.0.1:$CDP_PROXY_PORT/health" &>/dev/null; then
        INFO=$(curl -s "http://127.0.0.1:$CDP_PROXY_PORT/health")
        CONNECTED=$(echo "$INFO" | jq -r '.connected' 2>/dev/null || echo "false")
        if [ "$CONNECTED" = "true" ]; then
            echo -e "${GREEN}✓ 已连接 Chrome${NC}"
            ((PASS_COUNT++))
        else
            echo -e "${YELLOW}⚠ 未连接 Chrome${NC}"
            ((PASS_COUNT++))
        fi
    else
        echo -e "${RED}✗ 未运行${NC}"
        echo ""
        echo "  解决方案：运行以下命令启动 CDP Proxy"
        echo "  CDP_CHROME_HOST=$CHROME_HOST CDP_CHROME_PORT=$CHROME_PORT \\"
        echo "    node scripts/cdp-proxy.mjs &"
        echo ""
        ((FAIL_COUNT++))
        return 1
    fi
}

# 检查中文字体
check_fonts() {
    echo -n "检查中文字体: "

    if fc-list :lang=zh &>/dev/null; then
        echo -e "${GREEN}✓ 已安装${NC}"
        ((PASS_COUNT++))
    else
        echo -e "${YELLOW}⚠ 未安装（中文页面可能乱码）${NC}"
        echo "  安装命令：apt-get install fonts-noto fonts-wqy-zenhei"
        ((PASS_COUNT++))
    fi
}

# 检查共享内存
check_shm() {
    echo -n "检查共享内存: "

    if [ -d "/dev/shm" ]; then
        SIZE=$(df -h /dev/shm 2>/dev/null | tail -1 | awk '{print $4}')
        if [ -n "$SIZE" ]; then
            echo -e "${GREEN}✓ 可用 $SIZE${NC}"
            ((PASS_COUNT++))
        else
            echo -e "${YELLOW}⚠ 无法获取大小${NC}"
            ((PASS_COUNT++))
        fi
    else
        echo -e "${YELLOW}⚠ /dev/shm 不存在${NC}"
        ((PASS_COUNT++))
    fi
}

# 检查 Skill 文件
check_skill_files() {
    echo -n "检查 Skill 文件: "

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$(dirname "$SCRIPT_DIR")"

    if [ -f "$BASE_DIR/SKILL.md" ]; then
        echo -e "${GREEN}✓ 完整${NC}"
        ((PASS_COUNT++))
    else
        echo -e "${RED}✗ 缺少 SKILL.md${NC}"
        ((FAIL_COUNT++))
        return 1
    fi

    if [ -d "$BASE_DIR/site-patterns" ]; then
        PLATFORM_COUNT=$(ls -1 "$BASE_DIR/site-patterns"/*.md 2>/dev/null | wc -l)
        if [ "$PLATFORM_COUNT" -gt 0 ]; then
            echo -e "${GREEN}  ($PLATFORM_COUNT 个平台经验)${NC}"
        else
            echo -e "${YELLOW}  (无平台经验文件)${NC}"
        fi
    fi
}

# 测试 CDP 连接
test_cdp_connection() {
    echo ""
    echo "测试 CDP 连接..."

    # 列出可用 targets
    TARGETS=$(curl -s "http://127.0.0.1:$CDP_PROXY_PORT/targets" 2>/dev/null || echo "")

    if [ -n "$TARGETS" ] && [ "$TARGETS" != "[]" ]; then
        COUNT=$(echo "$TARGETS" | jq 'length' 2>/dev/null || echo "0")
        echo -e "${GREEN}✓ 发现 $COUNT 个页面${NC}"
    else
        echo -e "${YELLOW}⚠ 当前没有打开的页面${NC}"
        echo "  使用 /new 端点创建新页面:"
        echo "  curl -s 'http://localhost:$CDP_PROXY_PORT/new?url=https://example.com'"
    fi
}

# 打印总结
print_summary() {
    echo ""
    echo "=========================================="
    echo "  检查总结"
    echo "=========================================="
    echo ""
    echo -e "通过：${GREEN}$PASS_COUNT${NC} | 失败：${RED}$FAIL_COUNT${NC}"
    echo ""

    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓ 环境检查通过，可以开始使用${NC}"
        echo ""
        echo "快速测试："
        echo "  curl -s 'http://localhost:$CDP_PROXY_PORT/new?url=https://mp.weixin.qq.com'"
    else
        echo -e "${RED}✗ 存在未解决的问题，请先修复${NC}"
        echo ""
        echo "参考文档：SKILL.md 中的故障排查章节"
    fi
    echo ""
}

# 主流程
main() {
    check_nodejs
    check_chrome
    check_cdp_proxy
    check_fonts
    check_shm
    check_skill_files
    test_cdp_connection
    print_summary
}

main "$@"
