#!/usr/bin/env bash

[ -f "$HOME/.xprofile" ] && source "$HOME/.xprofile"

for f in "$HOME/.Xresources" "/etc/X11/xinit/.Xresources"; do
    [ -f $f ] && xrdb -merge "$f"
done

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && source "$f"
  done
fi

exec i3
