#!/usr/bin/env bash

# requirements
# * xdotool, xprop, notify-send
# * browser (of course)

declare -A history_keymap=(
["firefox"]="alt+Left alt+Right"
["chromium"]="alt+Left alt+Right"
["vimb"]="ctrl+o ctrl+i"
["vivaldi-stable"]="alt+Left alt+Right"
)

# 0 => back, 1 => forward
# see history_keymap.value
declare -i history_op=0

_browser() {
    xdotool getwindowfocus getwindowclassname | tr -s '[:upper:]' '[:lower:]'
}

parse_flag() {
    for flag; do
        case "$flag" in
            forward|--forward|-f)
                history_op=1
                ;;
            back|--back|-b)
                history_op=0
                ;;
        esac
    done
}

notify() {
    notify-send "gesture" "$*"
}

main() {
    local browser

    browser=$(_browser) || {
        notify "can not get browser window info"
        return 1
    }

    if [ -z "${history_keymap[$browser]}" ]; then
        notify "can not found keystroke definition for browser '$browser'"
        return 1
    fi

    local keystroke=($(echo "${history_keymap[$browser]}"))

    exec xdotool key "${keystroke[$history_op]}"
}

parse_flag "$@" && main
