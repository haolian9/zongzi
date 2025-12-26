# todo: maybe use fish_add_path instead
source $__fish_config_dir/config.d/profile.fish

status is-interactive; or return

begin #behaviors
    set -g fish_autosuggestion_enabled 0

    fish_vi_key_bindings

    # since i have tmux, fish's visual mode isnt that useful
    bind -M default v :

    begin # cursor shape between vi modes

        # to disable tons of checks in fish_vi_cursor()
        set fish_vi_force_cursor 1
        # Set the normal and visual mode cursors to a block
        set fish_cursor_default block
        # Set the insert mode cursor to a line
        set fish_cursor_insert line
        # Set the replace mode cursors to an underscore
        set fish_cursor_replace_one underscore
        set fish_cursor_replace underscore
        # Set the external cursor to a line. The external cursor appears when a command is started.
        # The cursor shape takes the value of fish_cursor_default when fish_cursor_external is not specified.
        set fish_cursor_external line
    end
end

source $__fish_config_dir/config.d/aliases.fish
source $__fish_config_dir/config.d/abbrs.fish
source $__fish_config_dir/config.d/pending_mode.fish
source $__fish_config_dir/config.d/cli_rc.fish

begin # completions
    complete -c x -w ssh
    complete -c :h -w man
    complete -c vi -w nvim
    complete -c ni -w nvim
    complete -c pkgconf -w pkg-conf
end

source $__fish_config_dir/config.d/local.fish
