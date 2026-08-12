#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

target="${1:?target required}"
shift

DOCKERFILE="${DOCKERFILE:-${RELEASE_DOCKERFILE}}"
root="$(gh_repo_root)"
cd "$root"

stage_run_with_timeout "${CI_DOCKER_BUILD_TIMEOUT}" gh_docker_build "$target" "$@"
