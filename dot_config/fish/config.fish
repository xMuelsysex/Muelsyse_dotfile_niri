test ! -e "$HOME/.x-cmd.root/local/data/fish/rc.fish" || source "$HOME/.x-cmd.root/local/data/fish/rc.fish" # boot up x-cmd.
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# 代理配置 (Proxy Configuration) — 修改此处以适配你的代理端口
set -g PROXY_ADDR "127.0.0.1:7890"

# 开启代理 (支持自定义端口或地址，如: proxy_on 10808 或 proxy_on 192.168.1.5:7890)
function proxy_on
    set -l addr "$PROXY_ADDR"
    if test (count $argv) -gt 0
        if string match -r '^\d+$' -- $argv[1]
            set addr "127.0.0.1:$argv[1]"
        else
            set addr "$argv[1]"
        end
    end

    set -gx http_proxy "http://$addr"
    set -gx https_proxy "http://$addr"
    set -gx all_proxy "socks5://$addr"
    set -gx HTTP_PROXY "http://$addr"
    set -gx HTTPS_PROXY "http://$addr"
    set -gx ALL_PROXY "socks5://$addr"
    echo "[+] 终端代理已开启 (Proxy: $addr)"
end

# 关闭代理
function proxy_off
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e HTTP_PROXY
    set -e HTTPS_PROXY
    set -e ALL_PROXY
    echo "[-] 终端代理已关闭"
end

