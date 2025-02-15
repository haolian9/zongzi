#!/bin/bash

gen_workspaces() {
    i3-msg -t get_workspaces | tr ',' '\n' | grep "name" | sed 's/"name":"\(.*\)"/\1/g' | sort -n
}

switch_to_workspace() {

    local workspace=${1:?requires workspace param}

    i3-msg workspace "$workspace" >/dev/null
}

main() {
    case $# in
        0)
            gen_workspaces
            ;;
        *)
            switch_to_workspace "$@"
            ;;
    esac
}

main "$@"
