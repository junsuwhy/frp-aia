#!/bin/bash
# 跨平台編譯腳本 - 在 Ubuntu 下編譯 Linux/macOS/Windows 版本並複製到安裝目錄

set -e

VERSION=${VERSION:-"v1.0.0"}
OUTPUT_DIR="dist"
INSTALL_DIR="../server/install-files"

echo "🚀 開始編譯 frp-tool ${VERSION}"
echo "=================================="

# 清理舊的編譯產物
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}
mkdir -p ${INSTALL_DIR}

# 編譯函數
build() {
    local GOOS=$1
    local GOARCH=$2
    local OUTPUT_NAME=$3
    
    echo "📦 編譯 ${GOOS}/${GOARCH}..."
    
    GOOS=${GOOS} GOARCH=${GOARCH} go build \
        -ldflags "-s -w -X main.Version=${VERSION}" \
        -o ${OUTPUT_DIR}/${OUTPUT_NAME} \
        main.go
    
    echo "✅ ${OUTPUT_NAME} 完成"
}

# Linux
build linux amd64 frp-tool-linux-amd64
build linux arm64 frp-tool-linux-arm64

# macOS
build darwin amd64 frp-tool-darwin-amd64
build darwin arm64 frp-tool-darwin-arm64

# Windows
build windows amd64 frp-tool-windows-amd64.exe
build windows arm64 frp-tool-windows-arm64.exe

echo ""
echo "=================================="
echo "✅ 編譯完成！產物位於 ${OUTPUT_DIR}/"
ls -lh ${OUTPUT_DIR}/
echo ""

# 複製到安裝目錄
echo "📋 複製檔案到安裝目錄..."
cp -f ${OUTPUT_DIR}/* ${INSTALL_DIR}/

# 複製安裝腳本（如果存在）
if [ -f "../server/install-files/install.sh" ] && [ -f "../server/install-files/install.ps1" ]; then
    echo "📝 安裝腳本已存在"
else
    echo "⚠️  警告：安裝腳本不存在，請手動複製"
fi

# 設定權限
echo "🔐 設定權限..."
chmod 755 ${INSTALL_DIR}/frp-tool-* 2>/dev/null || true
chmod 755 ${INSTALL_DIR}/*.exe 2>/dev/null || true
chmod 755 ${INSTALL_DIR}/*.sh 2>/dev/null || true
chmod 644 ${INSTALL_DIR}/*.ps1 2>/dev/null || true

echo ""
echo "✅ 所有檔案已複製到 ${INSTALL_DIR}/"
ls -lh ${INSTALL_DIR}/
echo ""
echo "提示："
echo "  - 如需重啟 Caddy: cd ../server && docker compose restart caddy"
echo ""
