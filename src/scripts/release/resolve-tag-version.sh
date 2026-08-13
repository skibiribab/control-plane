#!/usr/bin/env bash
# Resolve release coordinates from a pushed git tag (bare X.Y.Z, no v prefix).
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
  if [[ ! "$ref" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
    echo "expected bare semver tag X.Y.Z (no v prefix), got: $ref" >&2
    exit 1
  fi

  git_tag="$ref"
  version="$ref"
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
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
      | grep -vx "$ref" \
      | head -n1 \
      || true)"
  fi
  if [[ -n "$prev_version" ]]; then
    if ! stage_compare_versions "$prev_version" "$version"; then
      echo "tag ${git_tag} (${version}) must be greater than the previous release (${prev_version})" >&2
      exit 1
    fi
  fi

  # Docker guard: must be greater than the greatest version already published
  # to Docker Hub (a tag that was never pushed helps nobody — e.g. pushing
  # 0.1.0 while 0.2.0 is already live).
  local published
  published="$(stage_max_published_docker_version || true)"
  if [[ -n "$published" ]]; then
    if ! stage_compare_versions "$published" "$version"; then
      echo "tag ${git_tag} (${version}) must be greater than the greatest published Docker version (${published})" >&2
      exit 1
    fi
  fi

  gh_write_output tag "$git_tag"
  gh_write_output git_tag "$git_tag"
  gh_write_output version "$version"
  gh_write_output docker_tag "$version"
}

stage_run_with_timeout "${CI_RESOLVE_TIMEOUT}" _resolve_tag_version
