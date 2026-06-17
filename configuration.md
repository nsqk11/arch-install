# Configuration Guide

## Part 1: Generate the Configuration JSON

The JSON config must be generated on your machine — disk sizes are hardware-specific and cannot be hardcoded here.

### Prerequisites

Run this on an existing Arch Linux system (not the ISO — files persist there).

```bash
sudo pacman -S archinstall
```

### 1. Run archinstall in dry-run mode

```bash
archinstall --dry-run
```

### 2. Configure interactively

| Item | Target |
|------|--------|
| Mirrors | China (USTC or TUNA) |
| Locale | `en_US.UTF-8`, keyboard `us` |
| Disk config | Manual partitioning ([see below](#disk-layout)) |
| Disk encryption | None |
| Bootloader | Systemd-boot |
| Swap | yes (zram configured by post-install.sh) |
| Hostname | `R5-5600G` (or your choice) |
| Root password | set one |
| User account | your username, sudo = yes |
| Profile | Desktop → KDE Plasma, greeter = SDDM |
| Audio | Pipewire |
| Kernels | `linux-zen` |
| Network | NetworkManager |
| Parallel downloads | 5 |
| Additional packages | see package list below |
| Timezone | `Asia/Chongqing` |
| NTP | yes |

**Package list** (paste into the TUI "Additional packages" prompt):

```
base-devel vim git amd-ucode btrfs-progs ntfs-3g mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon firefox firefox-i18n-zh-cn noto-fonts-cjk fcitx5 fcitx5-configtool fcitx5-chinese-addons fcitx5-gtk fcitx5-qt mpv unzip unrar 7zip ufw zram-generator kde-connect steam kde-system konsole ark kate kcalc filelight gwenview okular ffmpegthumbs kio-extras archlinuxcn-keyring paru snapper snap-pac pacman-contrib
```

### 3. Disk partitioning (manual) {#disk-layout}

**`/dev/nvme0n1`** — system disk, wipe = yes:

| # | fs_type | Size | Mountpoint | Flags | Mount options |
|---|---------|------|------------|-------|---------------|
| 1 | fat32 | 512 MiB | `/boot` | Boot | — |
| 2 | btrfs | remaining | `null` (subvolumes) | — | `compress=zstd`, `noatime` |

Btrfs subvolumes for partition 2:

| Name | Mountpoint |
|------|------------|
| `@` | `/` |
| `@home` | `/home` |
| `@.snapshots` | `/.snapshots` |
| `@log` | `/var/log` |
| `@cache` | `/var/cache` |

**`/dev/sdb`** — data disk, wipe = yes:

| # | fs_type | Size | Mountpoint | Mount options |
|---|---------|------|------------|---------------|
| 1 | btrfs | full disk | `/data` | `compress=zstd`, `noatime` |

### 4. Do NOT install

When archinstall asks to proceed, **select No / abort**.

### 5. Save the generated JSON

```bash
cat /var/log/archinstall/user_configuration.json
```

Save this file — you will need it for installation. After saving, manually add archlinuxcn to `"mirror_config"`:

```json
"custom_mirrors": [
  {
    "name": "archlinuxcn",
    "url": "https://mirrors.ustc.edu.cn/archlinuxcn/$arch",
    "sign_check": "Required",
    "sign_option": "TrustAll"
  }
]
```

Also ensure `"additional-repositories": ["multilib"]` is present.

---

## Part 2: Install from the Arch ISO

### Serve the config from Raspberry Pi (nginx)

On the Raspberry Pi, add a location block to your nginx config:

```nginx
location /arch-install/ {
    alias /path/to/arch-install/;
    autoindex on;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Place your generated `user_configuration.json` and a `user_credentials.json` (with passwords filled in) into that directory.

`user_credentials.json` format:

```json
{
  "!root-password": "yourpassword",
  "!users": [
    {
      "username": "zzhayaw",
      "!password": "yourpassword",
      "sudo": true
    }
  ]
}
```

Then in the Arch ISO:

```bash
archinstall \
  --config http://raspberrypi.local/arch-install/user_configuration.json \
  --creds http://raspberrypi.local/arch-install/user_credentials.json \
  --silent
```

### After installation

Reboot into the new system, clone this repo and run:

```bash
git clone https://github.com/nsqk11/arch-install
cd arch-install
chmod +x post-install.sh
./post-install.sh
```

Reboot again to apply zram and fcitx5 changes.
