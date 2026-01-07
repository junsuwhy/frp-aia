# FRP Tool 安裝腳本 (Windows PowerShell)
# 用法:
#   方式 1: iex "& { $(irm https://your-domain.com/frp-install/install.ps1) } -Server 'test.domain.com' -Token 'abc123'"
#   方式 2: iex "& { $(irm https://your-domain.com/frp-install/install.ps1) } -ConfigUrl 'https://your-domain.com/frp-install/frpc-config.json'"
#   方式 3: irm https://your-domain.com/frp-install/install.ps1 | iex  (互動式輸入)

param(
    [string]$Server = "",
    [string]$Token = "",
    [string]$ConfigUrl = ""
)

# ==========================================
# 設定區
# ==========================================
$ServerUrl = ""  # 將從 ConfigUrl 自動推斷
$Version = "latest"
$InstallDir = "$env:LOCALAPPDATA\frp-tool"
$BinaryName = "frp-tool.exe"

# ==========================================
# 顏色輸出函數
# ==========================================
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# ==========================================
# 從 URL 讀取配置
# ==========================================
if ($ConfigUrl) {
    Write-Info "從 $ConfigUrl 讀取配置..."
    
    # 從 ConfigUrl 推斷 ServerUrl (移除檔案名稱)
    $ServerUrl = $ConfigUrl.Substring(0, $ConfigUrl.LastIndexOf('/'))
    Write-Info "使用伺服器 URL: $ServerUrl"
    
    try {
        $ConfigJson = Invoke-RestMethod -Uri $ConfigUrl -UseBasicParsing
        
        # 讀取 server
        $Server = $ConfigJson.server
        
        # 優先使用 token_encoded (base64 編碼)，如果沒有則使用 token
        $TokenEncoded = $ConfigJson.token_encoded
        $Token = $ConfigJson.token
        
        # 如果有 token_encoded，則解碼它
        if ($TokenEncoded) {
            try {
                $TokenBytes = [Convert]::FromBase64String($TokenEncoded)
                $Token = [System.Text.Encoding]::UTF8.GetString($TokenBytes)
                Write-Info "已從 token_encoded 解碼 token"
            }
            catch {
                Write-Err "無法解碼 token_encoded: $_"
                return
            }
        }
        
        # 驗證必要欄位
        if (-not $Server) {
            Write-Err "配置檔案中缺少 server 欄位"
            Write-Err "配置內容: $($ConfigJson | ConvertTo-Json -Compress)"
            return
        }
        
        if (-not $Token) {
            Write-Err "配置檔案中缺少 token 或 token_encoded 欄位"
            Write-Err "配置內容: $($ConfigJson | ConvertTo-Json -Compress)"
            return
        }
        
        Write-Info "✅ 配置讀取完成：Server=$Server"
    }
    catch {
        Write-Err "無法讀取配置檔案: $_"
        Write-Err "請確認 URL 可訪問且返回有效的 JSON 格式"
        return
    }
}

# ==========================================
# 互動式輸入（如果未提供參數）
# ==========================================
if (-not $Server) {
    $Server = Read-Host "請輸入 FRP 伺服器域名"
}

if (-not $Token) {
    $Token = Read-Host "請輸入驗證 Token"
}

# ==========================================
# 檢測系統架構
# ==========================================
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    $Arch = "arm64"
}

Write-Info "檢測到系統: Windows/$Arch"

# ==========================================
# 下載二進位檔案
# ==========================================
if (-not $ServerUrl) {
    Write-Err "無法確定下載位址，請使用 -ConfigUrl 參數"
    return
}

$BinaryUrl = "$ServerUrl/frp-tool-windows-$Arch.exe"

Write-Info "下載 $BinaryName 從 $BinaryUrl..."

try {
    # 建立安裝目錄
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    
    $BinaryPath = Join-Path $InstallDir $BinaryName
    
    # 下載
    Invoke-WebRequest -Uri $BinaryUrl -OutFile $BinaryPath -UseBasicParsing
    
    Write-Info "✅ 二進位檔案下載完成"
}
catch {
    Write-Err "下載失敗: $_"
    return
}

