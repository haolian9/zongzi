# see the default: /usr/share/fish/functions/fish_prompt.fish
function fish_prompt
    set -l last_status $status

    set -l parts
    begin
        set -l color_reset (set_color normal)
        set -l color_path (set_color black)
        if test "$BGMODE" = dark
            set color_path (set_color white)
        end

        set -a parts $color_path (prompt_pwd) $color_reset
        if test "$last_status" -ne 0
            set -a parts " " (set_color red) $last_status (set_color normal)
        end
        set -a parts " "
    end

    echo -ns $parts
end
