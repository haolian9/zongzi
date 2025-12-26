#!/bin/sh

#just like /etc/X11/xinit/xinitrc
[ -f "$HOME/.xprofile" ] && source "$HOME/.xprofile"

xrdb -load $HOME/.Xresources
#no sourcing /etc/X11/xinit/xinitrc.d/*.sh, as 50-systemd-user.sh does not work well with multiple sessions of the same user
#no sourcing /etc/X11/xinit/.Xresources, as it does not exist all the time

exec ${WM:-i3}
