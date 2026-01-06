# FRP Tool - 跨平台 FRP 客戶端管理工具

一個基於 Go 語言開發的 FRP 客戶端管理工具，支援 **Linux、macOS 和 Windows**。

## ✨ 特性

- 🚀 一鍵安裝，支援 `curl | sh` 和 PowerShell 安裝
- 🔧 簡單的命令列介面（CLI）
- 🐳 基於 Docker，跨平台運行
- 📝 TOML 配置檔案管理
- 🔐 支援從 URL 讀取配置（適合批量部署）
- 💻 支援 Windows/Linux/macOS 三大平台

## 📦 快速安裝

### Linux / macOS

```bash
# 方式 1: 直接傳參
curl -fsSL https://install.your-domain.com/install.sh | bash -s -- --server test.domain.com --token abc123

# 方式 2: 從 URL 讀取配置（推薦批量部署）
curl -fsSL https://install.your-domain.com/install.sh | bash -s -- --config https://install.your-domain.com/config.json
```

### Windows (PowerShell)

```powershell
# 直接傳參
irm https://install.your-domain.com/install.ps1 | iex -ArgumentList "-Server test.domain.com -Token abc123"

# 從 URL 讀取配置
$params = @{ConfigUrl="https://install.your-domain.com/config.json"}
irm https://install.your-domain.com/install.ps1 | iex @params
```

## 🎯 使用示例

```bash
# 新增通道（自動生成隨機名稱）
frp-tool add 3000

# 新增通道（指定名稱）
frp-tool add 8080 myapp

# 列出所有通道
frp-tool ls

# 移除通道
frp-tool rm myapp
```

## 📋 命令列表

| 命令 | 說明 |
|------|------|
| `frp-tool init --server <domain> --token <token>` | 初始化環境 |
| `frp-tool add <port> [name]` | 新增通道 |
| `frp-tool rm <name>` | 移除通道 |
| `frp-tool ls` | 列出所有通道 |

## 🛠️ 開發指南

### 本地編譯

```bash
# 編譯當前平台
cd cli
go build -o frp-tool main.go

# 跨平台編譯（在 Ubuntu 下編譯 Windows .exe）
GOOS=windows GOARCH=amd64 go build -o frp-tool.exe main.go

# 編譯所有平台
cd cli
./build.sh
```

### 配置檔案格式 (config.json)

```json
{
  "server": "testdomain.ccom",
  "token": "your_secret_token_here"
}
```

## 📖 詳細文檔

查看 [INSTALL.md](INSTALL.md) 獲取完整的安裝和部署指南。

---

# 原 FRP 內網穿透系統文档



```
┌─────────────────────────────────────────────────────────────┐
│                      Internet (公網)                         │
│                   *.testdomain.ccom                    │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS (443)
                         │
                ┌────────▼─────────┐
                │  公網服務器       │ 
                │  ┌─────────────┐ │
                │  │   Caddy     │ │ 反向代理 + HTTPS 終止
                │  └──────┬──────┘ │
                │         │        │
                │  ┌──────▼──────┐ │
                │  │    frps     │ │ FRP 服務端
                │  └──────┬──────┘ │
                │         │        │
                │  ┌──────▼──────┐ │
                │  │frp-manager  │ │ API 服務 (動態配置)
                │  └─────────────┘ │
                └──────────────────┘
                         │
                         │ FRP 隧道 (7000)
                         │
                ┌────────▼─────────┐
                │  本地 VM/電腦     │
                │  ┌─────────────┐ │
                │  │    frpc     │ │ FRP 客戶端
                │  └──────┬──────┘ │
                │         │        │
                │  ┌──────▼──────┐ │
                │  │localhost:XXX│ │ 您的本地服務
                │  └─────────────┘ │
                └──────────────────┘
```

## 目錄結構

```
~/frp/
├── cli/                    # Go CLI 工具
│   ├── main.go            # 源碼
│   ├── build.sh           # 編譯腳本
│   └── dist/              # 編譯產物
├── client/                 # 客戶端配置 (本地運行)
│   ├── frpc.toml          # 客戶端配置文件
│   └── docker-compose.yaml
├── server/                 # 服務端配置 (公網服務器)
│   ├── .env               # 環境變數
│   ├── docker-compose.yml # 服務編排
│   ├── frps/              # FRP 服務端
│   ├── install-files/     # 安裝文件分發
│   └── caddy/             # 反向代理
├── scripts/                # 各種腳本
└── docs/                   # 文檔
```

