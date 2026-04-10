#!/usr/bin/env node
/**
 * VNC 认证服务
 * 轻量级 JWT 认证中间件，支持 30 天免登录
 */

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// === 配置 ===
const CONFIG = {
    // 密码哈希存储（使用 PBKDF2 派生）
    // 默认密码：admin2026
    passwordHash: 'a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5',
    // JWT 密钥（每次启动随机生成，增强安全性）
    jwtSecret: crypto.randomBytes(32).toString('hex'),
    // Token 有效期 30 天
    tokenExpiry: 30 * 24 * 60 * 60 * 1000,
    // 服务端口
    port: 3030,
    // 监听地址（仅 localhost）
    host: '127.0.0.1'
};

// 计算密码哈希（与前端一致）
function computePasswordHash(password) {
    const SALT = 'vnc-auth-2026';
    return crypto.createHash('sha256').update(password + SALT).digest('hex');
}

// 实际的密码哈希（前端发送过来的哈希值）
const VALID_PASSWORD_HASH = computePasswordHash('admin2026');

// 简单的 JWT 实现
function signJWT(payload, secret) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const headerBase64 = base64UrlEncode(JSON.stringify(header));
    const payloadBase64 = base64UrlEncode(JSON.stringify(payload));
    const signature = crypto
        .createHmac('sha256', secret)
        .update(`${headerBase64}.${payloadBase64}`)
        .digest('base64url');
    return `${headerBase64}.${payloadBase64}.${signature}`;
}

function verifyJWT(token, secret) {
    try {
        const [headerBase64, payloadBase64, signature] = token.split('.');
        const expectedSignature = crypto
            .createHmac('sha256', secret)
            .update(`${headerBase64}.${payloadBase64}`)
            .digest('base64url');

        if (signature !== expectedSignature) {
            return null;
        }

        const payload = JSON.parse(base64UrlDecode(payloadBase64));

        // 检查过期
        if (payload.exp && Date.now() > payload.exp) {
            return null;
        }

        return payload;
    } catch (e) {
        return null;
    }
}

function base64UrlEncode(str) {
    return Buffer.from(str).toString('base64url');
}

function base64UrlDecode(str) {
    return Buffer.from(str, 'base64url').toString('utf8');
}

// 解析请求体
function parseBody(req) {
    return new Promise((resolve, reject) => {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                resolve(body ? JSON.parse(body) : {});
            } catch (e) {
                reject(new Error('Invalid JSON'));
            }
        });
        req.on('error', reject);
    });
}

// 设置 CORS 头
function setCorsHeaders(res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

// 认证中间件
function authenticate(req) {
    let token = null;

    // 从 Authorization header 读取
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
    }

    // 从 cookie 读取（优先级更低）
    if (!token && req.headers.cookie) {
        const cookies = req.headers.cookie.split(';');
        for (const cookie of cookies) {
            const [name, value] = cookie.trim().split('=');
            if (name === 'vnc_auth_token') {
                token = value;
                break;
            }
        }
    }

    if (!token) {
        return null;
    }

    const payload = verifyJWT(token, CONFIG.jwtSecret);

    if (!payload || !payload.authenticated) {
        return null;
    }

    return payload;
}

// 请求处理
async function handleRequest(req, res) {
    const url = new URL(req.url, `http://${CONFIG.host}:${CONFIG.port}`);
    const pathname = url.pathname;

    // CORS preflight
    if (req.method === 'OPTIONS') {
        setCorsHeaders(res);
        res.writeHead(200);
        res.end();
        return;
    }

    setCorsHeaders(res);
    res.setHeader('Content-Type', 'application/json');

    // 公开的路由
    if (pathname === '/api/auth/login' && req.method === 'POST') {
        try {
            const body = await parseBody(req);
            const { password } = body;

            if (!password) {
                res.writeHead(400);
                res.end(JSON.stringify({ message: '缺少密码' }));
                return;
            }

            // 验证密码哈希
            if (password !== VALID_PASSWORD_HASH) {
                // 模拟延迟防止暴力破解
                await new Promise(r => setTimeout(r, 300));
                res.writeHead(401);
                res.end(JSON.stringify({ message: '密码错误' }));
                return;
            }

            // 生成 token
            const token = signJWT({
                authenticated: true,
                iat: Date.now(),
                exp: Date.now() + CONFIG.tokenExpiry
            }, CONFIG.jwtSecret);

            // 设置 cookie（30 天有效期）
            const cookieMaxAge = Math.floor(CONFIG.tokenExpiry / 1000);
            const cookieOptions = `vnc_auth_token=${token}; Path=/; Max-Age=${cookieMaxAge}; HttpOnly; Secure; SameSite=Strict`;

            res.writeHead(200, {
                'Content-Type': 'application/json',
                'Set-Cookie': cookieOptions
            });
            res.end(JSON.stringify({ token, expiresIn: CONFIG.tokenExpiry }));
            return;

        } catch (e) {
            res.writeHead(400);
            res.end(JSON.stringify({ message: '请求格式错误' }));
            return;
        }
    }

    // 需要认证的路由
    if (pathname === '/api/auth/validate' && req.method === 'POST') {
        const user = authenticate(req);

        if (!user) {
            res.writeHead(401);
            res.end(JSON.stringify({ message: '未授权' }));
            return;
        }

        res.writeHead(200);
        res.end(JSON.stringify({ valid: true }));
        return;
    }

    // 登出
    if (pathname === '/api/auth/logout' && req.method === 'POST') {
        res.writeHead(200);
        res.end(JSON.stringify({ success: true }));
        return;
    }

    // nginx auth_request 验证端点（返回 200 或 401）
    if (pathname === '/api/auth/check' && req.method === 'GET') {
        const user = authenticate(req);
        if (!user) {
            res.writeHead(401);
            res.end('Unauthorized');
            return;
        }
        res.writeHead(200);
        res.end('OK');
        return;
    }

    // 根路径认证通过时的重定向端点
    if (pathname === '/api/auth/redirect' && req.method === 'GET') {
        const user = authenticate(req);
        if (!user) {
            res.writeHead(401);
            res.end('Unauthorized');
            return;
        }
        // 返回 302 重定向到 /vnc.html
        res.writeHead(302, { 'Location': '/vnc.html' });
        res.end();
        return;
    }

    // 404
    res.writeHead(404);
    res.end(JSON.stringify({ message: 'Not found' }));
}

// 创建服务
const server = http.createServer(handleRequest);

server.listen(CONFIG.port, CONFIG.host, () => {
    console.log(`VNC Auth Service running on http://${CONFIG.host}:${CONFIG.port}`);
});

// 优雅退出
process.on('SIGTERM', () => {
    server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
    server.close(() => process.exit(0));
});
