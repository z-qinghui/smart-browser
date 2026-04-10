#!/bin/bash
# 查看服务状态

echo "=== smart-browser 服务状态 ==="
echo ""

echo "【进程状态】"
for proc in Xvnc xfwm4 xfce4-panel xfdesktop websockify chrome cdp-proxy socat nginx; do
  count=$(pgrep -c "$proc" 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    echo "✓ $proc: $count 个进程"
  else
    echo "✗ $proc: 未运行"
  fi
done

echo ""
echo "【端口状态】"
for port in 5900 5901 6080 9222 3456 3030; do
  if ss -tlnp 2>/dev/null | grep -q ":$port"; then
    echo "✓ 端口 $port: 监听中"
  else
    echo "✗ 端口 $port: 未监听"
  fi
done

echo ""
echo "【VNC 访问】"
echo "http://localhost:6080/vnc.html"
echo "密码：admin2026"
