#!/usr/bin/env bash
# Shared helpers for workflow wrappers and Docker stage scripts.
set -euo pipefail

# Stage timeouts — override via env (e.g. in workflow `env:` blocks).
: "${CI_UNIT_TIMEOUT:=5m}"
: "${CI_INTEGRATION_TIMEOUT:=3m}"
: "${CI_DOCKER_BUILD_TIMEOUT:=5m}"
: "${CI_VERSION_CHECK_TIMEOUT:=2m}"
: "${CI_RESOLVE_TIMEOUT:=2m}"
: "${CI_LINT_TIMEOUT:=5m}"
: "${CI_RELEASE_SMOKE_TIMEOUT:=3m}"
: "${CI_DOCKER_PUSH_TIMEOUT:=5m}"
: "${DOCKER_REGISTRY_SETTLE_SECONDS:=0}"
: "${DOCKER_PULL_ATTEMPTS:=12}"
: "${DOCKER_PULL_INITIAL_DELAY:=4}"
: "${DOCKER_PULL_BACKOFF_MULTIPLIER:=2}"
: "${DOCKER_PULL_MAX_DELAY:=45}"

gh_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

PR_DOCKERFILE="${PR_DOCKERFILE:-src/docker/pull-request.dockerfile}"
RELEASE_DOCKERFILE="${RELEASE_DOCKERFILE:-src/docker/base.dockerfile}"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-binarylifter/gardusig-cli}"

# shellcheck disable=SC2034  # consumed by release/pull-request scripts
RUNTIME_VARIANTS=(base rust node python cpp go media java)

runtime_variant_dockerfile() {
  case "$1" in
    base) echo "src/docker/base.dockerfile" ;;
    rust) echo "src/docker/rust.dockerfile" ;;
    node) echo "src/docker/node.dockerfile" ;;
    python) echo "src/docker/python.dockerfile" ;;
    cpp) echo "src/docker/cpp.dockerfile" ;;
    go) echo "src/docker/go.dockerfile" ;;
    media) echo "src/docker/media.dockerfile" ;;
    java) echo "src/docker/java.dockerfile" ;;
    *) echo "unknown runtime variant: $1" >&2; exit 2 ;;
  esac
}

runtime_variant_tag() {
  local version="$1"
  local variant="$2"
  if [[ "$variant" == "base" ]]; then
    echo "${RUNTIME_IMAGE}:${version}"
  else
    echo "${RUNTIME_IMAGE}:${version}-${variant}"
  fi
}

# gh_read_project_version — version from the VERSION file (single source of truth).
gh_read_project_version() {
  local root="${1:-$(gh_repo_root)}"
  tr -d '[:space:]' < "${root}/VERSION"
}

# Version / tag formats (all targets use bare semver X.Y.Z).
gh_strip_v_prefix() {
  local raw="${1:?version required}"
  echo "${raw#v}"
}

gh_set_project_version() {
  local root="${1:?root required}"
  local version
  version="$(gh_strip_v_prefix "${2:?version required}")"
  printf '%s\n' "$version" > "${root}/VERSION"
  echo "VERSION -> ${version}"
}

gh_write_output() {
  local name="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${name}=${value}" >> "$GITHUB_OUTPUT"
  else
    echo "${name}=${value}"
  fi
}

gh_docker_build() {
  local target="$1"
  shift
  local root dockerfile
  root="$(gh_repo_root)"
  dockerfile="${DOCKERFILE:-${PR_DOCKERFILE:-${RELEASE_DOCKERFILE:-}}}"
  if [[ -z "$dockerfile" ]]; then
    echo "DOCKERFILE required (PR_DOCKERFILE or RELEASE_DOCKERFILE)" >&2
    exit 1
  fi
  if [[ ! -f "${root}/${dockerfile}" ]]; then
    echo "dockerfile not found: ${root}/${dockerfile}" >&2
    exit 1
  fi
  docker build -f "${root}/${dockerfile}" --target "$target" "$@" "${root}"
}

export_cli_test_profile() {
  export CLI_PROFILE="${CLI_PROFILE:-test}"
}

# stage_ensure_dev — no-op in the bash CLI (no pip/python). Present for
# compatibility with stage wrappers.
stage_ensure_dev() {
  export_cli_test_profile
  true
}

