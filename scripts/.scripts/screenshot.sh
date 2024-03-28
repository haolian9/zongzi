#!/usr/bin/env bash
#
# see: https://www.imagemagick.org/script/command-line-options.php#quality

set -e

main() {
    command -v import &>/dev/null || {
        >&2 echo "missing import executable, which provided by imagemagick"
        return 1
    }

    local root=$HOME/screenshot
    mkdir -p "$root"

    local fname
    # fname=$(date +'%Y%m%d_%H%M%S').jpg
    fname="$(uuidgen -t).jpg"

    # quality: 0-100, depth: (2^16)-1
    import -quality 90 -depth 16384 "$root/$fname"

    if [ -f "$root/$fname" ]; then
        notify-send "screenshot" "captured into ${fname}"
    else
        notify-send "screenshot" "nothing captured"
    fi
}

main "$@"
