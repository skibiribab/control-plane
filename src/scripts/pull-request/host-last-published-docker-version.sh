#!/usr/bin/env bash
# Host-only helper: print the greatest published version (bare X.Y.Z) for
# RUNTIME_IMAGE on Docker Hub — derived from the <version>-<variant> tags,
# paginates ALL tags, greatest semver = latest.
# A 404 (repo/tags not yet published) prints nothing (no published version).
# Transient failures retry a few times, then fall back to the repo's git
# version tags with a warning. Used as the Docker side of the PR version gate.
set -euo pipefail

image="${RUNTIME_IMAGE:-skibiribab/cli}"
attempts="${DOCKER_PULL_ATTEMPTS:-4}"
initial="${DOCKER_PULL_INITIAL_DELAY:-2}"
multiplier="${DOCKER_PULL_BACKOFF_MULTIPLIER:-2}"
max_delay="${DOCKER_PULL_MAX_DELAY:-16}"

_extract_names() {
  grep -oE '"name":"[^"]+"' | sed -E 's/"name":"([^"]+)"/\1/'
}

_extract_next() {
  grep -oE '"next":"[^"]+"' | sed -E 's/"next":"([^"]+)"/\1/'
}

# fetch_tags — print every tag name from Docker Hub (paginated).
# Returns 0 on success or when the repo/tags are absent (404); 1 on transient error.
fetch_tags() {
  local url="https://hub.docker.com/v2/repositories/${image}/tags?page_size=100"
  while [[ -n "$url" && "$url" != "null" ]]; do
    local body code
    body="$(curl -sSL --max-time 20 -w $'\n%{http_code}' "$url" 2>/dev/null)" || return 1
    code="${body##*$'\n'}"
    body="${body%$'\n'*}"
    case "$code" in
      404) return 0 ;;  # not published yet → no published versions
      200) ;;
      *) return 1 ;;    # 429 / 5xx / unexpected → transient, retry
    esac
    printf '%s\n' "$body" | _extract_names
    url="$(printf '%s\n' "$body" | _extract_next)"
  done
  return 0
}

greatest_version() {
  # stdin: tag names -> stdout: greatest bare X.Y.Z (empty if none)
  # Versions come from <version>-<variant> tags only (bare tags are not pushed).
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+-(orphanage|node|python|rust|cpp|go|java|media|ai)$' \
    | sed -E 's/-[^-]+$//' \
    | sort -V -r | head -n1
}

attempt=1
while (( attempt <= attempts )); do
  if tags="$(fetch_tags)"; then
    printf '%s\n' "$(printf '%s\n' "$tags" | greatest_version)"
    exit 0
  fi
  if (( attempt < attempts )); then
    delay="$(( initial * (multiplier ** (attempt - 1)) ))"
    (( delay > max_delay )) && delay="${max_delay}"
    sleep "$delay"
  fi
  attempt=$((attempt + 1))
done

echo "Docker Hub unreachable — falling back to git version tags" >&2
bash "$(dirname "${BASH_SOURCE[0]}")/host-last-published-version.sh"
