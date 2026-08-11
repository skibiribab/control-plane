#!/usr/bin/env bash
# Version gate: PR VERSION must be greater than the greatest previous release
# tag (BASE_VERSION from resolve). Skipped only when there is no previous tag.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_run_version_check() {
  local root
  root="$(gh_repo_root)"
  cd "$root"

  if [[ -z "${BASE_VERSION:-}" ]]; then
    echo "no previous release tag yet — version gate skipped (first release)"
    return 0
  fi

  local head_version
  head_version="$(gh_read_project_version "$root")"
  stage_compare_versions "$BASE_VERSION" "$head_version"
}

stage_run_with_timeout "${CI_VERSION_CHECK_TIMEOUT}" _run_version_check
