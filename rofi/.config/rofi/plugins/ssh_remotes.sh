#!/usr/bin/env bash

show_options() {
    grep -i '^host' "$USER_SSH_DIR/config" | awk '{ print $2 }'
}

connect_to_remote() {
    local conn=${1:?requires ssh conn}

    # local ssh_entry="mosh --ssh='ssh -i $USER_SSH_DIR/id_rsa -F $USER_SSH_DIR/config -t' $conn --"
    local ssh_entry="ssh -i $USER_SSH_DIR/id_rsa -F $USER_SSH_DIR/config -t $conn"
    local user_shell="tmux new -As default"

    coproc {
        eval i3-sensible-terminal -e "$ssh_entry $user_shell"
    }

    local in=${COPROC[1]}
    exec {in}>&-
}

main() {

    case $# in
        0)
            show_options
            ;;
        *)
            connect_to_remote "$@"
            ;;
    esac

}

readonly USER_SSH_DIR="/home/haoliang/.ssh"


main "$@"
