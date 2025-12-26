#!/usr/bin/env bash

declare -A known_workdirs
known_workdirs["pearl"]="/srv/pearl"
known_workdirs["playground"]="/srv/playground"
known_workdirs["squidward"]="$HOME/squidward"
known_workdirs["scratchpad"]="$HOME"

notify() {
    [ $# -le 0 ] && return

    notify-send "rofi:plugin:tmux.session" "$*" &>/dev/null
}

list_sessions() {
    tmux list-session -F '#{session_name}' || {
        notify "failed to list session"
        return 1
    }
}

attach_to_session() {
    local session=${1:?requires session param}

    local mutex_option=""
    if [ $MUTEX -ne 0 ]; then
        mutex_option="-d"
    fi

    coproc {
        exec i3-sensible-terminal -e tmux a -t "$session" $mutex_option
    }
}

attach_to_new_session() {
    local session="${1:?requires session param}"
    local _workdir="${2:?requires workdir param}"

    local workdir
    {
        local workdir=${known_workdirs[$session]}
        if [ -z "$workdir" ]; then
            workdir=$(realpath "${_workdir/#\~/$HOME}") || {
                notify "invalid workdir: ${_workdir}"
                return 1
            }
        fi
    }

    tmux new-session -d -c "$workdir" -s $session || {
        notify "failed to create session using name '$session' and workdir '$workdir'"
        return 1
    }

    attach_to_session $session
}

main() {

    # NB: rofi always gives one argument
    # shellcheck disable=SC2116
    set -- $(echo "$@")

    case $# in
        0)
            list_sessions
            ;;
        2)
            attach_to_new_session "$@"
            ;;
        1|*)
            attach_to_session "$*"
            ;;
    esac

}

MUTEX=${MUTEX:-1}

main "$@"
