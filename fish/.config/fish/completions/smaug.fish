complete -f -c smaug

set -l commands download progress lastn
complete -c smaug -a "$commands" \
    -n "not __fish_seen_subcommand_from $commands"

complete -c smaug -s n -l no-proxy \
    -n "__fish_seen_subcommand_from download"
