#!/usr/bin/env bash
# Slim publish smoke: after pushing, pull every published variant tag from
# Docker Hub and verify it runs — cli version matches the tag plus one cheap
# tool probe per variant. The full per-variant lint smoke already ran in PR CI
# on the same tree, so this stays fast (build/push-focused release).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_slim_smoke() {
  local version image variant tag probe
  version="${CLI_VERSION:?CLI_VERSION required}"
  image="${RUNTIME_IMAGE:?RUNTIME_IMAGE required}"

  # Nested so it survives the stage_run_with_timeout subshell.
  variant_probe() {
    case "$1" in
      orphanage) echo "qpdf --version" ;;
      node)      echo "node --version" ;;
      python)    echo "python3 --version" ;;
      rust)      echo "cargo --version" ;;
      cpp)       echo "g++ --version" ;;
      go)        echo "go version" ;;
      java)      echo "java -version" ;;
      media)     echo "ffmpeg -version" ;;
      ai)        echo "opencode --version" ;;
      *)         echo "" ;;
    esac
  }

  for variant in "${RUNTIME_VARIANTS[@]}"; do
    tag="$(runtime_variant_tag "$version" "$variant")"
    docker_wait_and_pull "${image}" "${tag#"${image}":}"
    docker run --rm "${tag}" --version | grep -Fxq "$version"
    probe="$(variant_probe "$variant")"
    if [[ -n "$probe" ]]; then
      docker run --rm --entrypoint bash "${tag}" -ec "${probe} >/dev/null 2>&1"
    fi
    echo "publish smoke ok: ${tag}"
  done
}

stage_run_with_timeout "${CI_RELEASE_SMOKE_TIMEOUT:-15m}" _slim_smoke
echo "publish smoke passed: ${RUNTIME_IMAGE:?RUNTIME_IMAGE required}:${CLI_VERSION:?CLI_VERSION required}-*"
