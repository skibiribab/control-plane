#!/usr/bin/env bash
# Resolve release coordinates from a pushed git tag (X.Y.Z).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_resolve_tag_version() {
  local ref git_tag version root project_version
  ref="${GITHUB_REF_NAME:-}"
  if [[ -z "$ref" ]]; then
    echo "GITHUB_REF_NAME is required (push a release tag)" >&2
    exit 1
  fi
  if [[ ! "$ref" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
    echo "expected semver tag X.Y.Z (optional v prefix), got: $ref" >&2
    exit 1
  fi

  git_tag="$ref"
  version="$(gh_strip_v_prefix "$ref")"
  root="$(gh_repo_root)"
  project_version="$(gh_read_project_version "$root")"
  if [[ "$version" != "$project_version" ]]; then
    echo "tag ${git_tag} (${version}) must match VERSION (${project_version})" >&2
    exit 1
  fi

  # Downgrade guard: the new release must be greater than the previous one.
  local prev_version
  if [[ -n "${PREV_VERSION:-}" ]]; then
    prev_version="${PREV_VERSION}"
  else
    prev_version="$(git tag --sort=-v:refname 2>/dev/null \
      | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' \
      | grep -vx "$ref" \
      | head -n1 \
      | sed 's/^v//' \
      || true)"
  fi
  if [[ -n "$prev_version" ]]; then
    if ! stage_compare_versions "$prev_version" "$version"; then
      echo "tag ${git_tag} (${version}) must be greater than the previous release (${prev_version})" >&2
      exit 1
    fi
  fi

  gh_write_output tag "$git_tag"
  gh_write_output git_tag "$git_tag"
  gh_write_output version "$version"
  gh_write_output docker_tag "$version"
}

stage_run_with_timeout "${CI_RESOLVE_TIMEOUT}" _resolve_tag_version
