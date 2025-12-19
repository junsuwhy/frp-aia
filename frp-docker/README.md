# FRP Docker 部署指南

基於 gemini.md 建議優化的 FRP + Caddy 自動 HTTPS 解決方案。

## 🎯 特色

- ✅ **自動 HTTPS**：Caddy 自動申請 Let's Encrypt SSL 憑證
- ✅ **安全加固**：移除不必要的 Admin API 外露
- ✅ **簡化架構**：專注於核心功能（FRP + SSL）
- ✅ **Docker 網路隔離**：服務間使用內部網路通訊

## 📋 前置需求

1. **DNS 設定**：確保 `*.yourdomain.com` 的 A Record 指向你的伺服器 IP
2. **防火牆**：開放 80, 443, 7000 端口
3. **Docker & Docker Compose**

## � 目錄結構

```
frp-docker/
├── .env                # 環境變數配置（敏感資訊）
├── .env.example        # 環境變數範例
├── docker-compose.yml  # Docker Compose 配置
├── frps.toml          # FRP 伺服器配置
├── Caddyfile          # Caddy 反向代理配置
├── logs/              # FRP 日誌目錄
└── .gitignore         # Git 忽略文件
```

## �🚀 快速開始

### 1. 修改配置

編輯 `.env` 文件：

```bash
# 修改為你的域名
DOMAIN=yourdomain.com
EMAIL=your-email@example.com

# 設定強密碼（重要！）
FRP_TOKEN=your-strong-password-here
FRP_WEB_USER=admin
FRP_WEB_PASSWORD=your-admin-password
```

### 2. 啟動服務

```bash
cd frp-docker
docker-compose up -d
```

### 3. 檢查狀態

```bash
# 查看容器狀態
docker-compose ps

# 查看 Caddy 日誌（確認 SSL 憑證申請）
docker-compose logs -f caddy

# 查看 FRP 日誌
docker-compose logs -f frps
```

### 4. 訪問 Dashboard

開啟瀏覽器訪問：`http://your-server-ip:7500`

## 🖥️ 客戶端配置範例

在你的 VM 或本地機器上配置 `frpc.toml`：

```toml
serverAddr = "your-server-ip"
serverPort = 7000
auth.token = "your-strong-password-here"

[[proxies]]
name = "web-demo"
type = "http"
localIP = "127.0.0.1"
localPort = 80
customDomains = ["demo.yourdomain.com"]
```

啟動客戶端：

```bash
docker run -d --name frpc \
  -v ./frpc.toml:/etc/frp/frpc.toml \
  snowdreamtech/frpc:latest
```

## 🔧 重要修改說明

根據 gemini.md 的建議，本配置做了以下優化：

### 1. 網路架構修正
- ✅ 所有服務使用同一個 Docker bridge 網路 (`frp_net`)
- ✅ Caddy 使用服務名稱 `frps:8080` 進行反向代理

### 2. 安全性提升
- 🔒 移除 Caddy Admin API (2019 port) 的外部暴露
- 🔒 `.gitignore` 保護敏感文件

### 3. 架構簡化
- 💡 註解掉 `frp-manager` 服務（非核心功能）
- 💡 移除 Certbot（Caddy 已內建 ACME 支持）

### 4. 配置修正
- 🔧 `frps.toml` 中 `webServer.addr` 改為 `0.0.0.0`
- 🔧 Caddyfile 移除 admin API 配置

## 📝 服務端口說明

| 端口 | 服務 | 用途 |
|------|------|------|
| 80 | Caddy | HTTP（自動重定向到 HTTPS）|
| 443 | Caddy | HTTPS（SSL 流量）|
| 7000 | FRP Server | FRP 客戶端連線 |
| 7500 | FRP Dashboard | 網頁管理介面（可選）|

## 🛠️ 故障排除

### SSL 憑證無法申請

1. 確認 DNS 記錄正確指向伺服器
2. 確認 80/443 端口開放
3. 查看 Caddy 日誌：`docker-compose logs caddy`

### 客戶端無法連線

1. 確認防火牆開放 7000 端口
2. 檢查 `auth.token` 是否一致
3. 查看 FRP 日誌：`docker-compose logs frps`

### 反向代理失敗

1. 確認 frps 和 caddy 在同一個網路中
2. 確認 `frps.toml` 中 `vhostHTTPPort = 8080`
3. 確認 Caddyfile 中使用 `frps:8080`

## 📚 參考資料

- [FRP 官方文檔](https://github.com/fatedier/frp)
- [Caddy 文檔](https://caddyserver.com/docs/)
- 本配置基於 gemini.md 的優化建議
