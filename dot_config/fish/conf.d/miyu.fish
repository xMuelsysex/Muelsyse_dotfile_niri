# miyu shell hook · v0.7.0 · 8f74113d
# 由 Miyu 生成，勿手改；重装 miyu fish-init

# PATH 上没有 miyu 时去常见安装目录里找(Homebrew、~/.local、cargo)。
if not type -q miyu
    for __miyu_dir in /opt/homebrew/bin /usr/local/bin /home/linuxbrew/.linuxbrew/bin ~/.local/bin ~/.cargo/bin
        if test -x $__miyu_dir/miyu
            set -g __miyu_bin $__miyu_dir/miyu
            function miyu
                $__miyu_bin $argv
            end
            break
        end
    end
    set -e __miyu_dir
end

complete -c miyu -n __fish_use_subcommand -f -a ask -d '向助手发送一条消息'
complete -c miyu -n __fish_use_subcommand -f -a init -d '创建默认配置和状态文件；Shell 集成请使用对应的 <shell>-init 命令'
complete -c miyu -n __fish_use_subcommand -f -a paths -d '显示应用配置、数据和缓存路径'
complete -c miyu -n __fish_use_subcommand -f -a config -d '打开或管理配置'
complete -c miyu -n __fish_use_subcommand -f -a reload -d '在运行中的 Miyu daemon 内重新加载配置'
complete -c miyu -n __fish_use_subcommand -f -a models -d '列出或切换模型'
complete -c miyu -n __fish_use_subcommand -f -a fish-init -d '集成到 fish，集成后可在终端直接使用自然语言交流。'
complete -c miyu -n __fish_use_subcommand -f -a bash-init -d '集成到 bash，集成后可在终端直接使用自然语言交流。'
complete -c miyu -n __fish_use_subcommand -f -a zsh-init -d '集成到 zsh，集成后可在终端直接使用自然语言交流。'
complete -c miyu -n __fish_use_subcommand -f -a remove-shell-hook -d '安全删除已安装的 Miyu shell hook'
complete -c miyu -n __fish_use_subcommand -f -a history -d '显示会话历史'
complete -c miyu -n __fish_use_subcommand -f -a kb -d '管理本地知识库'
complete -c miyu -n __fish_use_subcommand -f -a update-default-kb -d '更新 Miyu 默认知识库'
complete -c miyu -n __fish_use_subcommand -f -a memory -d '查看或编辑助手记忆'
complete -c miyu -n __fish_use_subcommand -f -a skills -d '管理助手 skills'
complete -c miyu -n __fish_use_subcommand -f -a reset -d '清空当前会话历史'

function __miyu_paste
    set -l output (miyu --clipboard-paste 2>/dev/null)
    if test $status -eq 0; and test -n "$output"
        if not set -q __miyu_image_counter
            set -g __miyu_image_counter 0
        end
        set __miyu_image_counter (math $__miyu_image_counter + 1)
        # 视频的占位符标签是 Video,只替 Image 的话第二个视频起序号永远是 1,
        # 解析端会把它们都当成第一个附件(08-28)。
        set output (string replace -r '^\[(Image|Video) 1' "[\$1 $__miyu_image_counter" -- $output)
        commandline -i -- $output
        commandline -f repaint
    else
        fish_clipboard_paste
    end
end

bind \cv __miyu_paste

function __miyu_insert_newline
    commandline -f expand-abbr
    commandline -i \n
end

bind ctrl-j __miyu_insert_newline
bind \cj __miyu_insert_newline
bind -M insert ctrl-j __miyu_insert_newline
bind -M insert \cj __miyu_insert_newline

function __miyu_wrap_fish_prompt
    functions -q __miyu_original_fish_prompt; and return
    functions -q fish_prompt; or fish_prompt >/dev/null 2>/dev/null
    functions -q fish_prompt; or return

    functions -c fish_prompt __miyu_original_fish_prompt
    function fish_prompt
        if set -q __miyu_pending_buffer
            printf '\e[?25l'
        end
        __miyu_original_fish_prompt
    end
end

function __miyu_replay_buffer
    set -l buffer $argv[1]
    set -l lines (string split \n -- "$buffer")
    if test (count $lines) -gt 0
        set -l prompt (fish_prompt | string collect -N)
        set -l prompt_lines (string split \n -- "$prompt")
        set -l prompt_col (math (string length --visible -- "$prompt_lines[-1]") + 1)
        printf '\e[?25l'
        printf '\e[1A\e[%sG' $prompt_col
        if not set -q fish_color_error; or not set_color $fish_color_error 2>/dev/null
            set_color red
        end
        printf '%s\n' "$lines[1]"
        for line in $lines[2..-1]
            printf '  %s\n' "$line"
        end
        set_color normal
    end
end

function __miyu_restore_cursor
    printf '\e[?25h'
    set -e __miyu_cursor_hidden
end

