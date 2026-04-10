---
domain: zhihu.com
aliases: [知乎，Zhihu]
updated: 2026-04-06
---

# 知乎 - 反爬虫访问指南

## 平台特征

| 特征 | 说明 |
|------|------|
| **域名** | `www.zhihu.com` |
| **反爬等级** | 中 |
| **需要登录** | 否（部分内容的完整内容需要登录） |
| **登录态有效期** | 约 30 天 |
| **推荐 Profile** | `/home/node/.chrome-data/zhihu-profile` |
| **访问频率限制** | 未登录约 50 页/小时，登录后约 300 页/小时 |

## 首次配置

### 1. 启动独立 Profile 的 Chrome

```bash
CHROME_DATA=/home/node/.chrome-data/zhihu-profile \
  bash scripts/start-chrome.sh
```

### 2. 扫码登录（可选）

部分内容无需登录即可访问，但完整内容（如评论、收藏夹）需要登录：

1. 在浏览器打开 `http://<宿主机 IP>:9222`
2. 访问 https://www.zhihu.com
3. 使用 App 扫码登录
4. 登录后导出 Cookie 备份

```bash
bash scripts/cookie-manager.sh export zhihu
```

## 访问流程

### 方法一：专栏文章提取

```bash
ARTICLE_URL="https://zhuanlan.zhihu.com/p/ARTICLE_ID"
TARGET_ID=$(curl -s "http://localhost:3456/new?url=$ARTICLE_URL" | jq -r '.targetId')

sleep 3

# 提取标题
TITLE=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('h1.Post-Title')?.innerText || ''")

# 提取正文
CONTENT=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.Post-RichText')?.innerText || ''")

# 提取作者
AUTHOR=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.AuthorInfo')?.innerText || ''")

echo "=== $TITLE ==="
echo "作者：$AUTHOR"
echo ""
echo "$CONTENT"

curl -s "http://localhost:3456/close?target=$TARGET_ID"
```

### 方法二：问题页面提取

```bash
QUESTION_URL="https://www.zhihu.com/question/QUESTION_ID"
TARGET_ID=$(curl -s "http://localhost:3456/new?url=$QUESTION_URL" | jq -r '.targetId')

sleep 3

# 提取问题标题
TITLE=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('h1.QuestionHeader-title')?.innerText || ''")

# 提取回答数量
ANSWER_COUNT=$(curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('[data-zop-question-answers]')?.innerText || ''")

echo "问题：$TITLE"
echo "回答数：$ANSWER_COUNT"

curl -s "http://localhost:3456/close?target=$TARGET_ID"
```

## 有效模式

### 1. 链接格式

| 类型 | 链接格式 |
|------|---------|
| 专栏文章 | `https://zhuanlan.zhihu.com/p/ARTICLE_ID` |
| 回答 | `https://www.zhihu.com/question/QUESTION_ID/answer/ANSWER_ID` |
| 问题 | `https://www.zhihu.com/question/QUESTION_ID` |
| 用户主页 | `https://www.zhihu.com/people/USER_ID` |
| 收藏夹 | `https://www.zhihu.com/collection/COLLECTION_ID` |

### 2. 选择器参考

| 元素 | CSS 选择器 |
|------|----------|
| 文章标题 | `h1.Post-Title` |
| 文章正文 | `.Post-RichText` |
| 作者信息 | `.AuthorInfo` |
| 赞同数 | `.VoteButton--up` |
| 发布时间 | `.content-time` |
| 问题标题 | `h1.QuestionHeader-title` |
| 回答内容 | `.RichContent-inner` |
| 评论数 | `.content-actions .comment-count` |

### 3. 内容折叠处理

```javascript
// 点击"展开全文"按钮
(() => {
  const expandBtn = document.querySelector('.expand-button');
  if (expandBtn) {
    expandBtn.click();
    return { expanded: true };
  }
  return { expanded: false };
})()
```

## 已知陷阱

| 陷阱 | 现象 | 解决方案 |
|------|------|---------|
| **内容折叠** | 长回答只显示部分 | 点击"展开全文"按钮 |
| **登录弹窗** | 滚动后弹出 | 保持 Cookie 有效，或降低访问频率 |
| **图片懒加载** | `src` 是占位图 | 从 `data-original` 提取 |
| **验证码** | 频繁访问后弹出 | 降低频率，等待 30 分钟 |
| **链接失效** | 内容被删除 | 检查 `.error-page` 元素 |

## 反爬绕过技巧

### 1. 随机延迟

```bash
# 在请求之间添加随机延迟
sleep $((3 + RANDOM % 5))  # 3-7 秒随机
```

### 2. 降低频率

- 未登录状态：每小时不超过 50 页
- 登录状态：每小时不超过 300 页
- 建议每抓取 20 篇内容休息 2 分钟

### 3. 模拟人类行为

```bash
# 先滚动再提取（模拟阅读行为）
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=bottom"
sleep 2
curl -s "http://localhost:3456/scroll?target=$TARGET_ID&direction=top"
sleep 1
# 再提取内容
```

## 故障排查

### 问题：页面显示"内容不存在"

```bash
# 检查是否是内容被删除
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.querySelector('.error-page')?.innerText || '内容存在'"

# 如果返回"内容不存在"，说明内容已被删除或链接有误
```

### 问题：登录弹窗频繁出现

```bash
# 检查 Cookie 是否有效
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "document.cookie.includes('z_c0')"

# 如果返回 false，重新登录
# 导入之前备份的 Cookie
bash scripts/cookie-manager.sh import zhihu

# 刷新页面
curl -s "http://localhost:3456/navigate?target=$TARGET_ID&url=https://www.zhihu.com"
```

### 问题：图片无法加载

```bash
# 从 data-original 提取真实图片 URL
curl -s -X POST "http://localhost:3456/eval?target=$TARGET_ID" \
  -d "Array.from(document.querySelectorAll('img')).map(img => ({
    src: img.src,
    dataOriginal: img.dataset?.original || null
  }))"
```

## 相关资源

- 微信公众号访问指南：`site-patterns/weixin.md`
- 小红书访问指南：`site-patterns/xiaohongshu.md`
- Cookie 管理：`scripts/cookie-manager.sh`
