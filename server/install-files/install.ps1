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
        $Server = $ConfigJson.server
        $Token = $ConfigJson.token
        
        if (-not $Server -or -not $Token) {
            Write-Err "配置檔案中缺少 server 或 token"
            return
        }
        
        Write-Info "✅ 配置讀取完成：Server=$Server"
    }
    catch {
        Write-Err "無法讀取配置檔案: $_"
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
Write-Info "正在執行初始化..."

try {
    & $BinaryPath init --server $Server --token $Token
    Write-Info "✅ 初始化完成！"
}
catch {
    Write-Err "初始化失敗: $_"
    return
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
