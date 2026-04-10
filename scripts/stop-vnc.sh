#!/bin/bash
# 停止 VNC 服务

set -e

echo "正在停止 VNC 服务..."

pkill -9 Xvnc 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 socat 2>/dev/null || true

echo "VNC 服务已停止"
