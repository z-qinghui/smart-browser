---
domain: mp.weixin.qq.com
aliases: [微信公众号，WeChat MP，公众号]
updated: 2026-04-06
---

# 微信公众号 - 反爬虫访问指南

## 平台特征

| 特征 | 说明 |
|------|------|
| **域名** | `mp.weixin.qq.com` |
| **反爬等级** | 高 |
| **需要登录** | 是（微信账号扫码） |
| **登录态有效期** | 约 7-30 天 |
| **推荐 Profile** | `/home/node/.chrome-data/weixin-profile` |
| **访问频率限制** | 单 IP 每小时约 50-100 篇文章 |

## 首次配置

### 1. 启动独立 Profile 的 Chrome

```bash
# 使用独立的微信 Profile 启动 Chrome
CHROME_DATA=/home/node/.chrome-data/weixin-profile \
  bash scripts/start-chrome.sh
```

### 2. 扫码登录

1. 在浏览器打开 `http://<宿主机 IP>:9222`
2. 看到 Chrome 调试页面
3. 访问任意公众号文章链接（如 https://mp.weixin.qq.com）
4. 页面会显示二维码，使用微信扫码登录
5. 登录成功后，登录态会持久化到 `weixin-profile` 目录

### 3. 导出 Cookie 备份

```bash
bash scripts/cookie-manager.sh export weixin
```

## 访问流程

### 方法一：通过 CDP Proxy API

```bash
# 1. 创建新 tab 并访问文章
RESULT=$(curl -s "http://localhost:3456/new?url=https://mp.weixin.qq.com/s/ARTICLE_ID")
TARGET_ID=$(echo "$RESULT" | jq -r '.targetId')

echo "Target ID: $TARGET_ID"

# 2. 等待页面加载
sleep 3

# 3. 提取正文内容
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('#js_content').innerText"

# 4. 提取标题
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('#activity-name').innerText"

# 5. 提取发布时间
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('#publish_time').innerText"

# 6. 完成后关闭 tab
curl -s "http://localhost:3456/close?target=$TARGET_ID"
```

### 方法二：使用 OpenClaw Gateway

```bash
# 通过 OpenClaw 发送消息
openclaw message send "访问这篇公众号文章并提取内容：https://mp.weixin.qq.com/s/xxx"
```

## 内容提取模板

### 完整提取脚本

```bash
#!/bin/bash
# extract-weixin-article.sh

ARTICLE_URL=$1
TARGET_ID=$(curl -s "http://localhost:3456/new?url=$ARTICLE_URL" | jq -r '.targetId')

sleep 3

# 提取标题
TITLE=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('#activity-name')?.innerText || ''")

# 提取作者
AUTHOR=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.rich_media_meta_nickname')?.innerText || ''")

# 提取正文
CONTENT=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('#js_content')?.innerText || ''")

# 提取发布时间
PUB_TIME=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('#publish_time')?.innerText || ''")

echo "=== $TITLE ==="
echo "作者：$AUTHOR"
echo "发布时间：$PUB_TIME"
echo ""
echo "$CONTENT"

# 关闭 tab
curl -s "http://localhost:3456/close?target=$TARGET_ID"
```

## 有效模式

### 1. 公众号文章链接格式

```
https://mp.weixin.qq.com/s?__biz=xxx&mid=xxx&idx=xxx&sn=xxx
https://mp.weixin.qq.com/s/SHORT_ID
```

### 2. 选择器参考

| 元素 | CSS 选择器 |
|------|----------|
| 标题 | `#activity-name` |
| 作者 | `.rich_media_meta_nickname` |
| 正文 | `#js_content` |
| 发布时间 | `#publish_time` |
| 摘要 | `#content_summary` |
| 阅读数 | `#read-count` |
| 在看数 | `#like-count` |

### 3. 图片提取

```javascript
// 提取正文中的所有图片
(() => {
  const imgs = document.querySelectorAll('#js_content img');
  return Array.from(imgs).map(img => ({
    src: img.getAttribute('data-src') || img.src,
    alt: img.alt || ''
  }));
})()
```

## 已知陷阱

| 陷阱 | 现象 | 解决方案 |
|------|------|---------|
| **链接过期** | 返回"已删除"页面 | 检查 `#js_share` 元素是否存在 |
| **地区限制** | 部分内容仅特定地区可访问 | 使用 VNC 环境切换 IP |
| **登录失效** | Cookie 过期 | 重新扫码登录，导出新 Cookie |
| **反爬触发** | 页面返回验证码 | 降低访问频率，等待 1-2 小时 |
| **图片防盗链** | 图片无法直接下载 | 使用 Referer 或通过浏览器截图 |

## 防封号建议

1. **频率控制**：单次会话不超过 50 篇文章
2. **随机延迟**：请求间隔 2-5 秒随机延迟
3. **避免并发**：不要同时打开过多 tab
4. **登录态保护**：不要频繁重新登录

## 故障排查

### 问题：页面显示"已删除"

```bash
# 检查是否是链接本身失效
curl -s "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.deleted_tip')?.innerText"

# 如果返回内容，说明链接已失效
```

### 问题：登录态过期

```bash
# 1. 关闭所有微信相关 tab
# 2. 清除 Profile 缓存（可选）
rm -rf /home/node/.chrome-data/weixin-profile/Default/Cache

# 3. 重新扫码登录
# 4. 导出新 Cookie
bash scripts/cookie-manager.sh export weixin
```

## 相关资源

- 小红书访问指南：`site-patterns/xiaohongshu.md`
- Cookie 管理：`scripts/cookie-manager.sh`