stage_ensure_test_deps() {
  stage_ensure_dev
}

stage_compare_versions() {
  local base="$1"
  local head="$2"

  # Compare MAJOR.MINOR.PATCH numerically (component-wise), so 1.3.0 > 1.2.10.
  _ver_cmp() {
    local v="$1"
    local -a parts=()
    local piece
    for piece in ${v//./ }; do
      parts+=("${piece//[^0-9]/0}")
    done
    while ((${#parts[@]} < 3)); do parts+=(0); done
    printf '%s\n' "${parts[@]}"
  }

  local -a b h
  mapfile -t b < <(_ver_cmp "$base")
  mapfile -t h < <(_ver_cmp "$head")
  local i
  for ((i = 0; i < 3; i++)); do
    if ((h[i] > b[i])); then
      echo "version ok: ${head} > ${base}"
      return 0
    fi
    if ((h[i] < b[i])); then
      echo "version ${head} is not greater than ${base}" >&2
      return 1
    fi
  done
  echo "version ${head} is not greater than ${base}" >&2
  return 1
}

docker_registry_has_tag() {
  local image="${1:?image required}"
  local tag="${2:?tag required}"
  curl -fsS "https://hub.docker.com/v2/repositories/${image}/tags/${tag}/" >/dev/null 2>&1
}

docker_settle_before_pull() {
  local image="$1"
  local tag="$2"
  local settle="${DOCKER_REGISTRY_SETTLE_SECONDS}"
  if (( settle > 0 )); then
    echo "settling ${settle}s before checking ${image}:${tag} on Docker Hub..."
    sleep "$settle"
  fi
}

# Wait for Docker Hub tag propagation, then pull, with exponential backoff.
docker_wait_and_pull() {
  local image="${1:?image required}"
  local tag="${2:?tag required}"
  local attempts="${DOCKER_PULL_ATTEMPTS}"
  local attempt=1

  docker_settle_before_pull "$image" "$tag"

  while (( attempt <= attempts )); do
    if docker_registry_has_tag "$image" "$tag"; then
      if docker pull "${image}:${tag}"; then
        echo "pulled ${image}:${tag} from Docker Hub"
        return 0
      fi
      echo "registry lists ${image}:${tag} but docker pull failed (${attempt}/${attempts})"
    else
      echo "waiting for ${image}:${tag} on Docker Hub (${attempt}/${attempts})..."
    fi
    if (( attempt < attempts )); then
      local delay
      delay="$(( DOCKER_PULL_INITIAL_DELAY * (2 ** (attempt - 1)) ))"
      (( delay > DOCKER_PULL_MAX_DELAY )) && delay="${DOCKER_PULL_MAX_DELAY}"
      echo "retrying in ${delay}s..."
      sleep "$delay"
    fi
    attempt=$((attempt + 1))
  done
  echo "failed to pull ${image}:${tag} from Docker Hub after ${attempts} attempts" >&2
  return 1
}

stage_run_with_timeout() {
  local limit="$1"
  shift
  if ! command -v timeout >/dev/null 2>&1; then
    echo "timeout command not found (install coreutils)" >&2
    exit 1
  fi
  local runner=("$@")
  if ((${#runner[@]} >= 1)) && declare -F "${runner[0]}" >/dev/null 2>&1; then
    local fn="${runner[0]}"
    local args=()
    if ((${#runner[@]} > 1)); then
      args=("${runner[@]:1}")
    fi
    local quoted=""
    if ((${#args[@]} > 0)); then
      quoted="$(printf ' %q' "${args[@]}")"
    fi
    local common_sh
    common_sh="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
    timeout --signal=TERM --kill-after=30s "$limit" bash -c "source $(printf '%q' "$common_sh"); $(declare -f "$fn"); $fn${quoted}"
    local code=$?
  else
    timeout --signal=TERM --kill-after=30s "$limit" "${runner[@]}"
    local code=$?
  fi
  if [[ "$code" -eq 0 ]]; then
    return 0
  fi
  if [[ "$code" -eq 124 ]]; then
    echo "timed out after ${limit}: ${runner[*]}" >&2
  fi
  return "$code"
}
