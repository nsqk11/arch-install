<div align="center">

# 🐧 Arch Linux Auto Installer

**基于官方安装脚本改造的个人 Arch Linux 自动安装方案。**

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=archlinux&logoColor=white)](#)
[![Kernel](https://img.shields.io/badge/Kernel-linux--zen-blue)](#系统架构)
[![Desktop](https://img.shields.io/badge/Desktop-HyDE_(Hyprland)-blueviolet)](#桌面环境)
[![Filesystem](https://img.shields.io/badge/FS-Btrfs-green)](#磁盘布局)

*一键安装 → 重启 → 运行 post-install → 开箱即用。*

</div>

---

## ✨ 特性

| | Feature | Description |
|---|---------|-------------|
| 📦 | **配置驱动** | 所有参数集中在 `config.json`，脚本零硬编码 |
| 🗂️ | **Btrfs 子卷** | @, @home, @snapshots, @log, @cache 五子卷布局 |
| 💾 | **双盘分离** | 系统盘 + 数据盘，Home 独立 NVMe |
| 🔄 | **快照回滚** | Timeshift + Btrfs，翻车秒恢复 |
| 🖥️ | **HyDE 桌面** | Hyprland + Waybar + Rofi，开箱即用 |
| 🇨🇳 | **中文就绪** | fcitx5 拼音 + CJK 字体 + 中文语言包 |

---

## 🏗️ 系统架构

```
┌──────────────────────────────────────────────┐
│              Hardware Layer                   │
├──────────────┬───────────────────────────────┤
│  CPU         │  AMD (amd-ucode)              │
│  GPU         │  AMD (mesa + vulkan-radeon)   │
│  Disk 0      │  SATA SSD — System + Home      │
│  Disk 1      │  NVMe — Windows                │
├──────────────┴───────────────────────────────┤
│              Software Stack                   │
├──────────────┬───────────────────────────────┤
│  Kernel      │  linux-zen                    │
│  Boot        │  systemd-boot                 │
│  Filesystem  │  Btrfs (zstd:3 compression)   │
│  Swap        │  zram (min(ram/2, 4096), zstd)  │
│  Firewall    │  ufw (DROP input)             │
│  Desktop     │  HyDE (Hyprland)              │
│  Input       │  fcitx5                       │
│  Audio       │  PipeWire                     │
└──────────────┴───────────────────────────────┘
```

---

## 📁 项目结构

```
arch-install/
├── 📄 config.json        # 安装配置（磁盘、网络、软件包、语言）
├── 🔧 install.sh         # 主安装脚本（Live USB 环境运行）
├── 🔧 post-install.sh    # 首次启动后脚本（普通用户运行）
└── 📄 README.md
```

---

## 💿 磁盘布局

```
sda (SATA SSD)
├── 1: EFI (1G, FAT32)    → /boot
└── 2: Btrfs
    ├── @          → /
    ├── @home      → /home
    ├── @snapshots → /.snapshots
    ├── @log       → /var/log
    └── @cache     → /var/cache/pacman/pkg
```

---

## 🚀 使用方法

### 1. 准备

将 `arch-install/` 放入 Arch Live USB，编辑 `config.json`：

```jsonc
{
  "wifi": { "ssid": "你的WiFi名", "password": "你的WiFi密码" },
  "disk": { "device": "/dev/sda", "efi_size": "1G" },
  "hostname": "arch",
  "user": { "name": "yawei", "shell": "/bin/bash" }
}
```

### 2. 安装

```bash
bash install.sh
```

脚本会自动完成：分区 → 格式化 → 创建子卷 → pacstrap → 配置引导 → 启用服务

### 3. 重启后

```bash
nmcli device wifi connect "SSID" password "密码"
~/arch-install/post-install.sh
```

post-install 会安装：yay → 百度网盘 / 微信 → KDE Connect 防火墙规则 → HyDE 桌面

---

## 📦 软件清单

### pacstrap 安装

| 类别 | 软件 |
|------|------|
| 浏览器 | Firefox (含中文语言包) |
| 办公 | LibreOffice Fresh (含中文) |
| 影音 | mpv, PipeWire (alsa/pulse/wireplumber) |
| 输入法 | fcitx5 + chinese-addons + gtk/qt |
| 字体 | noto-fonts-cjk |
| 系统 | timeshift, zram-generator, ufw, btrfs-progs |
| 网络存储 | cifs-utils (Samba 挂载) |
| 蓝牙 | bluez, bluez-utils |
| 连接 | kdeconnect |
| 压缩 | unzip, unrar, p7zip |
| 开发 | git, base-devel, vim |
| 其他 | ntfs-3g, bash-completion |

### post-install 安装 (AUR)

| 软件 | 包名 |
|------|------|
| 百度网盘 | `baidunetdisk-bin` |
| 微信 | `wechat-universal-bwrap` |
| Steam | `steam` (multilib) |
| Portal | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| HyDE | git clone + install.sh |

---

## 🔄 翻车回滚

```
能进系统？──▶ sudo timeshift --restore
    │
    ▼ 不能
能进 boot 菜单？──▶ 选 fallback initramfs ──▶ timeshift --restore
    │
    ▼ 不能
有安装 U 盘？──▶ chroot ──▶ timeshift --restore
    │
    ▼ timeshift 也挂了
手动 btrfs snapshot：mv @broken, snapshot @snapshots/... → @
```

### 快照节奏

| 时机 | 操作 |
|------|------|
| 装完系统稳定后 | `sudo timeshift --create --comments "基线"` |
| 每次 `pacman -Syu` 前 | `sudo timeshift --create` |
| 安装重要软件前 | `sudo timeshift --create` |
| 改系统配置前 | `sudo timeshift --create` |

---

## ⌨️ HyDE 快捷键速查

| 快捷键 | 功能 |
|--------|------|
| `Super + /` | **显示所有快捷键** |
| `Super + T` | 终端 |
| `Super + A` | 应用启动器 (rofi) |
| `Super + B` | 浏览器 |
| `Super + E` | 文件管理器 |
| `Ctrl + Q` | 关闭窗口 |
| `Super + W` | 切换浮动/平铺 |
| `Super + 1~0` | 切换工作区 |
| `Super + Shift + T` | 选择主题 |
| `Super + Shift + W` | 选择壁纸 |
| `Super + P` | 截图 (区域) |
| `Super + V` | 剪贴板历史 |
| `Super + L` | 锁屏 |

> [!TIP]
> 自定义配置写在 `~/.config/hypr/userprefs.conf`，HyDE 更新不会覆盖。

---

## ⚠️ 日常维护

| ✅ 要做 | ❌ 别做 |
|---------|---------|
| 每周 `sudo pacman -Syu` | `pacman -Sy` 单独刷新不升级 |
| 更新前看 [Arch News](https://archlinux.org/news/) | 从 AUR 装不认识的包 |
| 定期 `sudo pacman -Sc` 清缓存 | `sudo pacman -Rdd` 强制删包 |
| 遇到问题先搜 [Arch Wiki](https://wiki.archlinuxcn.org) | — |
