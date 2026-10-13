#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=$(cat "$root/support/container-image.txt")
exec docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)"   --env HOME=/tmp --volume "$root:/work" --workdir /work   "$image" make "$@"
