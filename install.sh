#!/bin/bash
# Arch Linux 自动安装脚本 — 从 config.json 读取配置
# 支持断点续跑：已完成的步骤自动跳过
set -euo pipefail

# 带时间戳的日志输出
log() { echo "[$(date '+%H:%M:%S')] $*"; }
skip() { log "  ↳ 已完成，跳过。"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$SCRIPT_DIR/config.json"

command -v jq &>/dev/null || { echo "正在安装 jq..."; pacman -Sy --noconfirm jq; }

j() { jq -r "$1" "$CFG"; }

# --- 读取配置 ---
DISK=$(j '.disk.device')
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

DISK_PFX=$(part_suffix "$DISK")
EFI_PART="${DISK_PFX}1"
ROOT_PART="${DISK_PFX}2"

BTRFS_OPTS="noatime,compress=zstd:3"

# --- 验证 UEFI ---
if [[ ! -d /sys/firmware/efi/efivars ]]; then
  echo "错误：未以 UEFI 模式启动！" >&2; exit 1
fi

# --- 网络检测 ---
if ping -c 2 -W 3 archlinux.org &>/dev/null; then
  log "网络已连通，跳过 Wi-Fi 配置。"
else
  WIFI_SSID=$(j '.wifi.ssid')
  WIFI_PASS=$(j '.wifi.password')
  if [[ "$WIFI_SSID" != "null" && -n "$WIFI_SSID" ]]; then
    log "正在连接 Wi-Fi: $WIFI_SSID ..."
    iwctl station wlan0 connect "$WIFI_SSID" --passphrase "$WIFI_PASS"
    sleep 3
  fi
  ping -c 2 -W 3 archlinux.org || { echo "错误：无网络连接！请检查有线或 Wi-Fi。" >&2; exit 1; }
fi

# --- 同步系统时钟 ---
log "正在同步系统时钟..."
timedatectl set-ntp true

# --- 配置中国镜像源 ---
log "正在配置中国镜像源..."
cat > /etc/pacman.d/mirrorlist <<'MIRROREOF'
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
MIRROREOF

# --- 分区 & 格式化（交互确认，可跳过）---
echo ""
echo "=== Arch Linux 安装程序 ==="
echo "磁盘    : $DISK (EFI: $EFI_PART, 根: $ROOT_PART)"
echo "主机名  : $HOSTNAME"
echo "用户名  : $USERNAME"
echo ""
read -rp "是否执行分区+格式化？(yes=擦盘重来 / skip=跳过 / no=取消安装): " DISK_ACTION
case "$DISK_ACTION" in
  yes)
    log "[1/10] 正在分区..."
    sgdisk -Z "$DISK"
    sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 "$DISK"
    sgdisk -n 2:0:0 -t 2:8300 "$DISK"

    log "[2/10] 正在格式化..."
    mkfs.fat -F32 "$EFI_PART"
    mkfs.btrfs -f "$ROOT_PART"

    log "[3/10] 正在创建 Btrfs 子卷..."
    mount "$ROOT_PART" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@cache
    umount /mnt
    ;;
  skip)
    log "跳过分区和格式化。"
    ;;
  *)
    echo "已取消。"; exit 1
    ;;
esac

# --- 密码 ---
ROOT_PW=$(j '.root_password')
USER_PW=$(j '.user.password')

# --- 挂载 ---
log "[4/10] 正在挂载..."
if mountpoint -q /mnt; then
  skip
else
  mount -o ${BTRFS_OPTS},subvol=@ "$ROOT_PART" /mnt
  mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache/pacman/pkg}
  mount "$EFI_PART" /mnt/boot
  mount -o ${BTRFS_OPTS},subvol=@home "$ROOT_PART" /mnt/home
  mount -o ${BTRFS_OPTS},subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
  mount -o ${BTRFS_OPTS},subvol=@log "$ROOT_PART" /mnt/var/log
  mount -o ${BTRFS_OPTS},subvol=@cache "$ROOT_PART" /mnt/var/cache/pacman/pkg
fi

# --- 安装基础系统 ---
log "[5/10] 正在安装基础系统..."
if [[ -x /mnt/usr/bin/pacman ]]; then
  skip
else
  pacstrap -K /mnt $PACKAGES
fi

# --- 生成 fstab ---
log "[6/10] 正在生成 fstab..."
if [[ -s /mnt/etc/fstab ]] && grep -q "$ROOT_PART\|subvol=@" /mnt/etc/fstab 2>/dev/null; then
  skip
else
  genfstab -U /mnt > /mnt/etc/fstab
fi
echo "--- 生成的 fstab ---"
cat /mnt/etc/fstab
echo "--- fstab 结束 ---"

# --- chroot 配置 ---
log "[7/10] 正在配置系统..."
if [[ -f /mnt/root/.setup_done ]]; then
  skip
else
  cat > /mnt/root/setup.sh <<'SETUP_SCRIPT'
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
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -G wheel -s "$USER_SHELL" "$USERNAME"
fi
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
systemctl enable sddm

# fcitx5 环境变量（KDE Plasma Wayland）
mkdir -p "/home/$USERNAME/.config/environment.d"
cat > "/home/$USERNAME/.config/environment.d/fcitx5.conf" <<EOF
QT_IM_MODULES=wayland;fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
INPUT_METHOD=fcitx
GLFW_IM_MODULE=ibus
EOF

chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config/environment.d"

touch /root/.setup_done
SETUP_SCRIPT

  chmod +x /mnt/root/setup.sh
  arch-chroot /mnt /root/setup.sh \
    "$TIMEZONE" "$LANG_SET" "$HOSTNAME" "$USERNAME" "$USER_SHELL" \
    "$ROOT_PW" "$USER_PW" "$ROOT_PART"
  rm -f /mnt/root/setup.sh
fi

# --- ufw 默认规则（写配置文件而非运行命令）---
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /mnt/etc/default/ufw
sed -i 's/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' /mnt/etc/default/ufw
sed -i 's/^ENABLED=.*/ENABLED=yes/' /mnt/etc/ufw/ufw.conf

# --- 配置软件仓库 ---
log "[8/10] 正在配置软件仓库..."

ARCHLINUXCN=$(j '.archlinuxcn // false')
if [[ "$ARCHLINUXCN" == "true" ]] && ! grep -q '\[archlinuxcn\]' /mnt/etc/pacman.conf; then
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
  arch-chroot /mnt pacman -S --noconfirm --needed archlinuxcn-keyring
fi
arch-chroot /mnt pacman -S --noconfirm --needed steam xdg-desktop-portal-gtk

# --- 复制安装文件到用户目录 ---
log "[9/10] 正在复制安装文件..."
if [[ -d "/mnt/home/$USERNAME/arch-install" ]]; then
  skip
else
  cp -rf "$SCRIPT_DIR" "/mnt/home/$USERNAME/arch-install"
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/arch-install"
  arch-chroot /mnt chmod +x "/home/$USERNAME/arch-install/post-install.sh"
fi

# --- 完成 ---
log "[10/10] 安装完成！"
echo ""
echo "接下来："
echo "  1. umount -R /mnt"
echo "  2. reboot"
echo "  3. 以 $USERNAME 登录"
echo "  4. 连接 Wi-Fi: nmcli device wifi connect \"SSID\" password \"密码\""
echo "  5. 运行: ~/arch-install/post-install.sh"
