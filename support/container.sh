#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
base=$(cat "$root/support/container-image.txt")
key=$(cat "$root/support/container-image.txt" "$root/support/Dockerfile" | cksum | awk '{print $1}')
image="paper-revision-template-toolchain:$key"
docker build --platform linux/amd64 --build-arg "BASE_IMAGE=$base" \
  --tag "$image" --file "$root/support/Dockerfile" "$root/support"
exec docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" \
  --env HOME=/tmp --volume "$root:/work" --workdir /work "$image" make "$@"
