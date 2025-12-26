function fish_right_prompt
    test "$fish_key_bindings" != fish_vi_key_bindings; and return

    switch $fish_bind_mode
        case insert
            :
        case default
            echo -ns '[N]'
        case replace replace_one
            echo -ns '[R]'
        case visual
            echo -ns '[V]'
        case leader
            echo -ns '[L]'
    end
end

