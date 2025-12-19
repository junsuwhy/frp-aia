#!/bin/bash
# 從範本生成實際配置檔

set -e

# 載入環境變數
if [ ! -f .env ]; then
    echo "錯誤: .env 檔案不存在"
    echo "請先複製 .env.example 為 .env 並修改設定"
    exit 1
fi

# source .env

# 生成 frps.toml
export $(grep -v '^#' .env | xargs) && envsubst < frps/frps.toml.template > frps.toml
echo "✓ 已生成 frps/frps.toml"

# 生成 Caddyfile（如果需要動態內容）
# envsubst < caddy/Caddyfile.template > caddy/Caddyfile
# echo "✓ 已生成 caddy/Caddyfile"

echo "配置檔案生成完成！"
