#!/usr/bin/env bash

# see https://docs.docker.com/engine/reference/commandline/inspect/

inspect_ip() {
    local container=${1:?requires container name or id}
    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$container"
}

inspect_port_bindings() {
    local container=${1:?requires container name or id}
    docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}} {{$p}} -> {{(index $conf 0).HostPort}} {{end}}' "$container"
}

op=${1:?requires operation}
shift

case "$op" in
    ip|--ip)
        inspect_ip "$@"
        ;;
    port|--port)
        inspect_port_bindings "$@"
        ;;
    *)
        >&2 echo "unsuported operation"
        ;;
esac