## 快速開始

### 前置需求

- Docker 和 Docker Compose
- 公網服務器一台 (已配置好服務端)
- 本地已運行的 Web 服務

### 客戶端部署

1. **啟動客戶端服務**

```bash
cd ~/frp/client
docker-compose up -d
```

2. **驗證連接狀態**

```bash
docker-compose logs -f
# 應該看到 "login to server success" 訊息
```

## 使用方法

### frp-domain 命令

`frp-domain` 是核心管理工具，提供以下功能：

#### 新增子域名

將本地服務映射到公網域名：

```bash
frp-domain add <subdomain> <local_port>
```

**範例:**

```bash
# 將本地 3000 端口映射到 https://myapp.testdomain.ccom
frp-domain add myapp 3000

# 將本地 8080 端口映射到 https://api.testdomain.ccom
frp-domain add api 8080
```

**執行過程:**
1. ✓ 檢查本地端口是否有服務運行
2. ✓ 更新客戶端配置 (frpc.toml)
3. ✓ 重啟客戶端容器
4. ✓ 通知服務端更新 Caddy 配置
5. ✓ 自動申請 HTTPS 證書
6. ✓ 完成! 服務現在可通過 HTTPS 訪問

#### 移除子域名

```bash
frp-domain remove <subdomain>
```

**範例:**

```bash
frp-domain remove myapp
```

#### 列出所有域名

```bash
frp-domain list
```

輸出範例:
```
已配置的子域名:
- testing.testdomain.ccom -> localhost:80
- myapp.testdomain.ccom -> localhost:3000
```

## 配置說明

### 客戶端配置 (frpc.toml)

```toml
serverAddr = "123.123.123.123"     # 公網服務器 IP
serverPort = 7000                # FRP 控制端口
auth.method = "token"
auth.token = "YOUR_SECRET_TOKEN_HERE"

# 代理配置範例
[[proxies]]
name = "myapp"                   # 唯一識別名稱
type = "http"
localIP = "127.0.0.1"
localPort = 3000                 # 本地服務端口
customDomains = ["myapp.testdomain.ccom"]
```

### 服務端配置

服務端由三個服務組成：

#### 1. frps (FRP 服務端)

- **控制端口**: 7000 (接受客戶端連接)
- **HTTP 端口**: 8080 (處理 HTTP 流量)
- **HTTPS 端口**: 8443 (處理 HTTPS 流量)
- **Dashboard**: 7500 (Web 管理界面)

#### 2. Caddy (反向代理)

- **HTTP**: 80 (自動重定向到 HTTPS)
- **HTTPS**: 443 (對外服務端口)
- **Admin API**: 2019 (動態配置)

功能:
- 自動申請 Let's Encrypt 證書
- 泛域名支持 (`*.testdomain.ccom`)
- 自動 HTTP 到 HTTPS 重定向

#### 3. frp-manager (API 服務)

- **API 端口**: 5000
- **功能**: 接收客戶端請求，動態更新 Caddy 配置

### 環境變數 (.env)

關鍵配置項:

```bash
# 域名配置
DOMAIN=testdomain.ccom
EMAIL=web@yourmail.domain

# 安全認證
FRP_TOKEN=YOUR_SECRET_TOKEN_HERE
FRP_API_TOKEN=YOUR_SECRET_TOKEN_HERE

# 端口配置
FRP_BIND_PORT=7000
CADDY_HTTP_PORT=80
CADDY_HTTPS_PORT=443
FRP_MANAGER_PORT=5000
```

## 工作流程

### 完整流量路徑

```
用戶請求: https://myapp.testdomain.ccom
    ↓
1. DNS 解析到公網服務器 (123.123.123.123)
    ↓
2. Caddy 接收 HTTPS 請求 (443)
   - 終止 TLS 連接
   - 驗證/使用 Let's Encrypt 證書
    ↓
3. Caddy 反向代理到 frps (8080)
   - 保留原始 Host header
   - 添加 X-Forwarded-* headers
    ↓
4. frps 根據 Host 匹配對應的客戶端連接
   - 查找 customDomains: myapp.testdomain.ccom
   - 路由到對應的 frpc 連接
    ↓
5. frpc 轉發到本地服務
   - 目標: 127.0.0.1:3000
    ↓
6. 本地服務處理請求並返回響應
    ↓
7. 響應原路返回給用戶
```

