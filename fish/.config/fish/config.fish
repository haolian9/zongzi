if status is-login #honor profile
    # in archlinux
    # * /bin linked to /usr/bin
    # * /usr/sbin /sbin linked to /usr/bin
    set -gx PATH
    set PATH ~/.scripts ~/bin ~/.local/bin
    # see /etc/profilee
    set -a PATH /usr/bin /usr/local/bin
    if fish_is_root_user
        set -a PATH /usr/local/sbin
    end

    # see /etc/profile.d/locale.sh
    set -x LC_ALL en_US.UTF-8
    set -x LANG en_US.UTF-8

    set -x EDITOR nvim
    set -x PAGER less

    set -x GOPATH ~/.go
    set -x GO111MODULE on
    # or https://mirrors.aliyun.com/goproxy/
    set -x GOPROXY https://mirrors.cloud.tencent.com/go/
end

status is-interactive; or return

begin #behaviors
    set -g fish_autosuggestion_enabled 0

    fish_vi_key_bindings
end


begin # completions
    complete -c dock -w ssh
    complete -c :h -w man
    complete -c vi -w nvim
    complete -c pkgconf -w pkg-conf
end

begin # aliases|abbr
    # alias :a='tmux a -t '
    abbr -a :a tmux a -t

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
    end

    begin # from wiki.archlinux
        alias mkdir='mkdir -p -v'

        #alias ..='cd ..' #alias ...='cd ../../' #alias ....='cd ../../../'
        function multicd
            echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
        end
        abbr --add dotdot --regex '^\.\.+$' --function multicd

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
end

begin #external tools
    set -x FZF_DEFAULT_OPTS --multi --cycle --no-hscroll --ansi --info=inline --no-mouse --bind space:accept

    if test $BGMODE = dark
        set -x LS_COLORS 'di=97:fi=97:ln=97'
    else
        set -x LS_COLORS 'di=30:fi=30:ln=30'
    end
end

begin #leader mode
    function _rhs_hist_fzf
        set -l cmd (history --max 200 | fzf)
        if test -n "cmd"
            echo $cmd
            eval $cmd
        end
        commandline -f repaint
    end

    function _rhs_zd
        set -l expr (zd)
        if test -n "$expr"
            eval $expr
        end
        commandline -f repaint
    end

    # ctrl-space
    bind -M insert -m leader -k nul repaint-mode
    bind -M normal -m leader -k nul repaint-mode
    bind -M visual -m leader -k nul repaint-mode

    bind -M leader -m insert s  _rhs_hist_fzf
    bind -M leader -m insert z  _rhs_zd

    bind -M leader -m insert \e repaint
    bind -M leader -m insert \r repaint
    bind -M leader -m insert \cC repaint

    bind -M leader -m insert \cD exit
end
