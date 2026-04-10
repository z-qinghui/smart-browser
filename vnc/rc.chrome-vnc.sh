#!/bin/bash
set -e

export HOME=/root
export USER=root

echo "=== 启动 VNC 服务 (TigerVNC Xvnc - 支持 UTF-8 剪切板) ==="

pkill -9 Xvnc 2>/dev/null || true
pkill -9 Xvfb 2>/dev/null || true
pkill -9 x11vnc 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 chrome 2>/dev/null || true
pkill -9 socat 2>/dev/null || true
pkill -9 xfce4-panel 2>/dev/null || true
pkill -9 xfce4-session 2>/dev/null || true
pkill -9 openbox 2>/dev/null || true
pkill -9 xfdesktop 2>/dev/null || true
pkill -9 xfwm4 2>/dev/null || true
pkill -9 fcitx5 2>/dev/null || true
pkill -9 fcitx-tray 2>/dev/null || true

sleep 2

# 清理残留端口占用
fuser -k 5900/tcp 2>/dev/null || true
fuser -k 5901/tcp 2>/dev/null || true
fuser -k 6080/tcp 2>/dev/null || true

# 创建 noVNC 软链接（websockify 需要）
ln -sf /usr/share/novnc /tmp/noVNC-master

# 启动 Xvnc (TigerVNC - 支持 UTF-8 剪切板)
# :1 显示监听端口 5901
# 注意：启用 RENDER 和 COMPOSITE 扩展以支持 xfwm4 合成器
Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None \
    +extension GLX \
    +extension RENDER \
    +extension COMPOSITE \
    -noreset \
    -SendPrimary 1 \
    -SetPrimary 1 \
    -SendCutText 1 \
    -AcceptCutText 1 &
sleep 3

# 将 5900 端口转发到 5901（兼容原有配置）
socat TCP-LISTEN:5900,fork TCP:localhost:5901 &
sleep 1

export DISPLAY=:1
# 中文语言环境
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US
export LC_ALL=zh_CN.UTF-8
# fcitx5 输入法
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx5

# 禁用 MIT-SHM 扩展（防止 xfce4-panel 崩溃）
export GDK_X11_DISABLE_MITSHM=1
export MITSHM=0

# TigerVNC Xvnc 自带 UTF-8 剪切板支持，无需 vncconfig

# 启动 fcitx5 输入法（使用系统 dbus 会话）
rm -f /tmp/fcitx5.log
sleep 5  # 等待 dbus 会话完全启动
fcitx5 -d > /tmp/fcitx5.log 2>&1 &
sleep 3

google-chrome-stable \
    --remote-debugging-port=9222 \
    --remote-debugging-address=0.0.0.0 \
    --no-sandbox \
    --disable-dev-shm-usage \
    --user-data-dir=/var/chrome-data/vnc-chrome \
    --disable-gpu \
    --disable-blink-features=AutomationControlled \
    --disable-features=KeyboardShortcutLockScreen \
    --disable-accelerated-shortcuts \
    > /tmp/chrome-desktop.log 2>&1 &

sleep 8

# 启动 websockify (noVNC WebSocket 代理)
# 安全修复：仅监听 localhost，通过 nginx 反向代理访问
websockify --web /tmp/noVNC-master 127.0.0.1:6080 localhost:5900 > /tmp/websockify.log 2>&1 &
sleep 2

# 安全修复：socat 仅监听 localhost，防止远程访问 CDP
socat TCP-LISTEN:9223,bind=127.0.0.1,fork TCP:127.0.0.1:9222 > /tmp/socat.log 2>&1 &
sleep 2

# 设置桌面环境变量
export XDG_RUNTIME_DIR=/run/user/0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus

# 启动 xfwm4 窗口管理器（XFCE 的窗口管理器 - 必须在 xfdesktop 之前）
xfwm4 --replace --display :1 > /tmp/xfwm4.log 2>&1 &
sleep 2

# 启动 Thunar 文件管理器（必须在 xfdesktop 之前启动，用于处理.desktop 文件执行）
thunar --daemon --display :1 > /tmp/thunar.log 2>&1 &
sleep 3

# 启动 xfdesktop（桌面背景和图标 - 需要 Thunar 已注册到 dbus）
xfdesktop --display :1 > /tmp/xfdesktop.log 2>&1 &
sleep 2

# 启动 XFCE 面板（底部工具栏）
xfce4-panel --display :1 > /tmp/xfce4-panel.log 2>&1 &
sleep 3

# 启动 fcitx5 输入法托盘
python3 /usr/local/bin/fcitx-tray.py :1 > /tmp/fcitx-tray.log 2>&1 &
sleep 2

sleep 1

# [已禁用] 在 Xorg :0 (阿里云 VNC) 上启动 Chrome 实例
# 用户确认不需要 alivnc-chrome，已禁用以节省内存 (~150MB)
# export XAUTHORITY=/var/run/lightdm/root/:0
# export DISPLAY=:0
# google-chrome-stable \
#     --remote-debugging-port=9224 \
#     --remote-debugging-address=0.0.0.0 \
#     --no-sandbox \
#     --disable-dev-shm-usage \
#     --user-data-dir=/var/chrome-data/alivnc-chrome \
#     --disable-gpu \
#     --disable-blink-features=AutomationControlled \
#     > /tmp/chrome-alivnc.log 2>&1 &
# sleep 3

echo "=== 服务启动完成 ==="
pgrep -a Xvnc | head -1
pgrep -a xfwm4 | head -1
pgrep -a xfce4-panel | head -1
pgrep -a websockify | head -1
pgrep -a chrome | head -1
