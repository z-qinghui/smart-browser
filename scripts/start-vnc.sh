#!/bin/bash
# 启动 VNC 服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "正在启动 VNC 服务..."
bash "$BASE_DIR/vnc/rc.chrome-vnc.sh"

echo "VNC 服务启动完成"
echo "访问地址：http://localhost:6080/vnc.html"
echo "默认密码：admin2026"
