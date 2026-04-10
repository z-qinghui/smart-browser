# 容器模式部署指南

适用于 OpenClaw 容器用户。

## 架构说明

- VNC 服务运行在宿主机
- CDP Proxy 运行在容器内
- 容器通过 `network_mode: host` 访问宿主机 Chrome

## 使用方式

```bash
# 在 OpenClaw 容器内
skill smart-browser
```

## 环境检测

```bash
# 检查宿主机 Chrome 是否可访问
curl http://127.0.0.1:9222/json/version

# 检查 CDP Proxy 是否运行
curl http://localhost:3456/health
```

## 访问方式

- **VNC**: 宿主机 IP:6080/vnc.html
- **密码**: `admin2026`
- **CDP Proxy**: localhost:3456（容器内访问）

## 启动 CDP Proxy

```bash
# 如果 CDP Proxy 未运行
CDP_CHROME_HOST=127.0.0.1 CDP_CHROME_PORT=9222 \
  node ~/.claude/skills/smart-browser/scripts/cdp-proxy.mjs &
```

## 使用示例

```bash
# 抓取微信公众号文章
TARGET=$(curl -s "http://localhost:3456/new?url=https://mp.weixin.qq.com/s/xxx" | jq -r '.targetId')
curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d "document.querySelector('#js_content').innerText"
curl -s "http://localhost:3456/close?target=$TARGET"
```
