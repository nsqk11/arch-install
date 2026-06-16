#!/bin/bash
set -euo pipefail

# --- ufw rules ---
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 1714:1764/tcp  # KDE Connect
sudo ufw allow 1714:1764/udp  # KDE Connect
sudo ufw enable

# --- zram-generator ---
sudo tee /etc/systemd/zram-generator.conf > /dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

# --- fcitx5 environment variables ---
sudo tee /etc/environment.d/fcitx5.conf > /dev/null <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

# --- locale ---
sudo sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/; s/#zh_TW.UTF-8 UTF-8/zh_TW.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen

# --- paccache (keep last 3 versions of each package, weekly cleanup) ---
sudo systemctl enable paccache.timer

# --- fstrim (weekly TRIM for SSD) ---
sudo systemctl enable fstrim.timer

# --- Btrfs scrub (monthly data integrity check) ---
sudo systemctl enable btrfs-scrub@-.timer
sudo systemctl enable btrfs-scrub@home.timer
sudo systemctl enable btrfs-scrub@data.timer

# --- snapper: auto snapshots + cleanup for root ---
sudo snapper -c root create-config /
# Keep: 10 hourly, 7 daily, 4 weekly, 3 monthly
sudo snapper -c root set-config \
  NUMBER_CLEANUP=yes \
  NUMBER_LIMIT=10 \
  TIMELINE_CREATE=yes \
  TIMELINE_CLEANUP=yes \
  TIMELINE_LIMIT_HOURLY=10 \
  TIMELINE_LIMIT_DAILY=7 \
  TIMELINE_LIMIT_WEEKLY=4 \
  TIMELINE_LIMIT_MONTHLY=3
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

# --- makepkg parallel compilation ---
sudo sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf

# --- pacman: color output + parallel downloads ---
sudo sed -i 's/#Color/Color/; s/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# --- vm.swappiness (lower value = prefer zram over disk swap) ---
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf

echo "Done. Reboot to apply zram and fcitx5 changes."
