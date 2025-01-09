# rules
# * avoid `&>/dev/null` which will hide potential errors

# settings {{

# "{pwd} {exitcode}"
if [ "$BGMODE" = 'dark' ]; then
    export PS1='%1~ %(?..%F{red}%? %F{white})'
else
    export PS1='%1~ %(?..%F{red}%? %F{black})'
fi

autoload -U compinit promptinit
compinit
promptinit

bindkey -v
# in vi-mode, type `v` to edit
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# title using pwd
autoload -U add-zsh-hook
add-zsh-hook -Uz chpwd (){
    echo -n -e "\033]0;z:$(basename ${PWD})\007"
}
# }}

# alias {{

alias p='proxychains -q '

# clear complete cache
# see https://unix.stackexchange.com/questions/2179/rebuild-auto-complete-index-or-whatever-its-called-and-binaries-in-path-cach/2180
alias ccc='rehash'

# tmux
alias :a="tmux a -t "

# zd
alias z='eval $(zd)'
alias z.='zd .'

# 对原有命令的修改
alias dig='dig +short'
alias less=~/.scripts/less.sh
alias more=~/.scripts/less.sh
alias info='info --vi-keys'
# a: with args, A: ascii, c: no compation, n: sort by pid, p: show pids, t: show threads full name
alias pstree='pstree -aAcnpt'
alias screenkey='screenkey --persist --position bottom --font-size medium --key-mode raw --font "Monego" --opacity 0.6'
alias nvim='nvim --luamod-dev'

# }}

# alias from wiki.archlinux {{

# Modified commands
alias mkdir='mkdir -p -v'

# New commands
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'

# Privileged access
if [ $UID -ne 0 ]; then
    alias reboot='sudo systemctl reboot'
    alias poweroff='sudo systemctl poweroff'
fi

# ls
alias ls='ls -hF --color=auto'
alias ll='ls -l'
alias lx='ls -BX'                   # sort by extension
alias lz='ls -rS'                   # sort by size
alias lt='ls -rt'                   # sort by date

# Safety features
alias cls=' echo -ne "\033c"'       # clear screen for real (it does not work in Terminology)

# Make Bash error tolerant
alias :q=' exit'
alias :Q=' exit'
alias :x=' exit'
alias cd..='cd ..'

# }}

# functions {{

function proxy_on {
    export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"

    local addr="${1:-127.0.0.1:8118}"

    valid=$(echo $addr | sed -n 's/\([0-9]\{1,3\}\.\?\)\{4\}:\([0-9]\+\)/&/p')
    if [ $valid != $addr ]; then
        >&2 echo "Invalid address: '$addr'"
        return 1
    fi

    echo "setting proxy, using config: '$addr'"
    export http_proxy="http://$addr/"
    export https_proxy=$http_proxy

    echo "Proxy environment variable set."
}

function proxy_off {
    unset http_proxy
    unset https_proxy
    echo -e "Proxy environment variable removed."
}

# }}

# completions {{

#for ~/.scripts/:h; 230503 not works anymore
#compdef :h=man

compdef dock=ssh

# }}

# external tools {{

export FZF_DEFAULT_OPTS=' --multi --cycle --no-hscroll --ansi --info=inline --no-mouse --bind space:accept'

if [ "$BGMODE" = "dark" ]; then
    export LS_COLORS='di=97:fi=97:ln=97'
else
    export LS_COLORS='di=30:fi=30:ln=30'
fi

# }}

source ~/.zshrc.local

# vim:fdm=marker:fmr={{,}}
