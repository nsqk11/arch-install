# Arch Linux 使用提醒

## 日常维护（必须做）

- 至少每周跑一次 `sudo pacman -Syu`，长期不更新再更新容易翻车
- 更新前看一眼 https://archlinux.org/news/ ，偶尔有需要手动处理的更新
- 定期清理包缓存：`sudo pacman -Sc`

## 快照习惯

- 每次大更新前跑 `sudo timeshift --create`，翻车了能秒回滚
- 装完系统稳定后立刻创建第一个快照作为基线

## 别做的事

- 不要 `pacman -Sy` 单独刷新数据库不升级，会导致部分升级，容易挂
- 不要随便从 AUR 装不认识的包，先看 PKGBUILD
- 不要用 `sudo pacman -Rdd` 强制删包忽略依赖

## 有用的命令

- `pacman -Qs 关键词` — 搜索已安装的包
- `pacman -Ss 关键词` — 搜索仓库里的包
- `yay -Sua` — 只更新 AUR 包
- `systemctl --failed` — 查看挂掉的服务
- `journalctl -b -p err` — 查看本次启动的错误日志

## Arch Wiki 是你的圣经

- 遇到任何问题先搜 https://wiki.archlinuxcn.org
- 90% 的问题 wiki 上都有答案，比搜百度/Google 靠谱

## 滚动更新翻车了怎么办

### 方法一：在本机回滚（能进系统时）

```bash
# 查看可用快照
sudo timeshift --list

# 回滚到指定快照
sudo timeshift --restore --snapshot '2026-04-07_12-00-00'

# 重启
reboot
```

### 方法二：从 fallback initramfs 启动（系统能启动但有问题）

1. 开机时按任意键进入 systemd-boot 菜单
2. 选择带 `fallback` 的启动项
3. 进入系统后按方法一回滚

### 方法三：从安装 U 盘救援（系统完全无法启动）

```bash
# 1. 用安装 U 盘启动，连网
iwctl station wlan0 connect "WiFi名"

# 2. 挂载系统分区（根据实际设备名调整）
mount -o subvol=@ /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot
mount -o subvol=@home /dev/sda1 /mnt/home
mount -o subvol=@log /dev/nvme0n1p2 /mnt/var/log

# 3. chroot 进入系统
arch-chroot /mnt

# 4. 用 timeshift 回滚
timeshift --list
timeshift --restore --snapshot '2026-04-07_12-00-00'

# 5. 退出并重启
exit
umount -R /mnt
reboot
```

### 方法四：手动回滚 btrfs 快照（timeshift 不可用时）

```bash
# 从 U 盘启动后，挂载顶层子卷
mount -o subvolid=5 /dev/nvme0n1p2 /mnt

# 查看快照
ls /mnt/@snapshots/

# 把坏的 @ 改名，用快照替换
mv /mnt/@ /mnt/@broken
btrfs subvolume snapshot /mnt/@snapshots/timeshift-btrfs/snapshots/2026-04-07_12-00-00/@ /mnt/@

# 卸载并重启
umount /mnt
reboot
```

### Timeshift 日常使用

```bash
# 创建快照（更新前必做）
sudo timeshift --create --comments "更新前备份"

# 查看所有快照
sudo timeshift --list

# 删除旧快照
sudo timeshift --delete --snapshot '2026-04-01_12-00-00'

# 首次使用需要配置（选 BTRFS 模式）
sudo timeshift --setup
```

### 建议的快照节奏

- 装完系统稳定后：创建基线快照
- 每次 `pacman -Syu` 前：创建快照
- 安装重要软件前：创建快照
- 改系统配置前：创建快照

## 省心小技巧

- `checkupdates` 更新前先看看有哪些包要更新（pacman-contrib 提供）
- `yay` 更新时会提示 PKGBUILD 变更，养成看一眼的习惯
- 遇到 `.pacnew` 文件（配置文件冲突），用 `pacdiff` 处理

## 备份策略

- timeshift 只管系统快照，不管个人数据
- `/home` 里的重要文件建议定期备份到机械盘或网盘
- 简单备份：`rsync -av ~/重要目录 /data/backup/`

## HyDE 使用指南

官方文档：https://hydeproject.pages.dev/
主题预览：https://github.com/HyDE-Project/hyde-themes
快捷键完整列表：https://github.com/HyDE-Project/HyDE/blob/main/KEYBINDINGS.md

### 常用快捷键

**窗口管理：**
- `Ctrl + Q` — 关闭当前窗口
- `Super + W` — 切换浮动/平铺
- `Shift + F11` — 全屏
- `Super + L` — 锁屏
- `Alt + Tab` — 切换窗口焦点
- `Super + 方向键` — 切换焦点方向
- `Super + Shift + 方向键` — 调整窗口大小
- `Super + 鼠标左键拖动` — 移动窗口
- `Super + 鼠标右键拖动` — 调整窗口大小

**启动应用：**
- `Super + A` — 应用启动器（rofi）
- `Super + T` — 终端
- `Super + E` — 文件管理器
- `Super + B` — 浏览器
- `Super + C` — 文本编辑器
- `Super + V` — 剪贴板历史
- `Super + /` — 显示所有快捷键

**工作区：**
- `Super + 1~0` — 切换到工作区 1~10
- `Super + 鼠标滚轮` — 上/下一个工作区

**主题和壁纸：**
- `Super + Shift + T` — 选择主题
- `Super + Shift + W` — 选择壁纸
- `Super + Alt + ←/→` — 上/下一张壁纸

**截图：**
- `Super + P` — 截取区域
- `Print` — 截取全屏
- `Super + Shift + P` — 取色器

**音量：**
- `F11` / `F12` — 减小/增大音量
- `F10` — 静音

**退出：**
- `Alt + Ctrl + Delete` — 注销菜单
- `Super + Delete` — 关闭 Hyprland 会话

### 主题管理

```bash
# 查看快捷键（推荐先看这个）
Super + /

# 切换主题（rofi 菜单）
Super + Shift + T

# 命令行安装额外主题
hydeCtl theme import --name "主题名" --url "主题仓库URL"
```

### 配置文件位置

- Hyprland 主配置：`~/.config/hypr/hyprland.conf`
- HyDE 用户覆盖：`~/.config/hypr/userprefs.conf`（改这个，不要改主配置）
- Waybar：`~/.config/waybar/`
- Rofi：`~/.config/rofi/`
- 终端（kitty）：`~/.config/kitty/`

### 注意事项

- 自定义配置写在 `userprefs.conf`，HyDE 更新不会覆盖
- 不要直接改 `hyprland.conf`，HyDE 更新会覆盖
- `Super + /` 是你最好的朋友，忘了快捷键就按它
