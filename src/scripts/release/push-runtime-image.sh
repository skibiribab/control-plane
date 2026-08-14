#!/usr/bin/env bash
# Push every runtime image variant (versioned tags only, no :latest).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_push_runtime_image() {
  local version="${CLI_VERSION:?CLI_VERSION required}"
  for variant in "${RUNTIME_VARIANTS[@]}"; do
    docker push "$(runtime_variant_tag "$version" "$variant")"
  done
  docker push "${RUNTIME_IMAGE}:base-${version}"
}

stage_run_with_timeout "${CI_DOCKER_PUSH_TIMEOUT}" _push_runtime_image

# Free the runner: drop the pushed runtime images + build cache. Keep the
# ci-release-* images — the smoke step runs ci-release-smoke right after.
for variant in "${RUNTIME_VARIANTS[@]}"; do
  docker image rm -f "$(runtime_variant_tag "${CLI_VERSION:?CLI_VERSION required}" "$variant")" >/dev/null 2>&1 || true
done
docker image rm -f "${RUNTIME_IMAGE}:base-${CLI_VERSION}" >/dev/null 2>&1 || true
docker builder prune -af >/dev/null 2>&1 || true
