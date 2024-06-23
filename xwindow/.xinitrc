#!/bin/sh

#just like /etc/X11/xinit/xinitrc
[ -f "$HOME/.xprofile" ] && source "$HOME/.xprofile"
for f in "$HOME/.Xresources" "/etc/X11/xinit/.Xresources"; do
    [ -f $f ] && xrdb -merge "$f"
done
#no sourcing /etc/X11/xinit/xinitrc.d/*.sh, as 50-systemd-user.sh does not work well with multiple sessions of the same user

exec ${WM:-i3}
