#!/bin/bash

echo "========================================="
echo "frps 連通性完整測試（使用檔案日誌）"
echo "========================================="
echo ""

DOMAIN="your-domain.com"
SUBDOMAIN="testing"
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
LOG_FILE="frps/logs/frps.log"

# 工具函式 ---------------------------------------------------------
caddy_http_request() {
    local host_header="$1"
    local header_value="${host_header:-frps}"

    docker exec -e HOST_VALUE="$header_value" caddy sh -c '
        if ! command -v nc >/dev/null 2>&1; then
            echo "nc not found inside caddy container" >&2
            exit 127
        fi
        printf "GET / HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" "$HOST_VALUE" | nc -w 5 frps 8080
    '
}

parse_http_code() {
    echo "$1" | head -n 1 | tr -d '\r' | awk '/^HTTP/{print $2}'
}

extract_http_body() {
    tr -d '\r' <<< "$1" | awk 'BEGIN{body=0} /^$/{body=1; next} body{print}' | head -10
}

# 1. 檢查 frps 是否運行
echo "【1】檢查 frps 容器狀態"
echo "---"
if docker ps | grep -q frps; then
    echo "✓ frps 容器運行中"
else
    echo "✗ frps 容器未運行"
    exit 1
fi
echo ""

# 2. 檢查日誌檔案
echo "【2】檢查日誌檔案"
echo "---"
if [ -f "$LOG_FILE" ]; then
    echo "✓ 日誌檔案存在: $LOG_FILE"
    echo "  檔案大小: $(du -h $LOG_FILE | cut -f1)"
    echo "  最後修改: $(stat -c %y $LOG_FILE 2>/dev/null || stat -f %Sm $LOG_FILE 2>/dev/null)"
else
    echo "✗ 日誌檔案不存在: $LOG_FILE"
    exit 1
fi
echo ""

# 3. 檢查 frps 配置
echo "【3】檢查 frps 配置"
echo "---"
echo "vhostHTTPPort 設定:"
grep vhostHTTPPort frps/frps.toml | sed 's/^/  /'
echo ""

# 4. 檢查埠監聽
echo "【4】檢查 frps 埠監聽"
echo "---"
echo "7000 埠 (控制埠):"
if docker exec frps netstat -tln 2>/dev/null | grep -q ":7000"; then
    echo "  ✓ 正在監聽"
else
    echo "  ✗ 未監聽"
fi

echo "8080 埠 (HTTP 虛擬主機):"
if docker exec frps netstat -tln 2>/dev/null | grep -q ":8080"; then
    echo "  ✓ 正在監聽"
else
    echo "  ✗ 未監聽"
fi
echo ""

# 5. 檢查客戶端連接
echo "【5】檢查客戶端連接狀態"
echo "---"
echo "最近的客戶端連接:"
grep "client login" "$LOG_FILE" | tail -3 | sed 's/^/  /'

CONNECTED_CLIENTS=$(grep "client login" "$LOG_FILE" | wc -l)
echo ""
echo "總連接次數: $CONNECTED_CLIENTS"

if [ "$CONNECTED_CLIENTS" -gt 0 ]; then
    echo "✓ 有客戶端曾經連接"
    
    # 檢查最近的連接
    LAST_LOGIN=$(grep "client login" "$LOG_FILE" | tail -1)
    if [ ! -z "$LAST_LOGIN" ]; then
        echo ""
        echo "最後連接:"
        echo "  $LAST_LOGIN"
    fi
else
    echo "✗ 沒有客戶端連接記錄"
    echo "  問題: VM 上的 frpc 從未成功連接"
fi
echo ""

# 6. 檢查已註冊的代理
echo "【6】檢查已註冊的代理"
echo "---"
echo "已註冊的 HTTP 代理:"
grep "http proxy listen for host" "$LOG_FILE" | tail -10 | sed 's/^/  /'

if grep -q "http proxy listen for host \[$FULL_DOMAIN\]" "$LOG_FILE"; then
    echo ""
    echo "✓ 找到 $FULL_DOMAIN 的註冊"
    
    # 顯示該代理的詳細資訊
    echo ""
    echo "該代理的完整資訊:"
    grep "\[testing\]" "$LOG_FILE" | tail -5 | sed 's/^/  /'
else
    echo ""
    echo "✗ 未找到 $FULL_DOMAIN 的註冊"
    echo ""
    echo "可能的原因:"
    echo "1. VM 上的 frpc 未連接"
    echo "2. frpc 配置的域名不正確"
    echo "3. frpc 連接失敗"
    
    # 檢查是否有其他域名
    OTHER_DOMAINS=$(grep "http proxy listen for host" "$LOG_FILE" | tail -5)
    if [ ! -z "$OTHER_DOMAINS" ]; then
        echo ""
        echo "但有找到其他域名:"
        echo "$OTHER_DOMAINS" | sed 's/^/  /'
    fi
fi
echo ""

# 7. 檢查錯誤日誌
echo "【7】檢查錯誤日誌"
echo "---"
ERRORS=$(grep "\[E\]" "$LOG_FILE" | tail -10)
if [ ! -z "$ERRORS" ]; then
    echo "⚠️  發現錯誤:"
    echo "$ERRORS" | sed 's/^/  /'
else
    echo "✓ 沒有錯誤記錄"
fi
echo ""

# 8. 測試 Caddy → frps 連接
echo "【8】測試 Caddy → frps 連接"
echo "---"

