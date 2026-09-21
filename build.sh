#!/usr/bin/env bash
# build.sh: builds and pushes the harness images (dev and infra targets).
#
#   HARNESS_IMAGE_REPO=docker.io/<user>/harness ./build.sh [tag]
#
# A private Docker Hub repo is recommended: sbx reuses your `sbx login` session
# to pull the image. Another registry requires `sbx secret set --registry <host>`.
# Without a registry: PUSH=0 ./build.sh, then `docker image save` + load into
# the sbx runtime (see the Docker Sandboxes "Templates" doc).

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/image"

REPO="${HARNESS_IMAGE_REPO:?HARNESS_IMAGE_REPO missing (e.g. docker.io/you/harness)}"
TAG="${1:-$(date +%Y.%m.%d)}"
PLATFORM="${PLATFORM:-linux/arm64}"       # Apple Silicon means an arm64 VM; add linux/amd64 if needed
PUSH="${PUSH:-1}"

out=(--load); [[ "$PUSH" == 1 ]] && out=(--push)

for target in dev infra; do
  printf 'build %s (%s) -> %s:%s-%s\n' "$target" "$PLATFORM" "$REPO" "$target" "$TAG"
  docker buildx build --platform "$PLATFORM" --target "$target" \
    -t "$REPO:$target-$TAG" "${out[@]}" .
done

printf '%s\n' "$TAG" > TAG
printf 'tag %s written to image/TAG; `harness run` will use it\n' "$TAG"
