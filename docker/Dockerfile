FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1920x1080

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    websockify \
    nginx \
    chromium-browser \
    fonts-noto \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    nodejs \
    npm \
    jq \
    xfce4 \
    xfce4-goodies \
    fcitx5 \
    fcitx5-pinyin \
    curl \
    socat \
    && rm -rf /var/lib/apt/lists/*

# 创建目录
RUN mkdir -p /var/chrome-data /opt/vnc-auth /opt/cdp-proxy

# 复制应用文件
COPY vnc/rc.chrome-vnc.sh /etc/rc.chrome-vnc.sh
COPY vnc/auth-server.js /opt/vnc-auth/auth-server.js
COPY vnc/login.html /opt/vnc-auth/login.html
COPY scripts/cdp-proxy.mjs /opt/cdp-proxy.mjs
COPY docker/nginx/nginx.conf /etc/nginx/sites-available/default

RUN chmod +x /etc/rc.chrome-vnc.sh

# 暴露端口
EXPOSE 6080 8080 9222 3456

# 启动脚本
CMD ["/etc/rc.chrome-vnc.sh"]