# 查看代理状态
function proxy_status
    echo "--- 代理环境变量 (Proxy Env) ---"
    for var in http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
        if set -q $var
            echo "$var: "$$var
        else
            echo "$var: [未设置]"
        end
    end

    echo ""
    echo "--- 连通性测试 (Connectivity) ---"
    echo -n "测试 Google.com... "
    set -l start (date +%s%3N)
    set -l code (curl -I -s --connect-timeout 3 -o /dev/null -w "%{http_code}" https://www.google.com 2>/dev/null)
    set -l end (date +%s%3N)
    if test "$code" = "200" -o "$code" = "301" -o "$code" = "302"
        set -l duration (math $end - $start)
        echo "成功 (HTTP $code, $duration ms)"
    else
        echo "失败"
    end

    echo -n "测试 GitHub.com... "
    set -l gh_start (date +%s%3N)
    set -l gh_code (curl -I -s --connect-timeout 3 -o /dev/null -w "%{http_code}" https://github.com 2>/dev/null)
    set -l gh_end (date +%s%3N)
    if test "$gh_code" = "200" -o "$gh_code" = "301" -o "$gh_code" = "302"
        set -l gh_duration (math $gh_end - $gh_start)
        echo "成功 (HTTP $gh_code, $gh_duration ms)"
    else
        echo "失败"
    end

    echo ""
    echo "--- IP 地理位置 (IP Location) ---"
    curl -s -m 3 cip.cc 2>/dev/null | head -n 3
end

function ask_agy
    proxy_on
    agy $argv
end

# ==============================================================================
# NyxNiri TUI Cheatsheet 助手 (唯一指令: nyxhelp)
# ==============================================================================
function nyxhelp --description "NyxNiri Cheatsheet速查手册"
    set -l section ""
    if test (count $argv) -gt 0
        if test "$argv[1]" = "--section" -a (count $argv) -ge 2
            set section $argv[2]
        else
            set section $argv[1]
        end
    end

    switch "$section"
        case header
            echo ""
            set_color -o cyan; echo "  [ NyxNiri Dotfiles 终端与桌面速查手册 ]"; set_color normal
            echo ""
            return
        case cli
            set_color -o magenta; echo "  [ NyxNiri CLI & 配置快照 ]"; set_color normal
            set_color -o yellow; echo -n "     nyxniri                 "; set_color green; echo "-> 打开控制面板主菜单"; set_color normal
            set_color -o yellow; echo -n "     nyxniri doctor          "; set_color green; echo "-> 运行系统全要素诊断"; set_color normal
            set_color -o yellow; echo -n "     nyxniri snapshot [备注] "; set_color green; echo "-> 创建配置安全快照"; set_color normal
            set_color -o yellow; echo -n "     nyxniri rollback [序号] "; set_color green; echo "-> 恢复历史配置快照"; set_color normal
            set_color -o yellow; echo -n "     nyxniri list            "; set_color green; echo "-> 查看所有配置快照"; set_color normal
            return
        case proxy
            set_color -o magenta; echo "  [ 网络代理控制 ]"; set_color normal
            set_color -o yellow; echo -n "     proxy_on [端口/地址]    "; set_color green; echo "-> 开启代理 (默认 127.0.0.1:7890，Starship 实时显示)"; set_color normal
            set_color -o yellow; echo -n "     proxy_off               "; set_color green; echo "-> 关闭代理 (清除环境变量与 Prompt 标识)"; set_color normal
            set_color -o yellow; echo -n "     proxy_status            "; set_color green; echo "-> 检查代理连通性、延迟与公网 IP"; set_color normal
            return
        case pkg
            set_color -o magenta; echo "  [ 包管理与清理 ]"; set_color normal
            set_color -o yellow; echo -n "     up / update             "; set_color green; echo "-> 运行 shelly 一键全量更新"; set_color normal
            set_color -o yellow; echo -n "     in <包名>               "; set_color green; echo "-> 运行 shelly 安装软件包"; set_color normal
            set_color -o yellow; echo -n "     se                      "; set_color green; echo "-> 模糊搜索软件包并 fzf 交互安装"; set_color normal
            set_color -o yellow; echo -n "     un                      "; set_color green; echo "-> 模糊搜索已安装包并 fzf 交互卸载"; set_color normal
            set_color -o yellow; echo -n "     clean [--auto]          "; set_color green; echo "-> 扫描并清理大缓存与日志垃圾"; set_color normal
            return
        case keys bind keybindings
            set_color -o magenta; echo "  [ Niri 桌面核心快捷键 ]"; set_color normal
            set_color -o blue; echo -n "     Mod + Return            "; set_color green; echo "-> 启动 Kitty 终端"; set_color normal
            set_color -o blue; echo -n "     Mod + R / Mod + E       "; set_color green; echo "-> 启动 Noctalia Launcher / Nautilus"; set_color normal
            set_color -o blue; echo -n "     Mod + Q                 "; set_color green; echo "-> 关闭当前窗口"; set_color normal
            set_color -o blue; echo -n "     Mod + Tab               "; set_color green; echo "-> 切换工作区概览 (Overview)"; set_color normal
            set_color -o blue; echo -n "     Mod + Space             "; set_color green; echo "-> 切换预设列宽比例"; set_color normal
            set_color -o blue; echo -n "     Mod + T                 "; set_color green; echo "-> 切换窗口 浮动 / 平铺"; set_color normal
            set_color -o blue; echo -n "     Mod + F / Shift+F       "; set_color green; echo "-> 最大化列宽 / 全屏窗口"; set_color normal
            set_color -o blue; echo -n "     Mod + N                 "; set_color green; echo "-> 切换护眼暖色温模式"; set_color normal
            set_color -o blue; echo -n "     Mod + L                 "; set_color green; echo "-> 锁定屏幕 (Noctalia Lock)"; set_color normal
            set_color -o blue; echo -n "     Mod + Shift + S / Print "; set_color green; echo "-> 交互式区域截图"; set_color normal
            set_color -o blue; echo -n "     Mod + Shift + R         "; set_color green; echo "-> 重载 Niri 桌面配置"; set_color normal
            set_color -o blue; echo -n "     Mod + Slash (/)        "; set_color green; echo "-> 显示 Niri 原生按键覆盖层"; set_color normal
            return
        case shell
            set_color -o magenta; echo "  [ 终端补全与 fzf ]"; set_color normal
            set_color -o blue; echo -n "     Tab                     "; set_color green; echo "-> 采纳补全 / 触发列表补全"; set_color normal
            set_color -o blue; echo -n "     Ctrl + R                "; set_color green; echo "-> fzf 模糊搜索历史命令"; set_color normal
            set_color -o blue; echo -n "     Ctrl + Alt + F          "; set_color green; echo "-> fzf 模糊查找文件"; set_color normal
            set_color -o blue; echo -n "     Ctrl + Alt + L / S      "; set_color green; echo "-> fzf 浏览 Git Log / Status"; set_color normal
            return
    end

    if test -n "$section"
        nyxhelp header
        for sec in cli proxy pkg keys shell
            nyxhelp --section $sec
            echo ""
        end
        return
    end

    # Interactive TUI mode (when fzf is present & in interactive shell)
    if command -v fzf &>/dev/null; and status is-interactive
        set -l choices \
            "1. cli    NyxNiri CLI & 配置快照" \
            "2. proxy  网络代理控制 (Proxy)" \
            "3. pkg    包管理与缓存清理 (Shelly)" \
            "4. keys   Niri 桌面核心快捷键" \
            "5. shell  终端自动补全与 fzf 导航" \
            "6. all    显示全量手册 (Full Cheatsheet)"

        set -l selection (printf '%s\n' $choices | fzf \
            --prompt="nyxhelp > " \
            --header="指令: nyxhelp | [↑/↓] 移动 | [Enter] 选定 | [Esc] 退出" \
            --preview-window="right:65%:wrap" \
            --preview="fish -c 'nyxhelp --section {2}'"
        )
    else
        nyxhelp --section all
    end
end

if status is-interactive
    # No greeting
    set fish_greeting

    # Tab 智能自动补全：优先采纳灰色历史建议，无建议时触发 Tab 列表补全
    function custom_tab_complete
        if commandline -f accept-autosuggestion
            # 成功采纳自动提示建议
        else
            commandline -f complete
        end
    end

    function fish_user_key_bindings
        # 绑定 Tab 键
        bind \t custom_tab_complete
    end

    # Use starship prompt
    if command -v starship &>/dev/null
        starship init fish | source
    end

    # Aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear scrollback properly
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    
    # Shelly 统一包管理别名 (CachyOS 官方推荐)
    alias up='shelly upgrade-all'                 # 一键更新官方包、AUR、Flatpak、AppImage
    alias update='shelly upgrade-all'             # 同上，完整拼写
    alias in='shelly install'                     # 安装软件包 (支持官方源/AUR/Flatpak)
    alias clean='~/.config/fish/clean-cache'      # 运行一键缓存清理脚本

    # se：模糊搜索软件包 (官方源 + AUR) 并用 fzf 交互安装
    function se --description "模糊搜索并安装软件包 (官方源 + AUR)"
        set -l helper "pacman"
        if command -v paru &>/dev/null
            set helper "paru"
        else if command -v yay &>/dev/null
            set helper "yay"
        end

        set -l pkgs
        if test "$helper" = "paru"
            set pkgs (paru -Slq | fzf --multi --prompt='📦 安装 > ' \
                --preview 'paru -Si {1}' --preview-window 'right:60%:wrap')
            test -n "$pkgs"; and paru -S $pkgs
        else if test "$helper" = "yay"
            set pkgs (yay -Slq | fzf --multi --prompt='📦 安装 > ' \
                --preview 'yay -Si {1}' --preview-window 'right:60%:wrap')
            test -n "$pkgs"; and yay -S $pkgs
        else
            set pkgs (pacman -Slq | fzf --multi --prompt='📦 安装 > ' \
                --preview 'pacman -Si {1}' --preview-window 'right:60%:wrap')
            test -n "$pkgs"; and sudo pacman -S $pkgs
        end
    end

    # un：模糊搜索已安装的包并用 fzf 交互卸载
    function un --description "模糊搜索并卸载已安装软件包"
        set -l remove_cmd "sudo pacman -Rns"
        if command -v paru &>/dev/null
            set remove_cmd "paru -Rns"
        else if command -v yay &>/dev/null
            set remove_cmd "yay -Rns"
        end

        set -l pkgs (pacman -Qq | fzf --multi --prompt='🗑  卸载 > ' \
            --preview 'pacman -Qi {1}' --preview-window 'right:60%:wrap')
        test -n "$pkgs"; and eval "$remove_cmd $pkgs"
    end
    
    if command -v eza &>/dev/null
        alias ls 'eza --icons=auto'
    end
end

# pi-agent maestro CLI
fish_add_path "$HOME/.pi/agent/npm/node_modules/.bin"
