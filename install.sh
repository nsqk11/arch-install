#!/bin/bash
# Arch Linux 自动安装脚本 — 第一步：Live USB 环境
# 分区 → 格式化 → 子卷 → 挂载 → pacstrap → fstab
# Usage: bash install.sh
# shellcheck disable=SC2086
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "[$(date '+%H:%M:%S')] ${GREEN}$*${NC}"; }
warn() { echo -e "[$(date '+%H:%M:%S')] ${YELLOW}⚠ $*${NC}"; }
err()  { echo -e "[$(date '+%H:%M:%S')] ${RED}✗ $*${NC}" >&2; }
skip() { echo -e "[$(date '+%H:%M:%S')]   ${YELLOW}↳ 已完成，跳过。${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$SCRIPT_DIR/config.json"

command -v jq &>/dev/null || { err "jq 未安装，请使用包含 jq 的 Arch Live ISO。"; exit 1; }

j() { jq -r "$1" "$CFG"; }

# --- 读取配置 ---
DISK=$(j '.disk.device')
EFI_SIZE=$(j '.disk.efi_size')
HOSTNAME=$(j '.hostname')
USERNAME=$(j '.user.name')
PACKAGES=$(jq -r '.pacstrap_packages[]' "$CFG" | tr '\n' ' ')

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
  err "未以 UEFI 模式启动！"; exit 1
fi

# --- 网络检测 ---
if ping -c 2 -W 3 archlinux.org &>/dev/null; then
  log "网络已连通。"
else
  WIFI_SSID=$(j '.wifi.ssid')
  WIFI_PASS=$(j '.wifi.password')
  if [[ "$WIFI_SSID" != "null" && -n "$WIFI_SSID" ]]; then
    log "正在连接 Wi-Fi: $WIFI_SSID ..."
    iwctl station wlan0 connect "$WIFI_SSID" --passphrase "$WIFI_PASS"
    sleep 3
  fi
  ping -c 2 -W 3 archlinux.org || { err "无网络连接！"; exit 1; }
fi

# --- 同步时钟 ---
timedatectl set-ntp true

# --- 配置镜像源 ---
log "正在配置中国镜像源..."
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
EOF

# --- 分区 & 格式化（交互确认，可跳过）---
echo ""
echo "=== Arch Linux 安装程序 ==="
echo "磁盘    : $DISK (EFI: $EFI_PART, 根: $ROOT_PART)"
echo "主机名  : $HOSTNAME"
echo "用户名  : $USERNAME"
echo ""
read -rp "是否执行分区+格式化？(yes=擦盘重来 / skip=跳过 / no=取消): " DISK_ACTION
case "$DISK_ACTION" in
  yes)
    log "[1/6] 正在分区..."
    sgdisk -Z "$DISK"
    sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 "$DISK"
    sgdisk -n 2:0:0 -t 2:8300 "$DISK"

    log "[2/6] 正在格式化..."
    mkfs.fat -F32 "$EFI_PART"
    mkfs.btrfs -f "$ROOT_PART"

    log "[3/6] 正在创建 Btrfs 子卷..."
    mount "$ROOT_PART" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@cache
    umount /mnt
    ;;
  skip) log "跳过分区和格式化。" ;;
  *) echo "已取消。"; exit 1 ;;
esac

# --- 挂载 ---
log "[4/6] 正在挂载..."
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

# --- pacstrap ---
log "[5/6] 正在安装基础系统..."
if [[ -x /mnt/usr/bin/pacman ]]; then
  skip
else
  pacstrap -K /mnt $PACKAGES
fi

# --- fstab ---
log "[6/6] 正在生成 fstab..."
if [[ -s /mnt/etc/fstab ]] && grep -q "subvol=@" /mnt/etc/fstab 2>/dev/null; then
  skip
else
  genfstab -U /mnt > /mnt/etc/fstab
fi

# --- 复制安装文件到新系统 ---
log "正在复制安装文件..."
cp -rf "$SCRIPT_DIR" /mnt/root/arch-install

# --- 提示下一步 ---
log "第一步完成！"
echo ""
echo "接下来："
echo "  arch-chroot /mnt bash /root/arch-install/chroot-setup.sh"
