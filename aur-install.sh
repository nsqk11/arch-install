#!/bin/bash
# AUR 软件安装脚本：需要能访问 GitHub 时运行
# Usage: ~/arch-install/aur-install.sh
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "[$(date '+%H:%M:%S')] ${GREEN}$*${NC}"; }

if ! command -v paru &>/dev/null; then
  echo -e "${RED}错误：paru 未安装，请先运行 post-install.sh。${NC}" >&2; exit 1
fi

log "[1/2] 正在安装百度网盘..."
paru -S --noconfirm --needed baidunetdisk-bin

log "[2/2] 正在安装微信..."
paru -S --noconfirm --needed wechat-universal-bwrap

log "AUR 软件安装完成！"
