#!/bin/bash
set -euo pipefail

# --- amd-ucode: inject into systemd-boot entries ---
for entry in /boot/loader/entries/*.conf; do
    if ! grep -q "amd-ucode.img" "$entry"; then
        sudo sed -i '/^initrd /i initrd  /amd-ucode.img' "$entry"
    fi
done

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

# --- makepkg parallel compilation ---
sudo sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf

# --- pacman: color output + parallel downloads ---
sudo sed -i 's/#Color/Color/; s/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# --- vm.swappiness (lower value = prefer zram over disk swap) ---
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf

echo "Done. Reboot to apply zram and fcitx5 changes."
