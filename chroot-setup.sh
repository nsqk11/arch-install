#!/bin/bash
# Arch Linux 自动安装脚本 — 第二步：chroot 内运行
# 系统配置 → 仓库设置 → 所有 repo 包安装 → 引导 → 服务
# Usage: arch-chroot /mnt bash /root/arch-install/chroot-setup.sh
# shellcheck disable=SC2086
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "[$(date '+%H:%M:%S')] ${GREEN}$*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$SCRIPT_DIR/config.json"
j() { jq -r "$1" "$CFG"; }

# --- 读取配置 ---
TIMEZONE=$(j '.locale.timezone')
LANG_SET=$(j '.locale.lang')
HOSTNAME_VAL=$(j '.hostname')
USERNAME=$(j '.user.name')
USER_SHELL=$(j '.user.shell')
ROOT_PW=$(j '.root_password')
USER_PW=$(j '.user.password')
DISK=$(j '.disk.device')

part_suffix() {
  if [[ "$1" == *nvme* || "$1" == *mmcblk* ]]; then echo "${1}p"; else echo "${1}"; fi
}
ROOT_PART="$(part_suffix "$DISK")2"

CHROOT_PKGS=$(jq -r '.chroot_packages[]' "$CFG" | tr '\n' ' ')
CN_PKGS=$(jq -r '.archlinuxcn_packages[]' "$CFG" | tr '\n' ' ')
ARCHLINUXCN=$(j '.archlinuxcn // false')

# --- [1] 时区 ---
log "[1/10] 时区..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# --- [2] 语言 ---
log "[2/10] 语言..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=$LANG_SET" > /etc/locale.conf

# --- [3] 主机名 ---
log "[3/10] 主机名..."
echo "$HOSTNAME_VAL" > /etc/hostname

# --- [4] 用户 ---
log "[4/10] 用户..."
echo "root:$ROOT_PW" | chpasswd
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -G wheel -s "$USER_SHELL" "$USERNAME"
fi
echo "$USERNAME:$USER_PW" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- [5] 配置仓库 ---
log "[5/10] 配置软件仓库..."

# 镜像源
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
EOF

# archlinuxcn
if [[ "$ARCHLINUXCN" == "true" ]] && ! grep -q '\[archlinuxcn\]' /etc/pacman.conf; then
  cat >> /etc/pacman.conf <<'EOF'

[archlinuxcn]
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
EOF
fi

# multilib
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf

# 刷新仓库
pacman -Sy --noconfirm
if [[ "$ARCHLINUXCN" == "true" ]]; then
  pacman -S --noconfirm --needed archlinuxcn-keyring
fi

# --- [6] 安装所有包 ---
log "[6/10] 安装所有软件包..."
pacman -S --noconfirm --needed $CHROOT_PKGS
if [[ -n "$CN_PKGS" ]]; then
  pacman -S --noconfirm --needed $CN_PKGS
fi

# --- [7] systemd-boot 引导 ---
log "[7/10] 配置引导..."
bootctl install

cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor  no
EOF

PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux-zen
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen.img
options root=PARTUUID=$PARTUUID rootflags=subvol=@ rw
EOF

cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux-zen
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen-fallback.img
options root=PARTUUID=$PARTUUID rootflags=subvol=@ rw
EOF

# --- [8] zram ---
log "[8/10] 配置 zram..."
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF

cat > /etc/sysctl.d/99-vm-zram-parameters.conf <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

# --- [9] 启用服务 + ufw + fcitx5 ---
log "[9/10] 启用服务和配置..."
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable fstrim.timer
systemctl enable btrfs-scrub@-.timer
systemctl enable ufw
systemctl enable bluetooth
systemctl enable systemd-boot-update.service
systemctl enable sddm

# ufw 默认规则
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /etc/default/ufw
sed -i 's/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' /etc/default/ufw
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf

# fcitx5 环境变量
mkdir -p "/home/$USERNAME/.config/environment.d"
cat > "/home/$USERNAME/.config/environment.d/fcitx5.conf" <<EOF
QT_IM_MODULES=wayland;fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
INPUT_METHOD=fcitx
GLFW_IM_MODULE=ibus
EOF
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"

# --- [10] 复制安装文件到用户目录 ---
log "[10/10] 复制安装文件..."
cp -rf "$SCRIPT_DIR" "/home/$USERNAME/arch-install"
# 清除密码
jq '.root_password = "" | .user.password = ""' "/home/$USERNAME/arch-install/config.json" > /tmp/cfg.tmp \
  && mv -f /tmp/cfg.tmp "/home/$USERNAME/arch-install/config.json"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/arch-install"
chmod +x "/home/$USERNAME/arch-install/post-install.sh"
chmod +x "/home/$USERNAME/arch-install/aur-install.sh"

# --- 完成 ---
log "第二步完成！"
echo ""
echo "接下来："
echo "  exit"
echo "  umount -R /mnt"
echo "  reboot"
echo "  以 $USERNAME 登录后运行: ~/arch-install/post-install.sh"
