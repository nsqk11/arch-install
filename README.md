# arch-install

Personal Arch Linux installation config powered by [archinstall](https://github.com/archlinux/archinstall).

## What's Inside

```
.
├── configuration.md   # Full installation guide (generate config + install steps)
└── post-install.sh    # First-boot setup (ufw, zram, fcitx5, snapper, etc.)
```

## System Overview

| Component | Choice |
|-----------|--------|
| Kernel | linux-zen |
| Bootloader | systemd-boot |
| Filesystem | ext4 — nvme0n1: /boot (512MiB fat32), / (remaining) |
| Desktop | KDE Plasma (Wayland) + SDDM |
| Audio | PipeWire |
| GPU | AMD (mesa + vulkan-radeon, 32-bit included) |
| Input | fcitx5 + Chinese addons |
| Swap | zram (zstd, ram/2) |
| Firewall | ufw (deny in / allow out / KDE Connect ports) |
| Repos | official + multilib + archlinuxcn (USTC) |

## Usage

See [configuration.md](configuration.md) for the full step-by-step guide:
1. Generate a valid `user_configuration.json` using `archinstall --dry-run`
2. Serve it from Raspberry Pi via nginx
3. Boot the Arch ISO and run archinstall with the config
4. Reboot and run `post-install.sh`

## post-install.sh

Configures:
- **ufw** — default deny incoming, allow outgoing, KDE Connect ports (1714–1764 tcp/udp)
- **zram-generator** — zstd compression, size = ram/2
- **fcitx5** — environment variables in `/etc/environment.d/fcitx5.conf`
- **locale** — enables zh_CN.UTF-8 and zh_TW.UTF-8
- **paccache.timer** — weekly pacman cache cleanup (keeps last 3 versions)
- **fstrim.timer** — weekly TRIM for SSDs
- **makepkg** — parallel compilation with all CPU cores
- **pacman** — color output + parallel downloads
- **vm.swappiness=10** — tuned for zram

## Notes

- `paru` is installed from archlinuxcn, not AUR
- `/dev/sdb` (/data) uses Btrfs with compress=zstd,noatime
- AUR packages (e.g. `wps-office`): install via `paru` after first boot
