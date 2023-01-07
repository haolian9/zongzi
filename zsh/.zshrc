# rules
# * avoid `&>/dev/null` which will hide potential errors

# settings {{

fpath=( ~/.config/zsh-comp/zig "${fpath[@]}" )

autoload -U compinit promptinit
compinit
promptinit

HISTFILE=~/.zsh_history
HISTSIZE=500
SAVEHIST=500
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt HIST_SAVE_BY_COPY
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

bindkey -v

# in vi-mode, type `v` to edit
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

unalias run-help 2>/dev/null
autoload run-help

autoload -U add-zsh-hook
add-zsh-hook -Uz chpwd (){
    echo -n -e "\033]0;z:$(basename ${PWD})\007"
}

# stole from the fzf package and simplified
# CTRL-R - Paste the selected command from history into the command line
fzf-history-widget() {
  local selected=($(fc -li | fzf --layout=reverse --height=30% --min-height=10))
  local ret=$?
  if [ -n "$selected" ]; then
    num=$selected[1]
    if [ -n "$num" ]; then
      zle vi-fetch-history -n $num
    fi
  fi
  zle reset-prompt
  return $ret
}
zle     -N fzf-history-widget
bindkey -M viins '^R' fzf-history-widget

# }}

# alias {{

alias p='proxychains -q '

alias discaps='setxkbmap -option caps:none'

# clear complete cache
# see https://unix.stackexchange.com/questions/2179/rebuild-auto-complete-index-or-whatever-its-called-and-binaries-in-path-cach/2180
alias ccc='rehash'

# tmux
alias :a="tmux a -t "

# git
alias .st='git status'
alias .co='git checkout'
alias .ci='git commit'
alias .br='git branch'
alias .sb='git submodule'
alias .rb='git rebase'
alias .rt='git remote'
alias .ft='git fetch'
alias .lg="git log --graph --decorate --all --pretty=format:'%C(red)%h%C(reset) %C(blue)%d%C(reset) %s'"
alias .df="git diff"

# 原有命令的修改
alias dig='dig +short'
alias less=~/.scripts/less.sh
alias more=~/.scripts/less.sh
alias info='info --vi-keys'
# a: with args, A: ascii, c: no compation, n: sort by pid, p: show pids, t: show threads full name
alias pstree='pstree -aAcnpt'
alias screenkey='screenkey --persist --position bottom --font-size medium --key-mode raw --font "Monego" --opacity 0.6'

alias z='eval $(zd)'
alias z.='zd .'
alias zl='zd list'

# }}

# alias from wiki.archlinux {{

# Modified commands
alias mkdir='mkdir -p -v'

# New commands
alias openports='ss --all --numeric --processes --ipv4 --ipv6'
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
alias lx='ll -BX'                   # sort by extension
alias lz='ll -rS'                   # sort by size
alias lt='ll -rt'                   # sort by date

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
    export ftp_proxy=$http_proxy
    export rsync_proxy=$http_proxy

    echo "Proxy environment variable set."
}

function proxy_off {
    unset http_proxy
    unset https_proxy
    unset ftp_proxy
    unset rsync_proxy
    echo -e "Proxy environment variable removed."
}

# }}

# plugins {{

# if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
#     source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# fi

# }}

# completions {{

# ~/.scripts/:h
compdef :h=man

# }}

# external tools {{

export FZF_DEFAULT_OPTS=' --multi --cycle --no-hscroll --ansi --info=inline --no-mouse'

if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# }}

# docker specify {{

if { ip route | grep default | grep "via 172\." } &>/dev/null; then

    if tmux ls &>/dev/null; then
        tmux set-option -g status-bg colour1
        tmux set-option -g status-fg colour15
    fi

    function notify-send {
        ssh "$USERNAME@$HOST_IP" notify-send workstation "'$@'"
    }

fi

# }}

# local settings {{
if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi
# }}

# vim: fen:fdm=marker:fmr={{,}}
