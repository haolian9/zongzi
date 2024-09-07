# see /usr/share/fish/functions/fish_default_mode_prompt.fish

if false
    function fish_mode_prompt
        test "$fish_key_bindings" != fish_vi_key_bindings; and return

        switch $fish_bind_mode
            case insert
                :
            case default
                echo -ns 'N '
            case replace replace_one
                echo -ns 'R '
            case visual
                echo -ns 'V '
            case leader
                echo -ns 'L '
        end
    end
else
    function fish_mode_prompt
    end
end

