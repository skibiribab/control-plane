#!/usr/bin/env bash
# Resolve PR head version and greatest previous release versions. Both gates
# feed the version check: the greatest git release tag (GIT_VERSION) and the
# greatest published Docker Hub version (DOCKER_VERSION) — each empty when none.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_resolve_versions() {
  local root
  root="$(gh_repo_root)"
  cd "$root"

  local version base_version git_version
  version="$(gh_read_project_version "$root")"
  base_version="${DOCKER_VERSION:-}"
  git_version="${GIT_VERSION:-}"

  gh_write_output version "$version"
  gh_write_output base_version "$base_version"
  gh_write_output git_version "$git_version"
}

stage_run_with_timeout "${CI_RESOLVE_TIMEOUT}" _resolve_versions
