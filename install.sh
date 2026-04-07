#!/bin/bash
# Arch Linux 自动安装脚本 — 从 config.json 读取配置
set -euo pipefail

# 带时间戳的日志输出
log() { echo "[$(date '+%H:%M:%S')] $*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$SCRIPT_DIR/config.json"

command -v jq &>/dev/null || { echo "正在安装 jq..."; pacman -Sy --noconfirm jq; }

j() { jq -r "$1" "$CFG"; }

# --- 读取配置 ---
ROOT_DISK=$(j '.disk.root')
HOME_DISK=$(j '.disk.home')
EFI_SIZE=$(j '.disk.efi_size')
TIMEZONE=$(j '.locale.timezone')
LANG_SET=$(j '.locale.lang')
HOSTNAME=$(j '.hostname')
USERNAME=$(j '.user.name')
USER_SHELL=$(j '.user.shell')
PACKAGES=$(jq -r '.packages[]' "$CFG" | tr '\n' ' ')

# 自动判断分区后缀（NVMe 用 p1, SATA 用 1）
part_suffix() {
  if [[ "$1" == *nvme* || "$1" == *mmcblk* ]]; then
    echo "${1}p"
  else
    echo "${1}"
  fi
}

ROOT_PFX=$(part_suffix "$ROOT_DISK")
HOME_PFX=$(part_suffix "$HOME_DISK")
ROOT_P1="${ROOT_PFX}1"
ROOT_P2="${ROOT_PFX}2"
HOME_P1="${HOME_PFX}1"

BTRFS_OPTS="noatime,compress=zstd:3"

# --- 验证 UEFI ---
if [[ ! -d /sys/firmware/efi/efivars ]]; then
  echo "错误：未以 UEFI 模式启动！" >&2; exit 1
fi

# --- 连接 Wi-Fi ---
WIFI_SSID=$(j '.wifi.ssid')
WIFI_PASS=$(j '.wifi.password')
if [[ "$WIFI_SSID" != "null" && -n "$WIFI_SSID" ]]; then
  log "[0/11] 正在连接 Wi-Fi: $WIFI_SSID ..."
  iwctl station wlan0 connect "$WIFI_SSID" --passphrase "$WIFI_PASS"
  sleep 3
  ping -c 2 archlinux.org || { echo "Wi-Fi 连接失败！"; exit 1; }
  echo "Wi-Fi 已连接。"
fi

# --- 同步系统时钟 ---
log "正在同步系统时钟..."
timedatectl set-ntp true

# --- 配置中国镜像源 ---
log "正在配置中国镜像源..."
cat > /etc/pacman.d/mirrorlist <<'MIRROREOF'
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
MIRROREOF

# --- 确认 ---
echo ""
echo "=== Arch Linux 安装程序 ==="
echo "系统盘  : $ROOT_DISK (EFI: $ROOT_P1, 根: $ROOT_P2)"
echo "数据盘  : $HOME_DISK (Home: $HOME_P1)"
echo "主机名  : $HOSTNAME"
echo "用户名  : $USERNAME"
echo ""
echo "警告：这将完全擦除 $ROOT_DISK 和 $HOME_DISK！"
read -rp "是否继续？(yes/no): " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "已取消。"; exit 1; }

# --- 密码 ---
read -rsp "请输入 ROOT 密码: " ROOT_PW; echo
read -rsp "请输入 $USERNAME 的密码: " USER_PW; echo

# --- 分区 ---
log "[1/11] 正在分区..."
sgdisk -Z "$ROOT_DISK"
sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 "$ROOT_DISK"
sgdisk -n 2:0:0 -t 2:8300 "$ROOT_DISK"

sgdisk -Z "$HOME_DISK"
sgdisk -n 1:0:0 -t 1:8300 "$HOME_DISK"

# --- 格式化 ---
log "[2/11] 正在格式化..."
mkfs.fat -F32 "$ROOT_P1"
mkfs.btrfs -f "$ROOT_P2"
mkfs.btrfs -f "$HOME_P1"

# --- 创建 Btrfs 子卷（系统盘）---
log "[3/11] 正在创建 Btrfs 子卷..."
mount "$ROOT_P2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
umount /mnt

# 数据盘子卷
mount "$HOME_P1" /mnt
btrfs subvolume create /mnt/@home
umount /mnt

# --- 挂载（先根分区，再 boot，再其他）---
log "[4/11] 正在挂载..."
mount -o ${BTRFS_OPTS},subvol=@ "$ROOT_P2" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache/pacman/pkg}
mount "$ROOT_P1" /mnt/boot
mount -o ${BTRFS_OPTS},subvol=@home "$HOME_P1" /mnt/home
mount -o ${BTRFS_OPTS},subvol=@snapshots "$ROOT_P2" /mnt/.snapshots
mount -o ${BTRFS_OPTS},subvol=@log "$ROOT_P2" /mnt/var/log
mount -o ${BTRFS_OPTS},subvol=@cache "$ROOT_P2" /mnt/var/cache/pacman/pkg

