#!/bin/bash
# 安装后脚本：首次启动后以普通用户运行
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- 安装 paru（来自 archlinuxcn）---
if ! command -v paru &>/dev/null; then
  log "[1/6] 正在安装 paru..."
  sudo pacman -S --noconfirm paru
else
  log "[1/6] paru 已安装，跳过。"
fi

# --- 安装 AUR / 32 位软件 ---
log "[2/6] 正在安装 snapper、oh-my-zsh、32 位显卡库..."
sudo pacman -S --noconfirm --needed snapper

log "[3/6] 正在安装 oh-my-zsh 和 32 位 Mesa/Vulkan..."
sudo pacman -S --noconfirm --needed oh-my-zsh-git zsh-theme-powerlevel10k zsh-syntax-highlighting zsh-autosuggestions zsh-completions zsh-history-substring-search fzf pkgfile lib32-mesa lib32-vulkan-radeon
sudo pkgfile --update
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
cat >> ~/.zshrc <<'EOF'
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh
source /usr/share/doc/pkgfile/command-not-found.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
EOF

# --- 配置防火墙规则 ---
log "[4/5] 正在配置防火墙（KDE Connect 端口）..."
sudo ufw allow 1714:1764/udp
sudo ufw allow 1714:1764/tcp

# --- 完成 ---
log "安装完成！"
echo ""
echo "提示："
echo "  - 输入法：运行 fcitx5-configtool，添加拼音输入法"
echo "  - 夸克网盘：使用浏览器访问 https://pan.quark.cn"
echo "  - 系统快照：运行 sudo snapper -c root create -d \"首次快照\""
echo "  - Samba 挂载：sudo mount -t cifs //树莓派IP/共享名 /mnt/nas -o username=用户名,password=密码,uid=1000,gid=1000"
