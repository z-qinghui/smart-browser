# smart-browser

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue)](https://claude.ai/code)
[![OpenClaw Compatible](https://img.shields.io/badge/OpenClaw-Compatible-green)](https://github.com/openclaw/openclaw)

一站式智能浏览器自动化解决方案，支持反爬网站访问（微信公众号、小红书、知乎）和人机协作 VNC 通道。

## ✨ 特性

- 🌐 **三模式部署**: 独立模式 / 容器模式 / Docker 托管
- 🔐 **JWT 认证**: 登录密码验证，30 天免登录（默认密码：`admin2026`）
- 🤖 **反爬绕过**: 真实浏览器环境 + 用户行为模拟
- 👥 **人机协作**: 遇到验证码/登录墙时，用户可通过 VNC 手动干预
- 📚 **平台经验库**: 微信公众号、小红书、知乎访问指南

## 🚀 快速开始

### 模式 A：独立模式（推荐 Claude Code 用户）

```bash
git clone https://github.com/z-qinghui/smart-browser.git ~/.claude/skills/smart-browser
cd ~/.claude/skills/smart-browser
./scripts/install.sh
```

访问 VNC: `http://localhost:6080/vnc.html`  
默认密码：`admin2026`

### 模式 B：Docker 托管模式

```bash
git clone https://github.com/z-qinghui/smart-browser.git
cd smart-browser
docker-compose up -d
```

### 模式 C：OpenClaw 容器模式

已在 OpenClaw 镜像中预装，直接使用即可。

## 🛠️ 核心组件

| 组件 | 端口 | 用途 |
|------|------|------|
| Chrome CDP | 9222 | 浏览器调试接口 |
| CDP Proxy | 3456 | CDP 协议代理 |
| TigerVNC | 5901 | 虚拟显示 |
| websockify | 6080 | WebSocket 转发 |
| nginx | 443/8080 | HTTPS 反向代理 |
| auth-server | 3030 | JWT 认证服务 |

## 📦 部署模式对比

| 特性 | 独立模式 | 容器模式 | Docker 托管 |
|------|---------|---------|-----------|
| 目标环境 | Claude Code | OpenClaw 容器 | 任意主机 |
| Chrome 位置 | 宿主机 | 宿主机 | Docker 容器 |
| VNC 位置 | 宿主机 | 宿主机 | Docker 容器 |
| 安装难度 | ⭐ | ⭐⭐ | ⭐⭐⭐ |
| 适用场景 | 个人开发 | OpenClaw 用户 | 生产部署 |

## 🔧 API 示例

### 抓取微信公众号文章

```bash
# 1. 创建 tab
TARGET=$(curl -s "http://localhost:3456/new?url=ARTICLE_URL" | jq -r '.targetId')

# 2. 提取正文
curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d "document.querySelector('#js_content').innerText"

# 3. 关闭 tab
curl -s "http://localhost:3456/close?target=$TARGET"
```

### VNC 人工干预

当遇到验证码时：
1. 访问 `http://localhost:6080/vnc.html`
2. 输入密码 `admin2026` 登录 VNC 桌面
3. 手动处理验证码
4. 告知 AI 继续

## 📖 文档

- [系统架构](docs/SYSTEM_ARCHITECTURE.md)
- [部署指南](docs/deployment/)
  - [独立模式](docs/deployment/standalone.md)
  - [容器模式](docs/deployment/container.md)
  - [Docker 托管](docs/deployment/docker.md)
- [VNC 快速入门](docs/vnc/quickstart.md)
- [故障排查](docs/vnc/troubleshooting.md)
- [平台经验](site-patterns/)
  - [微信公众号](site-patterns/weixin.md)
  - [小红书](site-patterns/xiaohongshu.md)
  - [知乎](site-patterns/zhihu.md)

## 🔒 安全配置

- JWT Token + HttpOnly Cookie 认证
- 客户端密码哈希传输（SHA-256 + Salt）
- websockify 仅监听 localhost
- CDP 端口限制访问来源
- 密码默认值：`admin2026`（建议生产环境修改）

## 📝 License

MIT License
