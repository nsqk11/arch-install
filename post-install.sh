#!/bin/bash
# 安装后脚本：首次启动后以普通用户运行
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- 安装 yay ---
if ! command -v yay &>/dev/null; then
  log "[1/5] 正在安装 yay..."
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
else
  log "[1/5] yay 已安装，跳过。"
fi

# --- 安装用户软件 ---
log "[2/5] 正在安装应用（百度网盘、微信）..."
yay -S --noconfirm baidunetdisk-bin wechat-universal-bwrap

# --- 配置防火墙规则 ---
log "[3/5] 正在配置防火墙（KDE Connect 端口）..."
sudo ufw allow 1714:1764/udp
sudo ufw allow 1714:1764/tcp

# --- 安装 HyDE ---
log "[4/5] 正在安装 HyDE (Hyprland 桌面)，这一步耗时较长..."
if [[ ! -d ~/HyDE ]]; then
  git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE
fi
cd ~/HyDE/Scripts
./install.sh

# --- 完成 ---
log "[5/5] 安装完成！重启后即可使用 Hyprland。"
echo ""
echo "提示："
echo "  - 输入法：运行 fcitx5-configtool，添加拼音输入法"
echo "  - 夸克网盘：使用浏览器访问 https://pan.quark.cn"
echo "  - 系统快照：运行 sudo timeshift --create 创建第一个快照"
