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

echo "Done. Reboot to apply zram and fcitx5 changes."
