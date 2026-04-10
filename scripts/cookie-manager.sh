#!/bin/bash
# Cookie 管理工具 - 导出/导入网站登录态

set -e

# 检查 jq 依赖
if ! command -v jq &>/dev/null; then
    echo "错误：jq 未安装"
    echo "安装命令：apt-get install jq"
    exit 1
fi

ACTION=$1
PROFILE=${2:-default}
CHROME_PORT="${CHROME_PORT:-9222}"
CDP_PROXY_PORT="${CDP_PROXY_PORT:-3456}"
COOKIE_DIR="${HOME}/.openclaw/cookies"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "用法：$0 <command> [profile]"
    echo ""
    echo "命令:"
    echo "  export [profile]  - 导出 Cookie 到文件"
    echo "  import [profile]  - 从文件导入 Cookie"
    echo "  list              - 列出已保存的 Cookie"
    echo "  delete [profile]  - 删除保存的 Cookie"
    echo ""
    echo "示例:"
    echo "  $0 export weixin      # 导出微信 Cookie"
    echo "  $0 import weixin      # 导入微信 Cookie"
    echo "  $0 list               # 列出所有保存的 Cookie"
    exit 1
}

# 创建 Cookie 目录
mkdir -p "$COOKIE_DIR"

case $ACTION in
    export)
        echo -e "${GREEN}导出 Cookie (Profile: $PROFILE)${NC}"

        # 获取所有 targets
        TARGETS=$(curl -s "http://127.0.0.1:$CDP_PROXY_PORT/targets" || echo "[]")

        if [ "$TARGETS" = "[]" ]; then
            echo -e "${YELLOW}⚠ 当前没有打开的页面${NC}"
            echo "请先访问目标网站，然后重试"
            exit 1
        fi

        # 获取第一个 page target
        TARGET_ID=$(echo "$TARGETS" | jq -r '.[0].targetId' 2>/dev/null)

        if [ -z "$TARGET_ID" ] || [ "$TARGET_ID" = "null" ]; then
            echo -e "${RED}✗ 无法获取目标页面${NC}"
            exit 1
        fi

        echo "目标 ID: $TARGET_ID"
        echo "正在获取 Cookie..."

        # 使用 CDP Runtime.evaluate 获取 Cookie
        curl -s -X POST "http://127.0.0.1:$CDP_PROXY_PORT/eval?target=$TARGET_ID" \
            -d "document.cookie" > "$COOKIE_DIR/$PROFILE.txt"

        if [ -s "$COOKIE_DIR/$PROFILE.txt" ]; then
            echo -e "${GREEN}✓ Cookie 已导出到：$COOKIE_DIR/$PROFILE.txt${NC}"
            echo ""
            echo "内容预览:"
            head -c 200 "$COOKIE_DIR/$PROFILE.txt"
            echo "..."
        else
            echo -e "${YELLOW}⚠ Cookie 为空，可能当前页面未登录${NC}"
        fi
        ;;

    import)
        echo -e "${GREEN}导入 Cookie (Profile: $PROFILE)${NC}"

        COOKIE_FILE="$COOKIE_DIR/$PROFILE.txt"

        if [ ! -f "$COOKIE_FILE" ]; then
            echo -e "${RED}✗ Cookie 文件不存在：$COOKIE_FILE${NC}"
            echo ""
            echo "已保存的 Cookie:"
            ls -1 "$COOKIE_DIR"/*.txt 2>/dev/null || echo "  (无)"
            exit 1
        fi

        # 创建新 tab 用于注入 Cookie
        echo "创建新页面..."
        RESULT=$(curl -s "http://127.0.0.1:$CDP_PROXY_PORT/new?url=about:blank")
        TARGET_ID=$(echo "$RESULT" | jq -r '.targetId' 2>/dev/null)

        if [ -z "$TARGET_ID" ] || [ "$TARGET_ID" = "null" ]; then
            echo -e "${RED}✗ 无法创建目标页面${NC}"
            exit 1
        fi

        # 解析并逐个设置 Cookie（正确方式）
        echo "注入 Cookie..."
        COOKIES=$(cat "$COOKIE_FILE")

        # 使用 JavaScript 逐个设置 cookie
        JS_INJECT=$(cat <<EOF
(() => {
  const cookies = "$COOKIES".split(';').map(c => c.trim()).filter(c => c);
  cookies.forEach(c => {
    const parts = c.split('=');
    if (parts.length >= 2) {
      const name = parts.shift();
      const value = parts.join('=');
      document.cookie = name + '=' + value + '; path=/';
    }
  });
  return { success: true, count: cookies.length };
})()
EOF
)
        curl -s -X POST "http://127.0.0.1:$CDP_PROXY_PORT/eval?target=$TARGET_ID" \
            -d "$JS_INJECT"

        echo -e "${GREEN}✓ Cookie 已导入${NC}"
        echo ""
        echo "提示：导入后需要刷新页面才能生效"
        # 刷新页面使 Cookie 生效
        curl -s "http://127.0.0.1:$CDP_PROXY_PORT/navigate?target=$TARGET_ID&url=about:blank" &>/dev/null
        ;;

    list)
        echo -e "${GREEN}已保存的 Cookie:${NC}"
        echo ""

        if [ -d "$COOKIE_DIR" ] && [ "$(ls -A "$COOKIE_DIR"/*.txt 2>/dev/null)" ]; then
            for file in "$COOKIE_DIR"/*.txt; do
                name=$(basename "$file" .txt)
                size=$(wc -c < "$file")
                echo "  - $name ($size bytes)"
            done
        else
            echo "  (无)"
        fi
        ;;

    delete)
        COOKIE_FILE="$COOKIE_DIR/$PROFILE.txt"

        if [ -f "$COOKIE_FILE" ]; then
            rm "$COOKIE_FILE"
            echo -e "${GREEN}✓ 已删除：$PROFILE${NC}"
        else
            echo -e "${YELLOW}⚠ Cookie 不存在：$PROFILE${NC}"
        fi
        ;;

    *)
        usage
        ;;
esac