function __miyu_on_prompt --on-event fish_prompt
    set -q __miyu_pending_buffer; or return

    set -l buffer $__miyu_pending_buffer
    set -e __miyu_pending_buffer
    set -e __miyu_image_counter

    trap __miyu_restore_cursor INT TERM EXIT
    __miyu_replay_buffer "$buffer"
    printf '\n'
    printf '%s' "$buffer" | miyu --shell-intercept --shell fish --stdin
    set -l miyu_status $status
    trap - INT TERM EXIT
    __miyu_restore_cursor
    return $miyu_status
end

function __miyu_execute_or_continue
    commandline --is-valid
    set -l valid_status $status
    if test $valid_status -eq 2
        commandline -i \n
        commandline -f repaint
    else
        set -e __miyu_image_counter
        commandline -f execute
    end
end

function __miyu_buffer_is_multiline
    test (string split \n -- "$argv[1]" | count) -gt 1
end

function __miyu_first_command
    set -l tokens (commandline --input="$argv[1]" --tokens-expanded 2>/dev/null)
    while test (count $tokens) -gt 0
        set -l token $tokens[1]
        if string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- "$token"
            set -e tokens[1]
            continue
        end
        printf '%s' "$token"
        return 0
    end
    return 1
end

# 只看首词长什么样,所以取未展开的原文:--tokens-expanded 会真的跑命令替换,
# 放在每次回车上按不得。老版本 fish 不认 --tokens-raw,拿不到就当判不出来。
function __miyu_first_token_raw
    set -l tokens (commandline --input="$argv[1]" --tokens-raw 2>/dev/null)
    while test (count $tokens) -gt 0
        set -l token $tokens[1]
        if string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- "$token"
            set -e tokens[1]
            continue
        end
        printf '%s' "$token"
        return 0
    end
    return 1
end

# 首词是不是一个「展开后还是它自己」的普通词。$ ( ) ~ { } % 引号反斜杠这些会把
# 首词换成别的东西,判不出来就交回 fish 自己展开,这里不猜;; & | < > # ^ ! 和空白
# 同理,出现了说明这行有 fish 语法结构。
# 通配符 * ? [ ] 故意不在名单里:命令位上出现通配符,本来就说明这不是个命令名。
# 不能用 \w 白名单——fish 的正则里 \w 只认 ASCII,中文会被当成元字符。
function __miyu_head_is_plain_word
    test -n "$argv[1]"; or return 1
    string match -qr '[\x27"$()~{}%;&|<>#^!\x5c\s]' -- "$argv[1]"; and return 1
    return 0
end

function __miyu_hand_to_ai
    set -e __miyu_image_counter
    __miyu_wrap_fish_prompt
    set -g __miyu_cursor_hidden 1
    history append -- "$argv[1]"
    set -g __miyu_pending_buffer "$argv[1]"
    commandline -b -- ""
    printf '\e[?25l'
    commandline -f execute
end

function __miyu_accept_line
    status is-interactive; or return

    commandline -f expand-abbr
    set -l buffer (commandline -b | string collect)
    set -l trimmed (string trim -- "$buffer")
    if test -z "$trimmed"
        __miyu_execute_or_continue
        return
    end

    if not __miyu_buffer_is_multiline "$buffer"
        # 单行本来靠 fish_command_not_found 兜底,但 fish 是先展开再找命令:
        # 自然语言里带个没匹配上的通配符(「输出这段命令 …/core.*.zst」),
        # fish 在展开阶段就报「未找到通配符的匹配项」,命令根本没开始找,
        # 兜底函数也就永远不触发。首词是普通词又不是任何命令时提前接管。
        set -l head (__miyu_first_token_raw "$buffer")
        if not __miyu_head_is_plain_word "$head"; or type -q -- "$head"
            __miyu_execute_or_continue
            return
        end
        __miyu_hand_to_ai "$buffer"
        return
    end

    set -l first_command (__miyu_first_command "$buffer")
    if test -n "$first_command"; and not contains -- "$first_command" time test date which type command history; and type -q -- "$first_command"
        __miyu_execute_or_continue
        return
    end

    printf '%s' "$buffer" | miyu --shell-classify --shell fish --stdin 2>/dev/null
    set -l classify_status $status
    if test $classify_status -eq 0
        __miyu_execute_or_continue
        return
    else if test $classify_status -ne 1
        __miyu_execute_or_continue
        return
    end

    __miyu_hand_to_ai "$buffer"
end

bind enter __miyu_accept_line
bind \r __miyu_accept_line
bind -M insert enter __miyu_accept_line
bind -M insert \r __miyu_accept_line

function fish_command_not_found
    status is-interactive; or return 127

    set -e __miyu_image_counter

    set -l current_line (status current-commandline 2>/dev/null | string collect)
    if test -n "$current_line"; and not string match -qr '[\n\r]' -- "$current_line"
        set -l top_command (__miyu_first_command "$current_line")
        if test -z "$top_command"; or not type -q -- "$top_command"
            printf '\n'
            printf '%s' "$current_line" | miyu --shell-intercept --shell fish --stdin 2>/dev/null
            return 127
        end
    end

    set -l command $argv
    if test (count $command) -eq 0
        return 127
    end

    set -l text (string join ' ' -- $command)
    string match -qr '[\n\r]' -- $text; and return 127

    miyu --shell-intercept --shell fish -- $command 2>/dev/null
    return 127
end
