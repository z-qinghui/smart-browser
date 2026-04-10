---
name: smart-browser
description: Use when accessing WeChat MP, Xiaohongshu, Zhihu via CDP Proxy; when managing VNC browser environment; when needing human-in-the-loop intervention for captcha/login walls
version: 1.0.0
author: z-qinghui
tags: [browser, vnc, cdp, anti-bot, wechat, xiaohongshu, zhihu]
github: https://github.com/z-qinghui/smart-browser
---

# smart-browser — 智能浏览器自动化套件

## 环境检测

**此技能依赖 CDP Proxy 和 VNC 服务运行**。使用前先检查服务是否可用：

```bash
# 检查 CDP Proxy 是否运行
curl -s http://127.0.0.1:3456/health
# 期望输出：{"status":"ok","connected":true,...}

# 检查 Chrome DevTools 是否运行
curl -s http://127.0.0.1:9222/json/version
# 期望输出：{"Browser": "Chrome/..."}
```

**判断逻辑：**
- 如果上述命令返回正常 → ✅ CDP Proxy 可用，可以使用技能
- 如果连接失败或报错 → ❌ 先运行 `./scripts/install.sh` 安装服务

---

## 触发场景

| 用户需求 | 是否触发 |
|---------|---------|
| "帮我抓取这篇公众号文章内容" | ✅ |
| "小红书笔记怎么在容器里访问" | ✅ |
| "容器里的 Chrome 如何保持登录态" | ✅ |
| "微信公众号文章链接内容读取" | ✅ |
| "知乎专栏文章抓取" | ✅ |
| "遇到验证码了，怎么手动处理" | ✅（引导用户访问 VNC） |
| "VNC 无法连接/黑屏/忘记密码" | ✅（使用 vnc-manager 模块） |
| 普通搜索/公开网页访问 | ❌（使用 web-access） |

---

## 快速开始

### 一键安装

```bash
# 克隆仓库
git clone https://github.com/z-qinghui/smart-browser.git ~/.claude/skills/smart-browser
cd ~/.claude/skills/smart-browser

# 运行安装脚本
./scripts/install.sh

# 验证安装
./scripts/check-deps.sh
```

### 访问方式

- **VNC**: `http://localhost:6080/vnc.html`
- **默认密码**: `admin2026`
- **CDP Proxy**: `http://localhost:3456`

---

## 使用示例

### 1. 微信公众号文章抓取

```bash
# 1. 创建 tab 并访问文章
TARGET=$(curl -s "http://localhost:3456/new?url=https://mp.weixin.qq.com/s/xxx" | jq -r '.targetId')

# 2. 提取正文内容
curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d "document.querySelector('#js_content').innerText"

# 3. 关闭 tab
curl -s "http://localhost:3456/close?target=$TARGET"
```

**首次使用需要扫码登录**：
1. 访问 VNC: `http://localhost:6080/vnc.html`，密码 `admin2026`
2. 在 VNC 桌面中访问任意公众号文章
3. 微信扫码登录
4. 登录态持久化到 `chrome-data` 目录

### 2. 小红书笔记抓取

```bash
# 创建 tab
TARGET=$(curl -s "http://localhost:3456/new?url=https://www.xiaohongshu.com/explore/xxx" | jq -r '.targetId')

# 滚动触发懒加载
curl -s "http://localhost:3456/scroll?target=$TARGET&direction=bottom"
sleep 1

# 提取内容
curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d "document.querySelector('.note-content').innerText"
```

### 3. Cookie 管理

```bash
# 导出 Cookie（备份登录态）
./scripts/cookie-manager.sh export weixin

# 导入 Cookie
./scripts/cookie-manager.sh import weixin

# 列出已保存的 Cookie
./scripts/cookie-manager.sh list
```

---

## CDP Proxy API

| 端点 | 方法 | 用途 |
|------|------|------|
| `/new?url=` | GET | 创建后台 tab |
| `/close?target=` | GET | 关闭 tab |
| `/navigate?target=&url=` | GET | 导航到 URL |
| `/eval?target=` | POST | 执行 JS 表达式 |
| `/click?target=` | POST | 点击元素 |
| `/scroll?target=&direction=` | GET | 滚动页面 |
| `/screenshot?target=&file=` | GET | 截图 |
| `/health` | GET | 健康检查 |

---

## 支持的平台

| 平台 | 反爬等级 | 需要登录 | 文档 |
|------|---------|---------|------|
| 微信公众号 | 高 | 是 | [使用指南](site-patterns/weixin.md) |
| 小红书 | 极高 | 部分 | [使用指南](site-patterns/xiaohongshu.md) |
| 知乎 | 中 | 否 | [使用指南](site-patterns/zhihu.md) |

---

## 人机协作约定

当浏览器访问遇到验证码、登录墙、或需要人工干预时：

> "当前页面需要人工验证（验证码/登录/交互等），请访问 **http://localhost:6080/vnc.html** 登录到浏览器手动操作，密码 `admin2026`，完成后告诉我继续。"

---

## 故障排查

### VNC 无法连接

```bash
# 检查 VNC 服务状态
./scripts/status.sh

# 重启 VNC 服务
./scripts/stop-vnc.sh
./scripts/start-vnc.sh
```

### CDP Proxy 连接超时

```bash
# 检查 Chrome 是否运行
curl http://127.0.0.1:9222/json/version

# 重启 CDP Proxy
pkill -f cdp-proxy.mjs
node scripts/cdp-proxy.mjs &
```

### 中文显示乱码

确保已安装中文字体：
```bash
apt-get install -y fonts-noto fonts-wqy-zenhei fonts-wqy-microhei
```

---

## 注意事项

1. **Token 安全**：不要将 Cookie 和密码提交到 Git
2. **频率控制**：避免短时间大量请求导致封号
3. **隐私保护**：用户数据目录需要妥善保管
4. **默认密码**：生产环境请修改 `admin2026`

---

## License

MIT
