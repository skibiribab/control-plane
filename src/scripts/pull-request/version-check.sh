#!/usr/bin/env bash
# Version gate (dual-source): the PR head VERSION must be
#   - valid bare semver x.y.z
#   - strictly greater than the greatest git release tag (GIT_VERSION)
#   - strictly greater than the greatest published Docker Hub version (DOCKER_VERSION)
# Each comparison is skipped only when that source has no version yet (first release).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_run_version_check() {
  local root head_version
  root="$(gh_repo_root)"
  cd "$root"

  head_version="$(gh_read_project_version "$root")"
  if [[ ! "$head_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be bare semver x.y.z, got: ${head_version}" >&2
    return 1
  fi
  echo "VERSION ok: ${head_version}"

  if [[ -n "${GIT_VERSION:-}" ]]; then
    stage_compare_versions "$GIT_VERSION" "$head_version"
  else
    echo "no git release tag yet — git comparison skipped (first release)"
  fi

  if [[ -n "${DOCKER_VERSION:-}" ]]; then
    stage_compare_versions "$DOCKER_VERSION" "$head_version"
  else
    echo "no published Docker version yet — Docker comparison skipped (first release)"
  fi
}

stage_run_with_timeout "${CI_VERSION_CHECK_TIMEOUT}" _run_version_check
