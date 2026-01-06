#!/bin/bash
set -e

# ==========================================
# 設定區
# ==========================================
WORK_DIR="$PWD/client"
ENV_FILE="$WORK_DIR/.env"
CONFIG_FILE="$WORK_DIR/frpc.toml"

# ==========================================
# 自動載入環境變數
# ==========================================
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "錯誤: 找不到 $ENV_FILE"
    exit 1
fi

DOMAIN=${DOMAIN:-"test.mydomain.com"}

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

function log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
function log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
function log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

function generate_random_name() {
    # 產生 6 碼小寫英數混合字串
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1
}

function check_toml_format() {
    if [ -s "$CONFIG_FILE" ] && [ "$(tail -c1 "$CONFIG_FILE" | wc -l)" -eq 0 ]; then
        echo "" >> "$CONFIG_FILE"
    fi
}

function add_tunnel() {
    local local_port=$1
    local subdomain=$2
    
    # 1. 檢查 Port 是否為數字
    if ! [[ "$local_port" =~ ^[0-9]+$ ]]; then
        log_err "錯誤：Port '$local_port' 必須是數字"
        exit 1
    fi

    # 2. 如果沒有給子網域，自動產生隨機名稱
    if [ -z "$subdomain" ]; then
        subdomain=$(generate_random_name)
        log_info "未指定名稱，已自動產生：$subdomain"
    fi

    local full_domain="${subdomain}.${DOMAIN}"

    # 3. 檢查名稱是否重複
    if grep -q "name = \"$subdomain\"" "$CONFIG_FILE"; then
        log_err "錯誤：子域名設定 '$subdomain' 已存在！"
        exit 1
    fi

    # 4. 偵測 Port (僅提示)
    if ! nc -z 127.0.0.1 $local_port 2>/dev/null; then
        log_warn "注意：本地 Port $local_port 目前似乎沒有服務在執行"
    fi

    # 5. 寫入設定
    check_toml_format
    cat >> "$CONFIG_FILE" << PROXY

[[proxies]]
name = "$subdomain"
type = "http"
localIP = "127.0.0.1"
localPort = $local_port
customDomains = ["$full_domain"]
PROXY

    # 6. 重啟與暖身
    log_info "正在重啟 frpc..."
    cd "$WORK_DIR"
    docker compose restart frpc

    log_info "正在觸發 HTTPS 申請..."
    # 背景觸發，不等待
    curl -I -s --max-time 3 "https://${full_domain}" > /dev/null || true
    
    echo ""
    echo -e "${CYAN}=== 部署完成 ===${NC}"
    echo -e "名稱 (Name) : ${YELLOW}$subdomain${NC}  (移除時請用此名稱)"
    echo -e "本地 Port   : $local_port"
    echo -e "公開網址    : ${GREEN}https://${full_domain}${NC}"
    echo ""
}

function remove_tunnel() {
    local subdomain=$1
    
    if [ -z "$subdomain" ]; then
        log_err "請輸入要移除的名稱 (Name)"
        exit 1
    fi

    if ! grep -q "name = \"$subdomain\"" "$CONFIG_FILE"; then
        log_err "找不到名稱為 '$subdomain' 的設定"
        exit 1
    fi

    log_info "正在移除： $subdomain"

    # Python 精準移除區塊
    python3 -c "
import sys
file_path = '$CONFIG_FILE'
target = '$subdomain'

with open(file_path, 'r') as f: lines = f.readlines()

new_lines = []
block_buffer = []

for line in lines:
    if line.strip().startswith('[[proxies]]'):
        if block_buffer:
            content = ''.join(block_buffer)
            if f'name = \"{target}\"' not in content and f'name = \'{target}\'' not in content:
                new_lines.append(content)
        block_buffer = [line]
    else:
        if not block_buffer: new_lines.append(line)
        else: block_buffer.append(line)

if block_buffer:
    content = ''.join(block_buffer)
    if f'name = \"{target}\"' not in content and f'name = \'{target}\'' not in content:
        new_lines.append(content)

with open(file_path, 'w') as f: f.write(''.join(new_lines))
"

    cd "$WORK_DIR"
    docker compose restart frpc
    log_info "✅ 已移除"
}

function list_tunnels() {
    echo ""
    echo -e "${CYAN}=== 活躍通道列表 ===${NC}"
    printf "%-15s %-10s %-35s\n" "名稱 (ID)" "Port" "網址"
    echo "------------------------------------------------------------"
    
    grep -A 4 "\[\[proxies\]\]" "$CONFIG_FILE" | \
    awk -v d="$DOMAIN" '
    /name =/ { gsub(/"/,""); name=$3 }
    /localPort =/ { port=$3 }
    /customDomains =/ { 
        print name, port, "https://" name "." d
    }
    ' | xargs -L 1 printf "%-15s %-10s %-35s\n"
    echo ""
}

function show_usage() {
    cat << EOF
frp-client 通道管理工具

用法:
  frp-client add <port> [name]    新增通道 (Name 可選，若不填則隨機)
  frp-client rm <name>            移除通道 (需輸入 Name)
  frp-client ls                   列出列表

範例:
  frp-client add 3000             -> 隨機產生 xxx.domain.com -> 本地 3000
  frp-client add 8080 myapi       -> 指定 myapi.domain.com -> 本地 8080
  frp-client rm myapi             -> 移除 myapi
EOF
}

case "${1:-}" in
    add)
        [ -z "$2" ] && { log_err "請指定 Port"; show_usage; exit 1; }
        add_tunnel "$2" "$3"
        ;;
    rm|remove)
        remove_tunnel "$2"
        ;;
    ls|list)
        list_tunnels
        ;;
    *)
        show_usage
        ;;
esac