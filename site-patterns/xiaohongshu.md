---
domain: xiaohongshu.com
aliases: [小红书，XHS，RED]
updated: 2026-04-06
---

# 小红书 - 反爬虫访问指南

## 平台特征

| 特征 | 说明 |
|------|------|
| **域名** | `www.xiaohongshu.com` |
| **反爬等级** | 极高 |
| **需要登录** | 部分公开内容可匿名访问 |
| **登录态有效期** | 约 30-90 天 |
| **推荐 Profile** | `/home/node/.chrome-data/xhs-profile` |
| **访问频率限制** | 未登录约 20 页/小时，登录后约 200 页/小时 |

## 首次配置

### 1. 启动独立 Profile 的 Chrome

```bash
# 使用独立的小红书 Profile 启动 Chrome
CHROME_DATA=/home/node/.chrome-data/xhs-profile \
  bash scripts/start-chrome.sh
```

### 2. 扫码登录（可选）

部分公开内容无需登录即可访问，但完整内容需要登录：

1. 在浏览器打开 `http://<宿主机 IP>:9222`
2. 访问 https://www.xiaohongshu.com
3. 使用 App 扫码登录
4. 登录成功后导出 Cookie 备份

### 3. 导出 Cookie 备份

```bash
bash scripts/cookie-manager.sh export xiaohongshu
```

## 访问流程

### 方法一：通过 CDP Proxy API

```bash
# 1. 创建新 tab 并访问笔记
NOTE_URL="https://www.xiaohongshu.com/explore/NOTE_ID"
RESULT=$(curl -s "http://localhost:3456/new?url=$NOTE_URL")
TARGET_ID=$(echo "$RESULT" | jq -r '.targetId')

echo "Target ID: $TARGET_ID"

# 2. 等待页面加载
sleep 3

# 3. 滚动触发懒加载（加载图片）
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=bottom"

# 4. 提取笔记标题
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.title')?.innerText || ''"

# 5. 提取笔记内容
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.note-content')?.innerText || ''"

# 6. 提取所有图片
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "Array.from(document.querySelectorAll('.note-content img')).map(img => img.src)"

# 7. 完成后关闭 tab
curl -s "http://localhost:3456/close?target=$TARGET_ID"
```

### 方法二：完整提取脚本

```bash
#!/bin/bash
# extract-xhs-note.sh

NOTE_URL=$1
TARGET_ID=$(curl -s "http://localhost:3456/new?url=$NOTE_URL" | jq -r '.targetId')

# 等待加载
sleep 3

# 滚动加载所有图片
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=bottom" &>/dev/null
sleep 2

# 提取标题
TITLE=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.title')?.innerText || ''")

# 提取内容
CONTENT=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.note-content')?.innerText || ''")

# 提取图片
IMAGES=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "Array.from(document.querySelectorAll('.note-content img')).map(img => img.src)")

# 提取作者
AUTHOR=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.author-name')?.innerText || ''")

# 提取点赞数
LIKES=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.like-count')?.innerText || ''")

echo "=== $TITLE ==="
echo "作者：$AUTHOR"
echo "点赞：$LIKES"
echo ""
echo "$CONTENT"
echo ""
echo "图片链接:"
echo "$IMAGES" | jq -r '.[]'

# 关闭 tab
curl -s "http://localhost:3456/close?target=$TARGET_ID"
```

## 有效模式

### 1. 笔记链接格式

```
https://www.xiaohongshu.com/explore/NOTE_ID
https://www.xiaohongshu.com/discovery/item/NOTE_ID
https://xhslink.com/SHORT_CODE  # 短链接
```

### 2. 选择器参考

| 元素 | CSS 选择器 |
|------|----------|
| 标题 | `.title` |
| 正文 | `.note-content` |
| 作者 | `.author-name` |
| 点赞数 | `.like-count` |
| 收藏数 | `.collect-count` |
| 评论数 | `.comment-count` |
| 图片 | `.note-content img` |
| 发布时间 | `.time` |

### 3. 评论提取

```javascript
// 滚动到评论区并提取评论
(() => {
  // 滚动到评论区
  const comments = document.querySelector('.comment-list');
  if (comments) {
    comments.scrollIntoView();
  }

  // 提取评论
  return Array.from(document.querySelectorAll('.comment-item')).map(c => ({
    author: c.querySelector('.username')?.innerText || '',
    content: c.querySelector('.content')?.innerText || '',
    likes: c.querySelector('.like-count')?.innerText || '0'
  }));
})()
```

## 已知陷阱

| 陷阱 | 现象 | 解决方案 |
|------|------|---------|
| **内容折叠** | 长文只显示部分内容 | 执行 expand 点击操作 |
| **评论分页** | 评论需要滚动加载 | 多次 `/scroll` 触发加载 |
| **图片懒加载** | `src` 是占位图 | 从 `data-src` 提取，或先滚动页面 |
| **登录弹窗** | 浏览一定数量后弹出 | 保持 Cookie 有效，或降低频率 |
| **链接失效** | 笔记已删除或隐藏 | 检查 `.error-page` 元素 |

## 反爬绕过技巧

### 1. 滚动触发懒加载

```bash
# 多次滚动，确保所有内容加载
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=bottom"
sleep 1
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=bottom"
sleep 1
```

### 2. 随机延迟

```bash
# 在请求之间添加随机延迟
sleep $((2 + RANDOM % 4))  # 2-5 秒随机
```

### 3. 降低频率

- 未登录状态：每小时不超过 20 页
- 登录状态：每小时不超过 200 页
- 建议每抓取 10 篇笔记休息 5 分钟

## 故障排查

### 问题：图片无法加载

```bash
# 检查是否是懒加载问题
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=bottom"
sleep 2

# 重新提取图片
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "Array.from(document.querySelectorAll('img')).map(img => img.dataset?.src || img.src)"
```

### 问题：登录弹窗频繁出现

```bash
# 1. 检查 Cookie 是否有效
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.cookie.includes('web_session')"

# 2. 如果返回 false，重新登录
# 3. 导入之前备份的 Cookie
bash scripts/cookie-manager.sh import xiaohongshu
```

## 相关资源

- 微信公众号访问指南：`site-patterns/weixin.md`
- Cookie 管理：`scripts/cookie-manager.sh`
