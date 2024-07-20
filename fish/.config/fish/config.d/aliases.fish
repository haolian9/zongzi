
alias z='eval $(zd)'
alias z.='zd .'

begin # 对原有命令的修改
    alias dig='dig +short'
    alias less=~/.scripts/less.sh
    alias more=~/.scripts/less.sh
    alias info='info --vi-keys'
    # a: with args, A: ascii, c: no compation, n: sort by pid, p: show pids, t: show threads full name
    alias pstree='pstree -aAcnpt'
    alias screenkey='screenkey --persist --position bottom --font-size medium --key-mode raw --font "Monego" --opacity 0.6'
    alias nvim='nvim --luamod-dev'
end

begin # from wiki.archlinux
    alias mkdir='mkdir -p -v'

    alias ls='ls -hF --color=auto'
    alias ll='ls -l'
    alias lx='ls -BX' # sort by extension
    alias lz='ls -rS' # sort by size
    alias lt='ls -rt' # sort by date

    alias cls=' echo -ne "\033c"' # clear screen for real (it does not work in Terminology)

    alias :q='exit'
    alias :x='exit'

    if fish_is_root_user
        alias reboot='sudo systemctl reboot'
        alias poweroff='sudo systemctl poweroff'
    end
end
