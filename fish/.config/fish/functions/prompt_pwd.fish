function prompt_pwd
    set -l path $PWD
    if test "$path" != /
        set path (string trim -rc '/' $path)
    end

    set -l home (string trim -rc / $HOME)
    set -l home_len (string length $home)
    if test (string sub -e $home_len $path) = $home
        set -l remain_len (math (string length $path) - $home_len)
        if test $remain_len -eq 0
            set path '~'
        else
            set path '~'(string sub -s -$remain_len $path)
        end
    end

    echo $path
end
