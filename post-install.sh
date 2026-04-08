#!/bin/bash
# 安装后脚本：首次启动后以普通用户运行
# 支持断点续跑：已完成的步骤自动跳过
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }
skip() { log "  ↳ 已完成，跳过。"; }
DONE_DIR="$HOME/.local/state/arch-install"
mkdir -p "$DONE_DIR"
done_check() { [[ -f "$DONE_DIR/$1" ]]; }
done_mark() { touch "$DONE_DIR/$1"; }

TOTAL=5

# --- [1] 安装 paru（来自 archlinuxcn）---
if done_check paru; then
  log "[1/$TOTAL] paru"; skip
elif command -v paru &>/dev/null; then
  log "[1/$TOTAL] paru 已安装。"; done_mark paru
else
  log "[1/$TOTAL] 正在安装 paru..."
  sudo pacman -S --noconfirm paru
  done_mark paru
fi

# --- [2] snapper + 32 位显卡库 ---
if done_check packages; then
  log "[2/$TOTAL] 系统包"; skip
else
  log "[2/$TOTAL] 正在安装 snapper、32 位显卡库..."
  sudo pacman -S --noconfirm --needed snapper lib32-mesa lib32-vulkan-radeon steam
  # snapper 初始化
  if [[ ! -f /etc/snapper/configs/root ]]; then
    sudo snapper -c root create-config /
    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer
  fi
  done_mark packages
fi

# --- [3] oh-my-zsh + 插件 ---
if done_check zsh; then
  log "[3/$TOTAL] zsh 配置"; skip
else
  log "[3/$TOTAL] 正在配置 zsh 环境..."
  sudo pacman -S --noconfirm --needed oh-my-zsh-git zsh-theme-powerlevel10k \
    zsh-syntax-highlighting zsh-autosuggestions zsh-completions \
    zsh-history-substring-search fzf pkgfile
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

# --- [4] 防火墙规则 ---
if done_check ufw; then
  log "[4/$TOTAL] 防火墙"; skip
else
  log "[4/$TOTAL] 正在配置防火墙（KDE Connect 端口）..."
  sudo ufw allow 1714:1764/udp
  sudo ufw allow 1714:1764/tcp
  done_mark ufw
fi

# --- [5] 首次快照 ---
if done_check snapshot; then
  log "[5/$TOTAL] 首次快照"; skip
else
  log "[5/$TOTAL] 正在创建首次系统快照..."
  sudo snapper -c root create -d "post-install 完成"
  done_mark snapshot
fi

# --- 完成 ---
log "安装完成！"
echo ""
echo "提示："
echo "  - 输入法：运行 fcitx5-configtool，添加拼音输入法"
echo "  - 夸克网盘：使用浏览器访问 https://pan.quark.cn"
echo "  - AUR 软件：有 GitHub 访问时运行 ~/arch-install/aur-install.sh"
echo "  - Samba 挂载：sudo mount -t cifs //树莓派IP/共享名 /mnt/nas -o username=用户名,password=密码,uid=1000,gid=1000"
