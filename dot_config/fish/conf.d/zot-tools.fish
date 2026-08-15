# >>> zot 终端工具集成 (2026-07-28) >>>
# zoxide 智能 cd (z / zi 命令)
if command -v zoxide &>/dev/null
    zoxide init fish | source
end

# eza 增强别名
alias ll 'eza -lah --group-directories-first'
alias lt 'eza --tree --group-directories-first'
# <<< zot 终端工具集成 <<<
