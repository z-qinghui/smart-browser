# Docker 托管模式部署指南

适用于生产环境部署。

## 前置要求

- Docker 20+
- Docker Compose 2+
- 4GB+ 可用内存
- 云服务器/宿主机可访问外网

## 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/z-qinghui/smart-browser.git
cd smart-browser

# 2. 启动服务
docker-compose up -d

# 3. 查看日志
docker-compose logs -f

# 4. 验证安装
curl http://localhost:6080/vnc.html
```

## 访问方式

- **VNC**: http://localhost:8080/vnc.html
- **密码**: `admin2026`
- **CDP Proxy**: http://localhost:3456

## 配置修改

### 修改密码

编辑 `docker/docker-compose.yml`，添加环境变量：

```yaml
environment:
  - VNC_PASSWORD=your-new-password
```

然后重启：

```bash
docker-compose down
docker-compose up -d
```

### 修改分辨率

编辑 `docker/docker-compose.yml`：

```yaml
environment:
  - RESOLUTION=1920x1080  # 或 2560x1440
```

## 数据持久化

```yaml
volumes:
  - ./chrome-data:/var/chrome-data  # Chrome 用户数据
  - ./vnc-data:/root/.vnc           # VNC 配置
```

## 故障排查

```bash
# 查看容器日志
docker-compose logs smart-browser

# 进入容器
docker exec -it smart-browser bash

# 重启容器
docker-compose restart

# 重新构建
docker-compose down
docker-compose build
docker-compose up -d
```
