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

# 2. 下载 vendor 依赖（推荐，提升安装速度）
./scripts/download-vendor.sh

# 3. 运行安装脚本
sudo ./scripts/install.sh

# 4. 验证安装
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

## vendor 依赖说明

项目使用 vendor 目录存储离线依赖包，包含：

- `chrome-installers/google-chrome-stable.deb` - Chrome 安装包 (~120MB)
- `noVNC/` - noVNC 源码

**不提交到 Git**：大型二进制文件（.deb）通过 `.gitignore` 排除

**下载依赖**：
```bash
./scripts/download-vendor.sh
```

**国内镜像**：脚本自动检测网络环境，使用清华镜像/Gitee 加速下载

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

### vendor 下载失败

```bash
# 手动下载 Chrome
wget https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_146.0.7680.177-1_amd64.deb \
  -O vendor/chrome-installers/google-chrome-stable.deb

# 手动克隆 noVNC
git clone --depth 1 https://github.com/novnc/noVNC.git vendor/noVNC
```
