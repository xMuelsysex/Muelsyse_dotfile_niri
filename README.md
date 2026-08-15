# Muelsyse Dotfiles (niri)

使用 [chezmoi](https://www.chezmoi.io/) 管理的 Arch Linux + niri 极简桌面配置文件集合，框架参照 [LanRhyme/dotfiles](https://github.com/LanRhyme/dotfiles)。

## 核心特性

- **动态主题联动**：基于 Noctalia 的壁纸色彩抓取，自动生成莫兰迪风格主题并覆盖终端、GTK/Qt、fastfetch、btop 等组件
- **模块化结构**：按应用解耦配置，niri 配置按模块拆分（`dms/`、`noctalia/`、`scripts/`）
- **敏感文件保护**：`.chezmoiignore` + `.gitignore` 双层隔离，密钥与隐私数据不入库
- **一键恢复**：一条命令在新设备复刻工作流

## 软件生态

| 分类 | 软件 |
| --- | --- |
| 窗口管理 | niri（Wayland 合成器） |
| 桌面交互 | noctalia（状态栏/主题引擎）、fuzzel（启动器） |
| Shell | fish + starship |
| 终端 | alacritty / ghostty / kitty / foot / wezterm |
| 输入法 | fcitx5 + Rime（雾凇拼音） |
| 监控 | btop / cava / fastfetch |
| 文件 | superfile / yazi |

## 极速部署

```bash
# 安装 chezmoi 与依赖（Arch 系）
sudo pacman -S chezmoi fish starship alacritty niri fcitx5

# 拉取并应用配置
chezmoi init --apply https://github.com/xMuelsysex/Muelsyse_dotfile_niri
```

## 核心配置导航

```
dot_config/
├── niri/                  # 合成器：config.kdl 主入口 + dms/ 模块化拆分 + scripts/
├── noctalia/              # 桌面栏与主题引擎、壁纸 hook、模板
├── fish/                  # Shell 配置与自定义函数
├── alacritty|ghostty|kitty|foot|wezterm/  # 终端矩阵
├── fastfetch|btop|cava/   # 监控工具
├── gtk-3.0|gtk-4.0|qt5ct|qt6ct/  # 主题联动
└── environment.d|autostart/      # 环境变量与自启动
dot_local/
├── bin/                   # 自定义脚本（niri-binds、noctalia-switch 等）
└── share/color-schemes/   # KDE/Qt 动态色彩
dot_pictures/Wallpapers/   # 壁纸库
```

## 敏感文件隔离

| 路径 | 原因 |
| --- | --- |
| `dot_local/share/fcitx5/rime/*userdb*` | 输入法个人词库 |
| `dot_config/gh/private_*.yml` | GitHub 凭据 |
| `dot_config/kdeconnect/*.pem` | 设备互信私钥 |
| `dot_config/noctalia/plugins/github-feed/settings.json` | GitHub Token |
| `dot_config/opencode/` | AI 工具凭据 |

新增密钥时执行：

```bash
echo "dot_config/app/secret.json" >> ~/.config/chezmoi/.chezmoiignore
```

## 同步指南

```bash
chezmoi diff    # 对比本地与源仓库
chezmoi apply   # 应用源仓库配置到本地
chezmoi re-add  # 把本地改动重新纳入源仓库
chezmoi cd      # 进入源仓库目录
```

## 许可证

MIT
