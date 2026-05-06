# arch-install

Personal Arch Linux installation config powered by [archinstall](https://github.com/archlinux/archinstall).

## What's Inside

```
.
├── user_configuration.json   # System config (disk, DE, packages, repos)
├── user_credentials.json     # User account (edit password before use!)
└── post-install.sh           # First-boot setup (ufw, zram, fcitx5)
```

## System Overview

| Component | Choice |
|-----------|--------|
| Kernel | linux-zen |
| Bootloader | systemd-boot |
| Filesystem | Btrfs (subvols: @, @home, @snapshots, @log, @cache) |
| Desktop | KDE Plasma (Wayland) + SDDM |
| Audio | PipeWire |
| GPU | AMD (mesa + vulkan-radeon, 32-bit included) |
| Input | fcitx5 + Chinese addons |
| Swap | zram (zstd, ram/2) |
| Firewall | ufw (deny in / allow out / KDE Connect) |
| Repos | official + multilib + archlinuxcn (USTC) |

## Usage

### 1. Boot the Arch ISO

### 2. Edit credentials

> ⚠️ **Change the password in `user_credentials.json` before installing!**

Use a plaintext password in the `!password` field, or generate a hash:

```bash
openssl passwd -6    # then put the hash in "enc_password" field
```

### 3. Run archinstall

```bash
archinstall --config user_configuration.json --creds user_credentials.json
```

### 4. Reboot and run post-install

```bash
chmod +x post-install.sh
./post-install.sh
```

This configures:
- **ufw** — default deny incoming, allow outgoing, open KDE Connect ports (1714–1764 tcp/udp)
- **zram-generator** — `/etc/systemd/zram-generator.conf` with zstd compression, size = ram/2
- **fcitx5** — environment variables in `/etc/environment.d/fcitx5.conf`

### 5. Reboot again

zram and fcitx5 take effect after reboot.

## Customization

- **Disk device**: Change `/dev/nvme0n1` to match your hardware
- **Hostname**: Change `"hostname"` in `user_configuration.json`
- **Packages**: Add/remove entries in the `"packages"` array
- **AUR packages**: Install via `paru` after first boot (paru comes from archlinuxcn)

## Notes

- `paru` is installed from the archlinuxcn repo, not AUR
- `archlinuxcn-keyring` is listed before `paru` to ensure signature verification works
- Single-disk layout with Btrfs subvolumes for easy snapshotting
