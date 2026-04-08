#!/bin/bash
# Arch Linux 自动安装脚本 — 第三步：重启后以普通用户运行
# 用户级配置：zsh 环境、snapper 初始化、防火墙规则
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }
skip() { log "  ↳ 已完成，跳过。"; }
DONE_DIR="$HOME/.local/state/arch-install"
mkdir -p "$DONE_DIR"
done_check() { [[ -f "$DONE_DIR/$1" ]]; }
done_mark() { touch "$DONE_DIR/$1"; }

TOTAL=4

# --- [1] snapper 初始化 ---
if done_check snapper; then
  log "[1/$TOTAL] snapper"; skip
else
  log "[1/$TOTAL] 正在初始化 snapper..."
  sudo pacman -S --noconfirm --needed snapper
  if [[ ! -f /etc/snapper/configs/root ]]; then
    sudo snapper -c root create-config /
    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer
  fi
  done_mark snapper
fi

# --- [2] zsh 配置 ---
if done_check zsh; then
  log "[2/$TOTAL] zsh"; skip
else
  log "[2/$TOTAL] 正在配置 zsh 环境..."
  sudo pacman -S --noconfirm --needed zsh-syntax-highlighting zsh-autosuggestions \
    zsh-completions zsh-history-substring-search fzf pkgfile
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
  done_mark zsh
fi

# --- [3] 防火墙规则 ---
if done_check ufw; then
  log "[3/$TOTAL] 防火墙"; skip
else
  log "[3/$TOTAL] 正在配置防火墙（KDE Connect 端口）..."
  sudo ufw allow 1714:1764/udp
  sudo ufw allow 1714:1764/tcp
  done_mark ufw
fi

# --- [4] 首次快照 ---
if done_check snapshot; then
  log "[4/$TOTAL] 首次快照"; skip
else
  log "[4/$TOTAL] 正在创建首次系统快照..."
  sudo snapper -c root create -d "post-install 完成"
  done_mark snapshot
fi

# --- 完成 ---
log "安装完成！"
echo ""
echo "提示："
echo "  - 输入法：运行 fcitx5-configtool，添加拼音输入法"
echo "  - AUR 软件：有 GitHub 访问时运行 ~/arch-install/aur-install.sh"
echo "  - 夸克网盘：浏览器访问 https://pan.quark.cn"
echo "  - Samba 挂载：sudo mount -t cifs //树莓派IP/共享名 /mnt/nas -o username=用户名,password=密码,uid=1000,gid=1000"