# --- 安装基础系统 ---
log "[5/11] 正在安装基础系统..."
pacstrap -K /mnt $PACKAGES

# --- 生成 fstab ---
log "[6/11] 正在生成 fstab..."
genfstab -U /mnt > /mnt/etc/fstab
echo "--- 生成的 fstab ---"
cat /mnt/etc/fstab
echo "--- fstab 结束 ---"

# --- 写入 chroot 脚本 ---
log "[7/11] 正在配置系统..."
cat > /mnt/tmp/setup.sh <<'SETUP_SCRIPT'
#!/bin/bash
set -euo pipefail

TIMEZONE="$1"
LANG_SET="$2"
HOSTNAME_VAL="$3"
USERNAME="$4"
USER_SHELL="$5"
ROOT_PW="$6"
USER_PW="$7"
ROOT_P2="$8"

# 时区
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# 语言
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=$LANG_SET" > /etc/locale.conf

# 主机名
echo "$HOSTNAME_VAL" > /etc/hostname

# 用户
echo "root:$ROOT_PW" | chpasswd
useradd -m -G wheel -s "$USER_SHELL" "$USERNAME"
echo "$USERNAME:$USER_PW" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# systemd-boot 引导
bootctl install

cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor  no
EOF

PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_P2")

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

# zram
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF

# zram swap 优化参数
cat > /etc/sysctl.d/99-vm-zram-parameters.conf <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

# 启用服务
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable fstrim.timer
systemctl enable btrfs-scrub@-.timer
systemctl enable ufw
systemctl enable bluetooth
systemctl enable systemd-boot-update.service

# fcitx5 环境变量（uwsm 管理的 Hyprland 用 ~/.config/uwsm/env）
# Wayland 下不设 GTK_IM_MODULE，改用 gtk settings.ini
mkdir -p "/home/$USERNAME/.config/uwsm"
cat > "/home/$USERNAME/.config/uwsm/env" <<EOF
export QT_IM_MODULES=wayland;fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export INPUT_METHOD=fcitx
export GLFW_IM_MODULE=ibus
EOF

mkdir -p "/home/$USERNAME/.config/gtk-3.0"
cat > "/home/$USERNAME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-im-module = fcitx
EOF

chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config/uwsm" "/home/$USERNAME/.config/gtk-3.0"
SETUP_SCRIPT

chmod +x /mnt/tmp/setup.sh
arch-chroot /mnt /tmp/setup.sh \
  "$TIMEZONE" "$LANG_SET" "$HOSTNAME" "$USERNAME" "$USER_SHELL" \
  "$ROOT_PW" "$USER_PW" "$ROOT_P2"
rm -f /mnt/tmp/setup.sh

# --- ufw 默认规则（写配置文件而非运行命令）---
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /mnt/etc/default/ufw
sed -i 's/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' /mnt/etc/default/ufw
sed -i 's/^ENABLED=.*/ENABLED=yes/' /mnt/etc/ufw/ufw.conf

# --- 配置软件仓库 ---
log "[8/11] 正在配置软件仓库..."

# archlinuxcn
ARCHLINUXCN=$(j '.archlinuxcn // false')
if [[ "$ARCHLINUXCN" == "true" ]]; then
  cat >> /mnt/etc/pacman.conf <<'CNEOF'

[archlinuxcn]
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
CNEOF
fi

# multilib（Steam 需要 32 位库）
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /mnt/etc/pacman.conf

# 刷新仓库并安装额外软件
arch-chroot /mnt pacman -Sy --noconfirm
if [[ "$ARCHLINUXCN" == "true" ]]; then
  arch-chroot /mnt pacman -S --noconfirm archlinuxcn-keyring
fi
arch-chroot /mnt pacman -S --noconfirm steam xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

# --- 复制安装文件到用户目录 ---
log "[9/11] 正在复制安装文件..."
cp -rf "$SCRIPT_DIR" "/mnt/home/$USERNAME/arch-install"
arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/arch-install"
arch-chroot /mnt chmod +x "/home/$USERNAME/arch-install/post-install.sh"

# --- 完成 ---
log "[10/11] 安装完成！"
echo ""
echo "接下来："
echo "  1. umount -R /mnt"
echo "  2. reboot"
echo "  3. 以 $USERNAME 登录"
echo "  4. 连接 Wi-Fi: nmcli device wifi connect \"SSID\" password \"密码\""
echo "  5. 运行: ~/arch-install/post-install.sh"
