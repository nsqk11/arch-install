# arch-install

Personal Arch Linux installation config powered by [archinstall](https://github.com/archlinux/archinstall).

## What's Inside

```
.
├── user_configuration.json   # System config (disk, DE, packages, repos)
├── user_credentials.json     # User account (edit password before use)
└── post-install.sh           # First-boot setup (ufw, zram, fcitx5)
```

## System Overview

| Component | Choice |
|-----------|--------|
| Kernel | linux-zen |
| Bootloader | systemd-boot |
| Filesystem | Btrfs (subvols: @, @home, @snapshots, @log, @cache) |
| Disks | nvme0n1 (system) + nvme1n1 (data → /home) |
| Desktop | KDE Plasma (Wayland) + SDDM |
| Audio | PipeWire |
| GPU | AMD (mesa + vulkan-radeon, 32-bit included) |
| Input | fcitx5 + Chinese addons |
| Swap | zram (zstd, ram/2) |
| Firewall | ufw (deny in / allow out / KDE Connect) |
| Repos | official + multilib + archlinuxcn (USTC) |

## Usage

### 1. Boot the Arch ISO

### 2. Run archinstall

```bash
archinstall --config user_configuration.json --creds user_credentials.json
```

### 3. Reboot and run post-install

```bash
chmod +x post-install.sh
./post-install.sh
```

This configures:
- **ufw** — default deny incoming, allow outgoing, open KDE Connect ports (1714–1764 tcp/udp)
- **zram-generator** — `/etc/systemd/zram-generator.conf` with zstd compression, size = ram/2
- **fcitx5** — environment variables in `/etc/environment.d/fcitx5.conf`

### 4. Reboot again

zram and fcitx5 take effect after reboot.

## Customization

- **Password**: Edit `user_credentials.json` before installing (or use `--creds` interactively)
- **Hostname**: Change `"hostname"` in `user_configuration.json`
- **Packages**: Add/remove entries in the `"packages"` array
- **Disk devices**: Adjust `/dev/nvme0n1` and `/dev/nvme1n1` to match your hardware

## Notes

- `paru` is installed from the archlinuxcn repo (not AUR)
- The second NVMe is formatted as a single Btrfs partition mounted at `/home`
- If you have a single disk, remove the second entry from `device_modifications`
