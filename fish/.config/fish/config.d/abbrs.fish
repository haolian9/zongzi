# alias :a='tmux a -t '
abbr -a :a tmux a -t

#alias ..='cd ..' #alias ...='cd ../../' #alias ....='cd ../../../'
function _multicd
    echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
end
abbr --add dotdot --regex '^\.\.+$' --function _multicd