## 日誌查看

### 客戶端日誌

```bash
cd ~/frp/client
docker-compose logs -f

# 或直接查看日誌文件
tail -f ~/frp/client/logs/frpc.log
```

### 服務端日誌

```bash
cd ~/frp/server

# 查看所有服務
docker-compose logs -f

# 查看特定服務
docker-compose logs -f frps
docker-compose logs -f caddy
```

## 故障排除

### 問題: 域名無法訪問

**檢查步驟:**

1. 確認本地服務正在運行
```bash
curl localhost:3000
# 或
netstat -tulpn | grep 3000
```

2. 檢查客戶端連接狀態
```bash
cd ~/frp/client
docker-compose logs | grep "login to server success"
```

3. 檢查 DNS 解析
```bash
nslookup myapp.testdomain.ccom
# 應該指向 123.123.123.123
```

4. 檢查防火牆
```bash
# 確保 7000 端口可訪問
telnet 123.123.123.123 7000
```

### 問題: HTTPS 證書錯誤

**解決方法:**

1. 檢查 Caddy 證書申請狀態
```bash
cd ~/frp/server
docker-compose exec caddy caddy list-certificates
```

2. 查看 Caddy 日誌
```bash
docker-compose logs caddy | grep -i certificate
```

3. 如果證書申請失敗，檢查:
   - 域名 DNS 是否正確指向服務器
   - 80/443 端口是否開放
   - Let's Encrypt 速率限制 (每週最多 50 個證書)

### 問題: 客戶端無法連接到服務端

**檢查步驟:**

1. 驗證 Token 配置
```bash
# 客戶端和服務端的 token 必須一致
grep token ~/frp/client/frpc.toml
grep token ~/frp/server/frps/frps.toml
```

2. 檢查網絡連通性
```bash
ping 123.123.123.123
telnet 123.123.123.123 7000
```

3. 重啟客戶端
```bash
cd ~/frp/client
docker-compose restart
```

## 常見問題

### Q: 可以同時映射多個服務嗎？

A: 可以! 每個服務使用不同的子域名:

```bash
frp-domain add frontend 3000
frp-domain add backend 8080
frp-domain add api 5000
```

### Q: 支援哪些協議？

A: 目前配置支援:
- HTTP
- HTTPS
- TCP (需手動配置)

### Q: 如何查看服務端管理界面？

A: 訪問 `http://123.123.123.123:7500`
- 用戶名: `web@yourmail.domain`
- 密碼: `YOUR_DASHBOARD_PASSWORD`

注意: Dashboard 只能從服務器本地訪問 (127.0.0.1)，需要先 SSH 到服務器。

### Q: 證書多久續期一次？

A: Caddy 會自動管理證書續期，Let's Encrypt 證書有效期 90 天，Caddy 會在到期前 30 天自動續期。

### Q: 可以使用自定義域名嗎？

A: 可以，需要修改以下配置:
1. 更新 `server/.env` 中的 `DOMAIN`
2. 更新 `frp-tool` 配置中的 `DOMAIN` 變數
3. 確保 DNS 記錄指向服務器 IP

### Q: 如何移除不再使用的配置？

A: 使用 `frp-domain remove` 命令會自動清理:
- 客戶端配置 (frpc.toml)
- Caddy 反向代理規則
- HTTPS 證書會保留但不再使用

## 安全建議

1. **定期更換 Token**: 建議每季度更換一次 `FRP_TOKEN` 和 `FRP_API_TOKEN`

2. **限制訪問**: 考慮在 Caddy 配置中添加 IP 白名單或 HTTP 基本認證

3. **日誌監控**: 定期檢查異常連接或訪問模式

4. **更新軟件**: 定期更新 Docker 映像版本:
```bash
cd ~/frp/client
docker-compose pull
docker-compose up -d
```

## 技術棧

- **FRP**: v0.52.3
- **Caddy**: v2 (latest)
- **Python**: 3.11 (frp-manager)
- **Flask**: 3.0.0
- **Docker**: 20.10+
- **Docker Compose**: v2+

## 授權

本項目基於以下開源軟件:
- [frp](https://github.com/fatedier/frp) - Apache 2.0 License
- [Caddy](https://github.com/caddyserver/caddy) - Apache 2.0 License
