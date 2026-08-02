#!/usr/bin/env bash
# Push every runtime image variant (versioned tags only, no :latest).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

version="${CLI_VERSION:?CLI_VERSION required}"

_push_runtime_image() {
  for variant in "${RUNTIME_VARIANTS[@]}"; do
    docker push "$(runtime_variant_tag "$version" "$variant")"
  done
  docker push "${RUNTIME_IMAGE}:base-${version}"
}

stage_run_with_timeout "${CI_DOCKER_PUSH_TIMEOUT}" _push_runtime_image

# Free the runner: drop the built/pushed images + build cache.
docker image prune -af >/dev/null 2>&1 || true
docker builder prune -af >/dev/null 2>&1 || true
