#!/usr/bin/env bash
# build.sh: assembles and builds ONE harness image from a list of tools.
#
#   TOOLS="go kubectl helm" HARNESS_IMAGE_REPO=docker.io/<user>/harness ./build.sh <image-name> [tag]
#
# Dockerfile = image/Dockerfile.base + tools/<t>/Dockerfile (catalogue order, tools/ORDER)
#              + image/Dockerfile.tail. Same prefix across projects = shared layers.
# `harness build` calls this with the project's tools and name; the image is
# <repo>:<image-name>-<tag> and records the tag in .harness/image.tag.
# DRY=1 prints the assembled Dockerfile and stops.
#
# A private Docker Hub repo is recommended: sbx reuses your `sbx login` session
# to pull the image. Another registry requires `sbx secret set --registry <host>`.
# Without a registry: PUSH=0 ./build.sh, then `docker image save` + load into
# the sbx runtime (see the Docker Sandboxes "Templates" doc).

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

NAME="${1:?usage: TOOLS=\"...\" ./build.sh <image-name> [tag]}"
TAG="${2:-$(date +%Y.%m.%d)}"
TOOLS="${TOOLS:-}"
PLATFORM="${PLATFORM:-linux/arm64}"       # Apple Silicon means an arm64 VM; add linux/amd64 if needed
PUSH="${PUSH:-1}"
DRY="${DRY:-0}"

# Validate the tool names against the catalogue, then walk the catalogue in order.
for t in $TOOLS; do
  grep -qx "$t" tools/ORDER || { printf 'build.sh: unknown tool "%s" (see tools/ORDER)\n' "$t" >&2; exit 1; }
done
df="$(mktemp)"; trap 'rm -f "$df"' EXIT
cat image/Dockerfile.base > "$df"
while read -r t; do
  for s in $TOOLS; do
    [[ "$s" == "$t" && -f "tools/$t/Dockerfile" ]] || continue
    printf '\n# ---- %s\n' "$t" >> "$df"
    cat "tools/$t/Dockerfile" >> "$df"
  done
done < tools/ORDER
cat image/Dockerfile.tail >> "$df"

if [[ "$DRY" == 1 ]]; then cat "$df"; exit 0; fi

REPO="${HARNESS_IMAGE_REPO:?HARNESS_IMAGE_REPO missing (e.g. docker.io/you/harness)}"
out=(--load); [[ "$PUSH" == 1 ]] && out=(--push)
printf 'build %s [%s] (%s) -> %s:%s-%s\n' "$NAME" "$TOOLS" "$PLATFORM" "$REPO" "$NAME" "$TAG"
docker buildx build --platform "$PLATFORM" -f "$df" -t "$REPO:$NAME-$TAG" "${out[@]}" image
