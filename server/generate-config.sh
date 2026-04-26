#!/bin/bash
# 從範本生成實際配置檔

set -e

# 載入環境變數
if [ ! -f .env ]; then
    echo "錯誤: .env 檔案不存在"
    echo "請先複製 .env.example 為 .env 並修改設定"
    exit 1
fi

# 載入 .env 並匯出變數
export $(grep -v '^#' .env | xargs)

# 生成 frps.toml
envsubst < frps/frps.toml.template > frps.toml
echo "✓ 已生成 frps.toml"

# 生成 install.sh（將 DOMAIN 和 INSTALL_PATH 填入 SERVER_URL）
envsubst '${DOMAIN} ${INSTALL_PATH}' < install-files/install.sh.template > install-files/install.sh
chmod +x install-files/install.sh
echo "✓ 已生成 install-files/install.sh"

echo "配置檔案生成完成！"
