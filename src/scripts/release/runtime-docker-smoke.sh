#!/usr/bin/env bash
# Release smoke against the pulled runtime image via docker run.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_run_runtime_docker_smoke() {
  local version="${CLI_VERSION:?CLI_VERSION required}"
  local image="${RUNTIME_IMAGE:?RUNTIME_IMAGE required}:${version}-orphanage"

  docker run --rm \
    -e CLI_PROFILE=test \
    -e CLI_CONFIG_DIR=/config \
    --entrypoint bash \
    "${image}" \
    -ec '
      set -euo pipefail
      got="$(cli --version)"
      if [[ "$got" != "'"${version}"'" ]]; then
        echo "runtime version mismatch: expected '"${version}"', got ${got}" >&2
        exit 1
      fi
      cli --help >/dev/null
      cli integration list >/dev/null
      cli gh policy list | grep -Fq pr-merge
    '

  local variant variant_image
  for variant in "${RUNTIME_VARIANTS[@]}"; do
    variant_image="$(runtime_variant_tag "$version" "$variant")"
    bash "$(dirname "${BASH_SOURCE[0]}")/runtime-smoke.sh" "${variant_image}" "$variant"
  done
}

stage_run_with_timeout "${CI_RELEASE_SMOKE_TIMEOUT}" _run_runtime_docker_smoke
echo "runtime docker integration passed: ${RUNTIME_IMAGE:?RUNTIME_IMAGE required}:${CLI_VERSION:?CLI_VERSION required}"
