#!/bin/bash
# 準備安裝檔案腳本 - 將編譯好的檔案複製到 frp-docker/install-files

set -e

INSTALL_DIR="frp-docker/install-files"
# load from frp-docker/.env
source frp-docker/.env

echo "========================================"
echo "  準備安裝檔案"
echo "========================================"
echo ""

# 1. 建立目錄
echo "📁 建立安裝檔案目錄..."
mkdir -p "$INSTALL_DIR"

# 2. 編譯所有平台
echo "📦 編譯所有平台..."
./build.sh
echo ""

# 3. 複製二進位檔案
echo "📋 複製二進位檔案..."
cp dist/frp-tool-linux-amd64 "$INSTALL_DIR/"
cp dist/frp-tool-linux-arm64 "$INSTALL_DIR/"
cp dist/frp-tool-darwin-amd64 "$INSTALL_DIR/"
cp dist/frp-tool-darwin-arm64 "$INSTALL_DIR/"
cp dist/frp-tool-windows-amd64.exe "$INSTALL_DIR/"
cp dist/frp-tool-windows-arm64.exe "$INSTALL_DIR/"

# 4. 複製安裝腳本
echo "📝 複製安裝腳本..."
cp install.sh "$INSTALL_DIR/"
cp install.ps1 "$INSTALL_DIR/"

# 5. 設定權限
echo "🔐 設定權限..."
chmod 755 "$INSTALL_DIR"/*.sh
chmod 644 "$INSTALL_DIR"/*.ps1
chmod 755 "$INSTALL_DIR"/frp-tool-*
chmod 755 "$INSTALL_DIR"/*.exe 2>/dev/null || true

echo ""
echo "✅ 安裝檔案準備完成！"
echo ""
echo "檔案位置: $INSTALL_DIR/"
ls -lh "$INSTALL_DIR/"
echo ""
echo "現在可以重啟 Caddy 容器："
echo "  cd frp-docker && docker compose restart caddy"
echo ""
echo "安裝 URL："
echo "  Linux/macOS: curl -fsSL https://install.$DOMAIN/$INSTALL_DIR/install.sh | bash | sh -s -- --config https://install.$DOMAIN/$INSTALL_DIR/frpc-config.json"
echo "  Windows:     iex \"& { \$(irm https://install.$DOMAIN/$INSTALL_DIR/install.ps1) } -ConfigUrl 'https://install.$DOMAIN/$INSTALL_DIR/frpc-config.json'\""
echo ""
