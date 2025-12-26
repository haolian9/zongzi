#!/usr/bin/env bash

_normalize_plugin_name() {
    if [ $# -gt 0 ]; then
        basename "$1" | sed 's/\.\w\+$//' | sed 's/[-_]/./g'
        return
    fi

    while read -r raw; do
        _normalize_plugin_name "$raw"
    done
}

_collect_plugins() {
    for dir in "${PLUGIN_DIRS[@]}"; do
        find "$dir" -type f,l -executable 2>/dev/null
    done
}

_prime_found_plugins() {
    local plugin
    local file
    for file in $(_collect_plugins); do
        plugin="$(_normalize_plugin_name "$file")"
        if [ -n "${FOUND_PLUGINS[$plugin]}" ]; then
            logger "[warning] #skipped# dulplicate plugin found: $plugin => {${FOUND_PLUGINS[$plugin]}, $file}, keeping first"
            continue
        fi
        FOUND_PLUGINS["$plugin"]="$file"
    done
}

_find_plugin_file() {
    local plugin=${1:?requires plugin param}
    local file

    file="${FOUND_PLUGINS[$plugin]}"

    if [ -x "$file" ]; then
        echo "$file"
        return
    fi

    return 1
}

logger() {
    echo "[$(date '+%H:%M:%S')] $*" >> $LOG_FILE
}

show_plugins() {
    for name in "${!FOUND_PLUGINS[@]}"; do
        echo "$name"
    done
}

run_plugin() {
    local plugin=${1:?requires plugin param}
    local modi

    if [ -x "$plugin" ]; then
        modi=$(_normalize_plugin_name "$plugin")
    else
        modi="$plugin"
        plugin="$(_find_plugin_file "$plugin" || {
            logger "failed to find file for $plugin"
            return 1
        })"
    fi

    logger "plugin: $plugin; modi: $modi"

    # I do need -sort(-method) options combined with fuzzy, see: https://github.com/davatorium/rofi/issues/810
    coproc {
        exec rofi -show "$modi" -modi "$modi":"$plugin" -matching fuzzy -sort -sorting-method=levenshtein
    }
}

main() {

    case $# in
        0)
            show_plugins
            ;;
        *)
            run_plugin "$@"
            ;;
    esac

}

PLUGIN_DIRS=(
"$HOME/.config/rofi/plugins"
"$HOME/.local/share/rofi/plugins"
)

LOG_FILE="/tmp/${UID}.rofi.plugin.entry.log"

# todo: cache in file if needed
declare -A FOUND_PLUGINS

_prime_found_plugins && main "$@"
