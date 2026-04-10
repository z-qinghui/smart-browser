# 独立模式部署指南

适用于 Claude Code 用户，在宿主机直接部署。

## 前置要求

- Ubuntu 22.04+ 或 Debian 11+
- Node.js 22+
- 2GB+ 可用内存
- root 权限

## 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/z-qinghui/smart-browser.git ~/.claude/skills/smart-browser
cd ~/.claude/skills/smart-browser

# 2. 运行安装脚本
sudo ./scripts/install.sh

# 3. 验证安装
./scripts/check-deps.sh
```

## 访问方式

- **VNC**: http://localhost:6080/vnc.html
- **密码**: `admin2026`
- **CDP Proxy**: http://localhost:3456

## 常用操作

```bash
# 查看服务状态
./scripts/status.sh

# 重启 VNC 服务
./scripts/stop-vnc.sh
./scripts/start-vnc.sh

# 检查依赖
./scripts/check-deps.sh
```

## 故障排查

### VNC 无法访问

```bash
# 检查端口是否监听
ss -tlnp | grep 6080

# 检查 nginx 状态
systemctl status nginx

# 重启服务
./scripts/stop-vnc.sh
./scripts/start-vnc.sh
```

### CDP Proxy 连接失败

```bash
# 检查 Chrome 是否运行
curl http://localhost:9222/json/version

# 重启 CDP Proxy
pkill -f cdp-proxy.mjs
node scripts/cdp-proxy.mjs &
```
