# smart-browser

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue)](https://claude.ai/code)
[![OpenClaw Compatible](https://img.shields.io/badge/OpenClaw-Compatible-green)](https://github.com/openclaw/openclaw)

一站式智能浏览器自动化解决方案，支持反爬网站访问（微信公众号、小红书、知乎）和人机协作 VNC 通道。

---

## 🚀 新手安装指南

### 第一步：确认你的使用环境

请根据你的情况选择合适的安装模式：

| 你在使用什么？ | 选择模式 | 难度 |
|--------------|---------|------|
| **Claude Code**（AI 编程助手） | 模式一：独立模式 | ⭐ 简单 |
| **OpenClaw**（容器环境） | 模式二：容器模式 | ⭐⭐ 中等 |
| **想用 Docker 部署** | 模式三：Docker 托管 | ⭐⭐⭐ 较复杂 |

---

### 模式一：独立模式（推荐 Claude Code 用户）

**适用于**：在 Claude Code 中使用，希望 AI 帮你访问微信公众号、小红书、知乎等网站。

#### 步骤 1：打开终端

- **Windows 用户**：安装 [Git Bash](https://git-scm.com/download/win) 或 [WSL2](https://learn.microsoft.com/zh-cn/windows/wsl/install)
- **Mac 用户**：按 `Cmd+Space`，输入 `Terminal` 回车
- **Linux 用户**：按 `Ctrl+Alt+T` 打开终端

#### 步骤 2：复制粘贴以下命令（整段复制）

```bash
# 克隆项目
git clone https://github.com/z-qinghui/smart-browser.git ~/.claude/skills/smart-browser

# 进入项目目录
cd ~/.claude/skills/smart-browser

# 运行一键安装脚本
sudo ./scripts/install.sh
```

**操作说明**：
1. 复制上面 4 行命令
2. 在终端中粘贴（右键点击或按 `Ctrl+Shift+V`）
3. 按回车执行
4. 如提示输入密码，请输入你的电脑登录密码（输入时不会显示，输完回车即可）

#### 步骤 3：等待安装完成

安装过程大约需要 **3-5 分钟**，你会看到类似以下输出：

```
✓ 检测到本地 Chrome 安装包
✓ 检测到本地 noVNC
正在安装系统依赖...
✓ Chrome 安装包下载完成
✓ noVNC 下载完成
==========================================
  安装完成！
==========================================
VNC 访问：http://localhost:6080/vnc.html
默认密码：admin2026
CDP Proxy: http://localhost:3456
```

#### 步骤 4：验证安装成功

在浏览器中打开以下地址：

```
http://localhost:6080/vnc.html
```

如果看到登录界面，说明安装成功！🎉

**默认密码**：`admin2026`

---

### 模式二：容器模式（OpenClaw 用户）

**适用于**：已经在运行 OpenClaw 容器的用户。

#### 如果你已经安装了 OpenClaw

此技能已预装在 OpenClaw 镜像中，直接使用即可。

在 Claude Code 中输入：
```
skill smart-browser
```

#### 如果需要安装 OpenClaw

请参考 [OpenClaw 官方文档](https://github.com/openclaw/openclaw)

---

### 模式三：Docker 托管模式

**适用于**：希望用 Docker 部署，不依赖宿主机环境。

#### 前置要求

- 已安装 Docker
- 已安装 Docker Compose

#### 步骤 1：克隆项目

```bash
git clone https://github.com/z-qinghui/smart-browser.git
cd openclaw-anti-bot
```

#### 步骤 2：启动服务

```bash
docker-compose up -d
```

#### 步骤 3：查看日志

```bash
docker-compose logs -f
```

看到以下日志表示启动成功：
```
smart-browser  | VNC Auth Service running on http://127.0.0.1:3030
smart-browser  | Chrome started successfully
```

#### 步骤 4：访问 VNC

浏览器打开：`http://localhost:8080/vnc.html`  
密码：`admin2026`

---

## ❓ 常见问题

### Q1: 安装时提示 "command not found" 或 "找不到命令"

**原因**：缺少必要的命令（git、curl、wget 等）

**解决方法**：

**Ubuntu/Debian**：
```bash
sudo apt-get update
sudo apt-get install -y git curl wget
```

**CentOS/RHEL**：
```bash
sudo yum install -y git curl wget
```

**Mac**：
```bash
xcode-select --install
```

### Q2: 安装时提示 "Permission denied"

**原因**：没有执行权限

**解决方法**：
```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

### Q3: VNC 页面打不开

**检查服务是否运行**：
```bash
./scripts/status.sh
```

**重启服务**：
```bash
./scripts/stop-vnc.sh
./scripts/start-vnc.sh
```

### Q4: 忘记密码了怎么办？

默认密码是 `admin2026`

如需修改，编辑 `vnc/auth-server.js`，找到：
```javascript
const VALID_PASSWORD_HASH = computePasswordHash('admin2026');
```
改为你的新密码，然后重启服务。

### Q5: 安装很慢，一直卡住

**原因**：网络问题导致下载慢

**解决方法**：使用国内镜像
```bash
# 手动下载 Chrome（清华大学镜像站）
mkdir -p vendor/chrome-installers
wget https://mirrors.tuna.tsinghua.edu.cn/chrome/pool/main/g/google-chrome-stable/google-chrome-stable_146.0.7680.177-1_amd64.deb \
  -O vendor/chrome-installers/google-chrome-stable.deb

# 克隆 noVNC（Gitee 镜像）
git clone --depth 1 https://gitee.com/mirrors/noVNC.git vendor/noVNC

# 重新运行安装
sudo ./scripts/install.sh
```

---

## 🛠️ 核心组件

| 组件 | 端口 | 用途 |
|------|------|------|
| Chrome CDP | 9222 | 浏览器调试接口 |
| CDP Proxy | 3456 | CDP 协议代理 |
| TigerVNC | 5901 | 虚拟显示 |
| websockify | 6080 | WebSocket 转发 |
| nginx | 443/8080 | HTTPS 反向代理 |
| auth-server | 3030 | JWT 认证服务 |

---

## 📖 详细文档

- [部署指南](docs/deployment/)
  - [独立模式](docs/deployment/standalone.md)
  - [容器模式](docs/deployment/container.md)
  - [Docker 托管](docs/deployment/docker.md)
- [平台经验](site-patterns/)
  - [微信公众号](site-patterns/weixin.md)
  - [小红书](site-patterns/xiaohongshu.md)
  - [知乎](site-patterns/zhihu.md)

---

## 🔧 使用示例

### 抓取微信公众号文章

在 Claude Code 中输入：
```
帮我读取这篇文章：https://mp.weixin.qq.com/s/xxx
```

AI 会自动使用 CDP Proxy 访问并提取内容。

### 遇到验证码怎么办？

当 AI 提示需要人工干预时：

1. 浏览器打开 `http://localhost:6080/vnc.html`
2. 输入密码 `admin2026` 登录
3. 在 VNC 桌面中手动处理验证码
4. 告诉 AI "已完成验证，继续"

---

## 💬 获取帮助

遇到问题？

1. 查看 [故障排查文档](docs/vnc/troubleshooting.md)
2. 运行诊断命令：`./scripts/check-deps.sh`
3. 查看日志：`tail -f /tmp/websockify.log`

---

## 🔒 安全提示

- 默认密码 `admin2026` 仅用于测试，生产环境请修改
- 不要将 Cookie 和密码提交到 Git
- CDP 端口和 VNC 端口请勿暴露在公网

---

## 📝 License

MIT License
