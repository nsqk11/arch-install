#!/bin/bash
# AUR 软件安装脚本：需要能访问 GitHub 时运行
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "[1/2] 正在安装百度网盘..."
paru -S --noconfirm --needed baidunetdisk-bin

log "[2/2] 正在安装微信..."
paru -S --noconfirm --needed wechat-universal-bwrap

log "AUR 软件安装完成！"