# ==========================================
# 新增到 PATH
# ==========================================
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$InstallDir*") {
    Write-Info "新增到 PATH..."
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$CurrentPath;$InstallDir",
        "User"
    )
    $env:Path = "$env:Path;$InstallDir"
    Write-Info "✅ 已新增到 PATH (重啟終端機後生效)"
}

# ==========================================
# 檢查 Docker
# ==========================================
Write-Info "檢查 Docker..."
try {
    $null = docker --version
}
catch {
    Write-Warn "未檢測到 Docker，請先安裝 Docker Desktop"
    Write-Warn "訪問: https://docs.docker.com/desktop/install/windows-install/"
    return
}

# ==========================================
# 執行初始化
# ==========================================
$ClientDir = "$env:USERPROFILE\.frp-client"
$ConfigFile = "$ClientDir\frpc.toml"
$OldProxies = $null
$HasProxies = $false

# 檢查是否已經安裝過且配置檔案存在
if (Test-Path $ClientDir) {
    if (Test-Path $ConfigFile) {
        Write-Warn "檢測到已存在的配置檔案: $ConfigFile"
        
        # 提取現有的 [[proxies]] 配置（使用文本處理）
        try {
            $ConfigLines = Get-Content $ConfigFile
            $InProxiesBlock = $false
            $ProxiesLines = @()
            
            foreach ($line in $ConfigLines) {
                # 檢測到 [[proxies]] 開始
                if ($line -match '^\[\[proxies\]\]') {
                    $InProxiesBlock = $true
                    $ProxiesLines += $line
                    continue
                }
                
                # 如果在 proxies 區塊中
                if ($InProxiesBlock) {
                    # 如果遇到新的頂級區塊（以 [[ 開頭但不是 [[proxies]]），停止
                    if ($line -match '^\[\[' -and $line -notmatch '^\[\[proxies\]\]') {
                        break
                    }
                    $ProxiesLines += $line
                }
            }
            
            if ($ProxiesLines.Count -gt 0) {
                # 檢查是否真的有內容（不只是 [[proxies]] 標題）
                $HasContent = $false
                foreach ($line in $ProxiesLines) {
                    if ($line -notmatch '^\[\[proxies\]\]$' -and $line.Trim() -ne '') {
                        $HasContent = $true
                        break
                    }
                }
                
                if ($HasContent) {
                    $OldProxies = $ProxiesLines -join "`n"
                    $HasProxies = $true
                    Write-Info "檢測到現有的通道配置，將在初始化後保留"
                }
            }
        }
        catch {
            Write-Warn "無法讀取現有配置: $_"
        }
    }
}

Write-Info "正在執行初始化..."

try {
    & $BinaryPath init --server $Server --token $Token
    Write-Info "✅ 初始化完成！"
}
catch {
    Write-Err "初始化失敗: $_"
    return
}

# 如果有舊的 proxies 配置，合併回去
if ($HasProxies -and $OldProxies) {
    Write-Info "正在合併現有的通道配置..."
    
    try {
        # 讀取新的配置檔案
        $NewConfigLines = Get-Content $ConfigFile
        
        # 移除新配置中的 proxies = [] 行（避免與 [[proxies]] 衝突）
        $FilteredLines = $NewConfigLines | Where-Object { $_ -notmatch '^proxies = \[\]$' }
        
        # 寫回過濾後的配置
        $FilteredLines | Set-Content -Path $ConfigFile
        
        # 追加舊的 [[proxies]] 配置
        Add-Content -Path $ConfigFile -Value ""
        Add-Content -Path $ConfigFile -Value $OldProxies
        
        Write-Info "✅ 已成功合併現有通道配置"
    }
    catch {
        Write-Warn "合併配置時發生錯誤: $_"
        Write-Warn "舊的通道配置可能未完全保留，請手動檢查 $ConfigFile"
    }
}

# ==========================================
# 顯示使用說明
# ==========================================
Write-Host ""
Write-Host "=== FRP Tool 安裝完成 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "快速開始:"
Write-Host "  1. 新增通道:  frp-tool add 3000"
Write-Host "  2. 列出通道:  frp-tool ls"
Write-Host "  3. 移除通道:  frp-tool rm <name>"
Write-Host ""
Write-Host "配置位置: $env:USERPROFILE\.frp-client\"
Write-Host ""
Write-Host "注意: 如果命令找不到，請重啟 PowerShell 終端機"
Write-Host ""
