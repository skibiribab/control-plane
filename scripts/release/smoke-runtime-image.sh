#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${script_dir}/../_common.sh"

_pull_runtime_image() {
  local variant tag
  for variant in "${RUNTIME_VARIANTS[@]}"; do
    tag="$(runtime_variant_tag "${CLI_VERSION:?CLI_VERSION required}" "$variant")"
    docker_wait_and_pull "${RUNTIME_IMAGE:?RUNTIME_IMAGE required}" "${tag#"${RUNTIME_IMAGE}":}"
  done
}

stage_run_with_timeout "${CI_RELEASE_SMOKE_TIMEOUT}" _pull_runtime_image
bash "${script_dir}/verify-runtime-version.sh"
bash "${script_dir}/runtime-docker-smoke.sh"

# Free the runner: drop the pulled images + build cache (~8GB).
docker image prune -af >/dev/null 2>&1 || true
docker builder prune -af >/dev/null 2>&1 || true
