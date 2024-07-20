function _pending_rhs_hist_fzf
    set -l cmd (history --max 200 | fzf)
    if test -n "$cmd"
        echo $cmd
        eval $cmd
    end
    commandline -f repaint
end

function _pending_rhs_zd
    set -l expr (zd)
    if test -n "$expr"
        eval $expr
    end
    commandline -f repaint
end

function _pending_rhs_olds
    vi +'lua require"fond".olds(false)'
end

# ctrl-space
bind -M insert -m leader -k nul repaint-mode
bind -M normal -m leader -k nul repaint-mode
bind -M visual -m leader -k nul repaint-mode

bind -M leader -m insert s _pending_rhs_hist_fzf
bind -M leader -m insert z _pending_rhs_zd
bind -M leader -m insert f _pending_rhs_olds

bind -M leader -m insert \e repaint
bind -M leader -m insert \r repaint
bind -M leader -m insert \cC repaint
