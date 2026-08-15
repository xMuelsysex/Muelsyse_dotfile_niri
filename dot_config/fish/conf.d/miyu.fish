function __miyu_paste
    set -l output (miyu --clipboard-paste 2>/dev/null)
    if test $status -eq 0; and test -n "$output"
        if not set -q __miyu_image_counter
            set -g __miyu_image_counter 0
        end
        set __miyu_image_counter (math $__miyu_image_counter + 1)
        set output (string replace "Image 1" "Image $__miyu_image_counter" -- $output)
        commandline -i -- $output
        commandline -f repaint
    else
        fish_clipboard_paste
    end
end

bind \cv __miyu_paste

function fish_command_not_found
    status is-interactive; or return 127

    set -e __miyu_image_counter

    set -l command $argv
    if test (count $command) -eq 0
        return 127
    end

    set -l text (string join ' ' -- $command)
    string match -qr '[\n\r]' -- $text; and return 127

    miyu --shell-intercept --shell fish -- $command 2>/dev/null
    return 127
end
