#!/bin/bash
# 實際部署示例 - 將檔案上傳到伺服器

# 配置區
SERVER_IP="123.123.123.123"
SERVER_USER="root"
WEB_ROOT="/var/www/html"

echo "========================================"
echo "  部署到伺服器: ${SERVER_IP}"
echo "========================================"
echo ""

# 1. 編譯所有平台
echo "📦 步驟 1: 編譯所有平台..."
../cli/build.sh
echo ""

# 2. 建立部署包
echo "📦 步驟 2: 建立部署包..."
mkdir -p deploy
cp -r ../cli/dist/* deploy/
cp ../server/install-files/install.sh deploy/
cp ../server/install-files/install.ps1 deploy/
cp ../docs/config.json.example deploy/config.json

# 修改配置檔案（實際使用時填入真實值）
cat > deploy/config.json << EOF
{
  "server": "your-domain.com",
  "token": "YOUR_ACTUAL_TOKEN_HERE"
}
EOF

echo "✅ 部署包建立完成"
ls -lh deploy/
echo ""

# 3. 上傳到伺服器
echo "📤 步驟 3: 上傳到伺服器..."
echo "請執行以下命令："
echo ""
echo "# 建立目錄"
echo "ssh ${SERVER_USER}@${SERVER_IP} 'mkdir -p ${WEB_ROOT}/frp-tool'"
echo ""
echo "# 上傳檔案"
echo "scp deploy/* ${SERVER_USER}@${SERVER_IP}:${WEB_ROOT}/frp-tool/"
echo ""
echo "# 設定權限"
echo "ssh ${SERVER_USER}@${SERVER_IP} 'chmod 644 ${WEB_ROOT}/frp-tool/*'"
echo ""

# 4. 生成安裝命令
echo "========================================"
echo "✅ 部署完成！使用者安裝命令："
echo "========================================"
echo ""
echo "Linux/macOS:"
echo "curl -fsSL http://${SERVER_IP}/frp-tool/install.sh | bash -s -- --config http://${SERVER_IP}/frp-tool/config.json"
echo ""
echo "Windows:"
echo "irm http://${SERVER_IP}/frp-tool/install.ps1 | iex -ConfigUrl \"http://${SERVER_IP}/frp-tool/config.json\""
echo ""

# 5. Nginx 配置建議
echo "========================================"
echo "📝 Nginx 配置建議："
echo "========================================"
cat << 'NGINX'

location /frp-tool/ {
    alias /var/www/html/frp-tool/;
    autoindex on;
    
    # 限制存取（可選）
    # allow 203.0.113.0/24;
    # deny all;
    
    # CORS（如果需要）
    add_header Access-Control-Allow-Origin *;
}

NGINX

echo ""
echo "將上述配置新增到 /etc/nginx/sites-available/default"
echo "然後執行: sudo nginx -t && sudo systemctl reload nginx"
echo ""
