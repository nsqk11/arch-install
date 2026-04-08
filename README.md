<div align="center">

# 🐧 Arch Linux Auto Installer

**基于官方安装脚本改造的个人 Arch Linux 自动安装方案。**

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=archlinux&logoColor=white)](#)
[![Kernel](https://img.shields.io/badge/Kernel-linux--zen-blue)](#系统架构)
[![Desktop](https://img.shields.io/badge/Desktop-KDE_Plasma-1d99f3)](#桌面环境)
[![Filesystem](https://img.shields.io/badge/FS-Btrfs-green)](#磁盘布局)

*一键安装 → 重启 → 运行 post-install → 开箱即用。*

</div>

---

## ✨ 特性

| | Feature | Description |
|---|---------|-------------|
| 📦 | **配置驱动** | 所有参数集中在 `config.json`，脚本零硬编码 |
| 🔁 | **断点续跑** | 出错修复后重新运行，已完成步骤自动跳过 |
| 🗂️ | **Btrfs 子卷** | @, @home, @snapshots, @log, @cache 五子卷布局 |
| 🔄 | **快照回滚** | snapper + Btrfs，翻车秒恢复 |
| 🖥️ | **KDE Plasma** | Wayland 桌面，开箱即用，全部来自官方 repo |
| 🐚 | **Zsh 全家桶** | oh-my-zsh + powerlevel10k + 语法高亮 + 模糊搜索 |
| 🇨🇳 | **中文就绪** | fcitx5 拼音 + CJK 字体 + 中文语言包 |
| 🚫 | **无需 GitHub** | 主安装和 post-install 全部使用官方 repo / archlinuxcn |

---

## 🏗️ 系统架构

```
┌──────────────────────────────────────────────┐
│              Hardware Layer                   │
├──────────────┬───────────────────────────────┤
│  CPU         │  AMD (amd-ucode)              │
│  GPU         │  AMD (mesa + vulkan-radeon)   │
│  Disk sdb    │  SATA SSD — Arch Linux        │
│  Disk nvme   │  NVMe SSD — Windows           │
├──────────────┴───────────────────────────────┤
│              Software Stack                   │
├──────────────┬───────────────────────────────┤
│  Kernel      │  linux-zen                    │
│  Boot        │  systemd-boot                 │
│  Filesystem  │  Btrfs (zstd:3 compression)   │
│  Swap        │  zram (min(ram/2, 4096), zstd) │
│  Firewall    │  ufw (DROP input)             │
│  Desktop     │  KDE Plasma (Wayland)         │
│  Shell       │  zsh + oh-my-zsh + p10k       │
│  Input       │  fcitx5                       │
│  Audio       │  PipeWire                     │
└──────────────┴───────────────────────────────┘
```

---

## 📁 项目结构

```
arch-install/
├── 📄 config.json        # 安装配置（磁盘、密码、软件包、语言）
├── 🔧 install.sh         # 第一步：Live USB 环境（分区/挂载/pacstrap）
├── 🔧 chroot-setup.sh    # 第二步：chroot 内（系统配置/所有包安装/引导）
├── 🔧 post-install.sh    # 第三步：重启后（zsh 配置/snapper/防火墙）
├── 🔧 aur-install.sh     # 可选：AUR 软件（需要 GitHub）
└── 📄 README.md
```

---

## 💿 磁盘布局

```
sdb (SATA SSD)
├── 1: EFI (1G, FAT32)    → /boot
└── 2: Btrfs
    ├── @          → /
    ├── @home      → /home
    ├── @snapshots → /.snapshots
    ├── @log       → /var/log
    └── @cache     → /var/cache/pacman/pkg
```

Windows 在另一块 NVMe 上，通过 BIOS 启动菜单（MSI 按 F11）切换。

---

## 🚀 使用方法

### 1. 准备

将 `arch-install/` 放入 Arch Live USB，编辑 `config.json`：

```jsonc
{
  "disk": { "device": "/dev/sdb", "efi_size": "1G" },
  "hostname": "arch",
  "user": { "name": "archie", "shell": "/bin/zsh", "password": "你的密码" },
  "root_password": "ROOT密码"
}
```

### 2. 第一步：安装基础系统（Live USB）

```bash
bash install.sh
```

分区 → 格式化 → Btrfs 子卷 → 挂载 → pacstrap 最小系统 → fstab

### 3. 第二步：系统配置（chroot）

```bash
arch-chroot /mnt bash /root/arch-install/chroot-setup.sh
```

时区/语言/用户 → 仓库配置（archlinuxcn + multilib）→ 所有软件包安装 → systemd-boot 引导 → zram → 服务启用

### 4. 重启

```bash
exit
umount -R /mnt
reboot
```

### 5. 第三步：用户配置（重启后）

```bash
~/arch-install/post-install.sh
```

snapper 初始化 → zsh 配置（oh-my-zsh + p10k + 插件）→ KDE Connect 防火墙规则 → 首次快照

### 6. AUR 软件（可选，需要能访问 GitHub）

```bash
~/arch-install/aur-install.sh
```

安装：百度网盘、微信

---

## 📦 软件清单

### install.sh（pacstrap 最小系统）

| 包 |
|----|
| base, linux-zen, linux-zen-headers, linux-firmware, amd-ucode |
| btrfs-progs, networkmanager, vim, git, base-devel, sudo |

### chroot-setup.sh（所有 repo 包）

| 类别 | 软件 |
|------|------|
| 桌面 | KDE Plasma, Konsole, Dolphin, Okular, Gwenview, Ark, Kate, Filelight, KCalc, Partition Manager |
| 浏览器 | Firefox (含中文语言包) |
| 办公 | LibreOffice Fresh (含中文) |
| 影音 | mpv, PipeWire |
| 输入法 | fcitx5 + chinese-addons + configtool + gtk |
| 字体 | noto-fonts-cjk |
| 显卡 | mesa, vulkan-radeon, lib32-mesa, lib32-vulkan-radeon |
| 系统 | zram-generator, ufw, htop, btop, fastfetch |
| 网络存储 | cifs-utils (Samba), ntfs-3g |
| 蓝牙 | bluez, bluez-utils |
| 连接 | KDE Connect, openssh |
| 压缩 | unzip, unrar, p7zip |
| Shell | zsh |
| 工具 | wget, rsync, less, tree, wl-clipboard, pacman-contrib, reflector |
| 游戏 | Steam (multilib) |
| archlinuxcn | paru, oh-my-zsh-git, zsh-theme-powerlevel10k |

### post-install.sh（用户级配置）

| 软件 | 来源 |
|------|------|
| snapper | extra |
| zsh-syntax-highlighting | extra |
| zsh-autosuggestions | extra |
| zsh-completions | extra |
| zsh-history-substring-search | extra |
| fzf | extra |
| pkgfile | extra |

### aur-install.sh（需要 GitHub）

| 软件 | 包名 |
|------|------|
| 百度网盘 | `baidunetdisk-bin` |
| 微信 | `wechat-universal-bwrap` |

---

## 🔄 翻车回滚

```
能进系统？──▶ sudo snapper -c root undochange <编号>
    │
    ▼ 不能
能进 boot 菜单？──▶ 选 fallback initramfs ──▶ snapper 回滚
    │
    ▼ 不能
有安装 U 盘？──▶ chroot ──▶ snapper 回滚
    │
    ▼ snapper 也挂了
手动 btrfs snapshot：mv @broken, snapshot @snapshots/... → @
```

### 快照节奏

| 时机 | 操作 |
|------|------|
| 装完系统稳定后 | `sudo snapper -c root create -d "基线"` |
| 每次 `pacman -Syu` 前 | `sudo snapper -c root create -d "更新前"` |
| 安装重要软件前 | `sudo snapper -c root create` |
| 改系统配置前 | `sudo snapper -c root create` |

---

## ⚠️ 日常维护

| ✅ 要做 | ❌ 别做 |
|---------|---------|
| 每周 `sudo pacman -Syu` | `pacman -Sy` 单独刷新不升级 |
| 更新前看 [Arch News](https://archlinux.org/news/) | 从 AUR 装不认识的包 |
| 定期 `sudo pacman -Sc` 清缓存 | `sudo pacman -Rdd` 强制删包 |
| 遇到问题先搜 [Arch Wiki](https://wiki.archlinuxcn.org) | — |
