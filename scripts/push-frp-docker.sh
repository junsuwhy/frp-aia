#!/bin/bash
# 從環境變數讀取或使用預設值
SERVER_IP=${FRP_SERVER_IP:-"YOUR_SERVER_IP"}
rsync -avuP ../server/* root@${SERVER_IP}:/opt/frp-server