# FRP Tool - 快速安裝指南

一個跨平台的 FRP 客戶端管理工具，支援 Linux、macOS 和 Windows。

## 🚀 快速安裝

### Linux / macOS

**方式 1: 直接傳參安裝**
```bash
curl -fsSL https://your-domain.com/install.sh | bash -s -- --server test.domain.com --token abc123
```

**方式 2: 從 URL 讀取配置（推薦）**
```bash
curl -fsSL https://your-domain.com/install.sh | bash -s -- --config https://your-domain.com/config.json
```

**方式 3: 互動式安裝**
```bash
curl -fsSL https://your-domain.com/install.sh | bash
```

### Windows (PowerShell)

**方式 1: 直接傳參安裝**
```powershell
irm https://your-domain.com/install.ps1 | iex -ArgumentList "-Server test.domain.com -Token abc123"
```

**方式 2: 從 URL 讀取配置（推薦）**
```powershell
$params = @{Server=""; Token=""; ConfigUrl="https://your-domain.com/config.json"}
irm https://your-domain.com/install.ps1 | iex @params
```

**方式 3: 下載後運行**
```powershell
Invoke-WebRequest -Uri https://your-domain.com/install.ps1 -OutFile install.ps1
.\install.ps1 -Server "test.domain.com" -Token "abc123"
```

## 📦 配置檔案格式 (config.json)

將此檔案托管在您的伺服器上（例如：`https://123.123.123.123/config.json`）：

```json
{
  "server": "testdomain.ccom",
  "token": "your_secret_token_here"
}
```

## 🔧 使用示例

安裝完成後：

```bash
# 新增通道（自動生成名稱）
frp-tool add 3000

# 新增通道（指定名稱）
frp-tool add 8080 myapp

# 列出所有通道
frp-tool ls

# 移除通道
frp-tool rm myapp
```

## 🧹 解除安裝（Uninstall frp-client）

`frp-client`（本機 FRP client）是透過 Docker Compose 跑 `frpc`；解除安裝就是**停掉容器 + 刪掉工作目錄 + 移除 frp-tool**。

### Linux / macOS

```bash
# 1) 到安裝時所在目錄（會有 client/；部分舊版可能叫 frp-client/）
cd /path/to/your/install-dir/client 2>/dev/null || cd /path/to/your/install-dir/frp-client

# 2) 停止並移除 frpc 容器
docker compose down

# 3) 刪掉本機設定與日誌
cd ..
rm -rf client frp-client

# 4) 移除安裝的 CLI（install.sh 預設裝在 /usr/local/bin）
sudo rm -f /usr/local/bin/frp-tool
```

### Windows (PowerShell)

```powershell
# 1) 到安裝時所在目錄（會有 client\；部分舊版可能叫 frp-client\）
Set-Location ".\client" -ErrorAction SilentlyContinue; if (-not $?) { Set-Location ".\frp-client" }

# 2) 停止並移除 frpc 容器
docker compose down

# 3) 刪掉本機設定與日誌
Set-Location ..
Remove-Item -Recurse -Force .\client, .\frp-client -ErrorAction SilentlyContinue

# 4) 移除 frp-tool
Remove-Item -Force "$env:LOCALAPPDATA\frp-tool\frp-tool.exe" -ErrorAction SilentlyContinue
```

## 🛠️ 開發者指南

### 本地編譯

#### 編譯當前平台
```bash
go build -o frp-tool main.go
```

#### 跨平台編譯（在 Ubuntu 下編譯 Windows 版本）
```bash
# 編譯 Windows 64位
GOOS=windows GOARCH=amd64 go build -o frp-tool-windows-amd64.exe main.go

# 編譯所有平台
./build.sh
```

### 編譯產物說明

執行 `./build.sh` 後會生成：

```
dist/
├── frp-tool-linux-amd64        # Linux x64
├── frp-tool-linux-arm64        # Linux ARM64
├── frp-tool-darwin-amd64       # macOS Intel
├── frp-tool-darwin-arm64       # macOS Apple Silicon
├── frp-tool-windows-amd64.exe  # Windows x64
└── frp-tool-windows-arm64.exe  # Windows ARM64
```

### Windows 編譯說明

**重要**: 
- `.exe` 是編譯出來的可執行檔案（binary）
- `.ps1` 是 PowerShell 腳本（不需要編譯）
- 可以在 Ubuntu 下使用 Go 的交叉編譯功能生成 Windows .exe

```bash
# 在 Ubuntu 下編譯 Windows 程式
GOOS=windows GOARCH=amd64 go build -o frp-tool.exe main.go
```

## 📋 部署清單

要部署完整的安裝系統，您需要：

1. **編譯二進位檔案**
   ```bash
   ./build.sh
   ```

2. **上傳到 GitHub Releases** 或您的伺服器

3. **托管安裝腳本**
   - `install.sh` (Linux/macOS)
   - `install.ps1` (Windows)

4. **托管配置檔案**
   - `config.json` (包含 server 和 token)

5. **更新腳本中的 URL**
   - 修改 `install.sh` 和 `install.ps1` 中的 `GITHUB_REPO` 變數
   - 或修改直接下載 URL

## 🔐 安全建議

1. **配置檔案存取控制**
   ```bash
   # 使用 nginx 限制存取
   location /config.json {
       allow 203.0.113.0/24;  # 僅允許特定 IP
       deny all;
   }
   ```

2. **HTTPS 傳輸**
   - 確保所有下載連結使用 HTTPS
   - 配置檔案應透過 HTTPS 提供

3. **Token 管理**
   - 定期輪換 token
   - 為不同使用者生成不同的 config.json

## 🎯 實際使用示例

假設您的伺服器是 `123.123.123.123`：

1. **準備配置檔案**
   ```bash
   # 在伺服器上建立 /var/www/html/frp-config.json
   {
     "server": "frp.example.com",
     "token": "secret-token-12345"
   }
   ```

2. **使用者安裝（Linux）**
   ```bash
   curl -fsSL http://123.123.123.123/install.sh | bash -s -- --config http://123.123.123.123/frp-config.json
   ```

3. **使用者安裝（Windows）**
   ```powershell
   irm http://123.123.123.123/install.ps1 | iex -ConfigUrl "http://123.123.123.123/frp-config.json"
   ```

## 📝 命令參考

| 命令 | 說明 | 示例 |
|------|------|------|
| `init` | 初始化環境 | `frp-tool init --server domain.com --token xxx` |
| `add` | 新增通道 | `frp-tool add 3000 myapp` |
| `rm` | 移除通道 | `frp-tool rm myapp` |
| `ls` | 列出通道 | `frp-tool ls` |

## 🐛 故障排除

### Docker 未安裝
```bash
# Linux
curl -fsSL https://get.docker.com | sh

# macOS
brew install --cask docker

# Windows
# 下載 Docker Desktop: https://docs.docker.com/desktop/install/windows-install/
```

### 權限錯誤
```bash
# Linux/macOS: 使用 sudo
sudo curl -fsSL https://your-domain.com/install.sh | sudo bash -s -- --server xxx --token yyy
```

### 找不到命令 (Windows)
- 重啟 PowerShell 終端機
- 或手動新增到 PATH：`$env:Path += ";$env:LOCALAPPDATA\frp-tool"`

## 📄 授權認證

MIT License
