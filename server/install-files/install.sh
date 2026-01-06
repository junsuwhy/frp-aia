#!/bin/bash
# FRP Tool 安裝腳本 (Linux/macOS)
# 用法:
#   方式 1: curl -fsSL https://your-domain.com/frp-install/install.sh | bash -s -- --server test.domain.com --token abc123
#   方式 2: curl -fsSL https://your-domain.com/frp-install/install.sh | bash -s -- --config https://your-domain.com/frp-install/frpc-config.json
#   方式 3: curl -fsSL https://your-domain.com/frp-install/install.sh | bash  (互動式輸入)

set -e

# ==========================================
# 設定區
# ==========================================
SERVER_URL="https://install.your-domain.com/frp-install"  # 請替換為您的伺服器 URL
VERSION="latest"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="frp-tool"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==========================================
# 參數解析
# ==========================================
SERVER=""
TOKEN=""
CONFIG_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --server|-s)
            SERVER="$2"
            shift 2
            ;;
        --token|-t)
            TOKEN="$2"
            shift 2
            ;;
        --config|-c)
            CONFIG_URL="$2"
            shift 2
            ;;
        *)
            log_error "未知參數: $1"
            exit 1
            ;;
    esac
done

# ==========================================
# 從 URL 讀取配置
# ==========================================
if [ -n "$CONFIG_URL" ]; then
    log_info "從 ${CONFIG_URL} 讀取配置..."
    
    # 從 CONFIG_URL 推斷 SERVER_URL (移除檔案名稱)
    SERVER_URL="${CONFIG_URL%/*}"
    log_info "使用伺服器 URL: ${SERVER_URL}"
    
    # 下載配置檔案
    CONFIG_JSON=$(curl -fsSL "$CONFIG_URL")
    
    # 解析 JSON (使用 jq 或 python)
    if command -v jq &> /dev/null; then
        SERVER=$(echo "$CONFIG_JSON" | jq -r '.server // empty')
        TOKEN_ENCODED=$(echo "$CONFIG_JSON" | jq -r '.token_encoded // empty')
    elif command -v python3 &> /dev/null; then
        SERVER=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('server', ''))")
        TOKEN_ENCODED=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('token_encoded', ''))")
    else
        log_error "需要 jq 或 python3 來解析 JSON 配置"
        exit 1
    fi
    
    # 解碼 base64 token
    if [ -n "$TOKEN_ENCODED" ]; then
        TOKEN=$(echo "$TOKEN_ENCODED" | base64 -d 2>/dev/null || echo "")
    fi
    
    if [ -z "$SERVER" ] || [ -z "$TOKEN" ]; then
        log_error "配置檔案中缺少 server 或 token"
        exit 1
    fi
    
    log_info "✅ 配置讀取完成：Server=${SERVER}"
fi

# ==========================================
# 互動式輸入（如果未提供參數）
# ==========================================
if [ -z "$SERVER" ]; then
    echo -n "請輸入 FRP 伺服器域名: "
    read SERVER
fi

if [ -z "$TOKEN" ]; then
    echo -n "請輸入驗證 Token: "
    read TOKEN
fi

# ==========================================
# 檢測系統架構
# ==========================================
detect_os_arch() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case "$OS" in
        linux)
            OS="linux"
            ;;
        darwin)
            OS="darwin"
            ;;
        *)
            log_error "不支援的作業系統: $OS"
            exit 1
            ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "不支援的架構: $ARCH"
            exit 1
            ;;
    esac
    
    log_info "檢測到系統: ${OS}/${ARCH}"
}

# ==========================================
# 下載二進位檔案
# ==========================================
download_binary() {
    local BINARY_URL="${SERVER_URL}/${BINARY_NAME}-${OS}-${ARCH}"
    
    log_info "下載 ${BINARY_NAME} 從 ${BINARY_URL}..."
    
    # 建立臨時目錄
    TMP_DIR=$(mktemp -d)
    TMP_FILE="${TMP_DIR}/${BINARY_NAME}"
    
    # 下載
    if ! curl -fsSL -o "$TMP_FILE" "$BINARY_URL"; then
        log_error "下載失敗！請檢查網路連線或伺服器位址"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # 新增執行權限
    chmod +x "$TMP_FILE"
    
    # 移動到安裝目錄
    log_info "安裝到 ${INSTALL_DIR}/${BINARY_NAME}..."
    if [ -w "$INSTALL_DIR" ]; then
        mv "$TMP_FILE" "${INSTALL_DIR}/${BINARY_NAME}"
    else
        sudo mv "$TMP_FILE" "${INSTALL_DIR}/${BINARY_NAME}"
    fi
    
    rm -rf "$TMP_DIR"
    log_info "✅ 二進位檔案安裝完成"
}

# ==========================================
# 執行初始化
# ==========================================
run_init() {
    log_info "正在執行初始化..."
    
    # 檢查 Docker
    if ! command -v docker &> /dev/null; then
        log_warn "未檢測到 Docker，請先安裝 Docker"
        log_warn "訪問: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # 執行 init
    if ! frp-tool init --server "$SERVER" --token "$TOKEN"; then
        log_error "初始化失敗"
        exit 1
    fi
    
    log_info "✅ 初始化完成！"
}

# ==========================================
# 顯示使用說明
# ==========================================
show_usage() {
    echo ""
    echo -e "${CYAN}=== FRP Tool 安裝完成 ===${NC}"
    echo ""
    echo "快速開始:"
    echo "  1. 新增通道:  frp-tool add 3000"
    echo "  2. 列出通道:  frp-tool ls"
    echo "  3. 移除通道:  frp-tool rm <name>"
    echo ""
    echo "配置位置: $(pwd)/client/"
    echo ""
}

# ==========================================
# 主流程
# ==========================================
main() {
    log_info "開始安裝 FRP Tool..."
    
    detect_os_arch
    download_binary
    run_init
    show_usage
}

main
