#!/usr/bin/env bash

prune_image() {
    yes | docker image prune
    docker images -a | awk '$1 == "<none>" || $2 == "<none>" { print $3 }' | xargs -I {} docker rmi {}
}

prune_container() {
    docker ps -a | grep Exited | awk '{ print $1 }' | xargs -I {} docker rm {}
}

main() {
    echo "########## prune stopped container"
    prune_container

    echo "########## prune images"
    prune_image
}

main