# 測試 1: 不帶 Host header
echo "測試 1: 直接訪問 (預期 404)"
RESPONSE1=$(caddy_http_request "" 2>&1)
STATUS1=$?
if [ $STATUS1 -ne 0 ]; then
    echo "  ✗ 無法透過 caddy 容器連線到 frps:8080"
    echo "  詳細: $(echo "$RESPONSE1" | head -n 2)"
else
    CODE1=$(parse_http_code "$RESPONSE1")
    if [ "$CODE1" = "404" ]; then
        echo "  ✓ 連接成功 (404 是預期的)"
    elif [ -z "$CODE1" ]; then
        echo "  ✗ 未取得 HTTP 狀態，輸出如下:"
        echo "$RESPONSE1" | head -n 5 | sed 's/^/    /'
    else
        echo "  狀態: $CODE1"
    fi
fi
echo ""

# 測試 2: 帶正確的 Host header
echo "測試 2: 帶 Host header: $FULL_DOMAIN"
RESPONSE2=$(caddy_http_request "$FULL_DOMAIN" 2>&1)
STATUS2=$?
HTTP_CODE=""
if [ $STATUS2 -ne 0 ]; then
    echo "  ✗ 無法發送請求: $(echo "$RESPONSE2" | head -n 2)"
else
    HTTP_CODE=$(parse_http_code "$RESPONSE2")
    BODY=$(extract_http_body "$RESPONSE2")
    echo "  狀態碼: ${HTTP_CODE:-未知}"

    if [ "$HTTP_CODE" = "200" ]; then
        echo "  ✓ 成功！完整路徑正常"
        if [ -n "$BODY" ]; then
            echo ""
            echo "  回應預覽:"
            echo "$BODY" | sed 's/^/    /'
        fi
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "  ✗ 404 - frps 找不到對應的代理"
        echo "  原因: 代理未註冊或域名不匹配"
    elif [ "$HTTP_CODE" = "502" ]; then
        echo "  ✗ 502 Bad Gateway"
        echo "  原因: frps 找到了代理，但無法連接到 VM 上的服務"
        echo "  檢查: VM 上的本地服務是否在運行"
    elif [ "$HTTP_CODE" = "503" ]; then
        echo "  ✗ 503 Service Unavailable"
        echo "  原因: frpc 斷線或服務不可用"
    else
        echo "  狀態: ${HTTP_CODE:-未知}"
        if [ -n "$BODY" ]; then
            echo "  回應:"
            echo "$BODY" | sed 's/^/    /'
        fi
    fi
fi
echo ""

# 9. 從外部測試
echo "【9】從外部測試完整路徑"
echo "---"
echo "測試 http://$FULL_DOMAIN"
EXT_RESPONSE=$(curl -s -w '\nHTTP_CODE:%{http_code}' -m 5 http://$FULL_DOMAIN 2>&1)
EXT_CODE=$(echo "$EXT_RESPONSE" | grep HTTP_CODE | cut -d: -f2)
echo "  狀態碼: $EXT_CODE"

if [ "$EXT_CODE" = "200" ]; then
    echo "  ✓ 外部訪問成功！"
elif [ "$EXT_CODE" = "000" ] || [ -z "$EXT_CODE" ]; then
    echo "  ✗ 無法連接"
    echo "  檢查: DNS、防火牆、Caddy"
else
    echo "  狀態: $EXT_CODE"
fi
echo ""

# 診斷總結
echo "========================================="
echo "診斷總結"
echo "========================================="
echo ""

# 判斷問題
if [ "$HTTP_CODE" = "200" ] && [ "$EXT_CODE" = "200" ]; then
    echo "🎉 系統運作完全正常！"
    echo ""
    echo "你可以訪問: http://$FULL_DOMAIN"
    
elif [ "$HTTP_CODE" = "200" ] && [ "$EXT_CODE" != "200" ]; then
    echo "⚠️  內部測試成功，但外部無法訪問"
    echo ""
    echo "問題出在外層:"
    echo "1. 檢查 DNS: dig +short $FULL_DOMAIN"
    echo "2. 檢查防火牆: sudo ufw status"
    echo "3. 檢查 Caddy: docker-compose logs caddy"
    
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  frps 找不到代理"
    echo ""
    echo "需要在 VM 上檢查 frpc:"
    echo "1. 檢查 frpc 是否運行:"
    echo "   docker ps | grep frpc"
    echo ""
    echo "2. 檢查 frpc 配置:"
    echo "   cat ~/.frp-client/frpc.toml"
    echo "   確認 customDomains = [\"$FULL_DOMAIN\"]"
    echo ""
    echo "3. 檢查 frpc 連接狀態:"
    echo "   docker logs frpc | grep login"
    echo "   或"
    echo "   tail -f ~/.frp-client/logs/frpc.log"
    
elif [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ]; then
    echo "⚠️  frps 代理已註冊，但無法連接到 VM 服務"
    echo ""
    echo "在 VM 上檢查:"
    echo "1. 本地服務是否運行:"
    echo "   curl localhost:3000  # 或你配置的埠"
    echo ""
    echo "2. frpc 日誌:"
    echo "   docker logs frpc | tail -20"
    
else
    echo "需要進一步診斷"
    echo ""
    echo "查看完整日誌:"
    echo "  tail -100 $LOG_FILE"
    echo "  docker-compose logs caddy"
fi

echo ""
echo "提示: 日誌檔案位置"
echo "  伺服器端: $LOG_FILE"
echo "  客戶端: ~/.frp-client/logs/frpc.log (如果有配置)"
echo ""
