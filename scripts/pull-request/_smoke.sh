#!/usr/bin/env bash
# Shared read-only integration smoke for an installed `cli` binary.
set -euo pipefail

smoke_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

smoke_default_config_dir() {
  smoke_repo_root
}

smoke_setup_config() {
  # Pure-env config: no config files required.
  export CLI_PROFILE="${CLI_PROFILE:-test}"
}

smoke_require_cli() {
  if ! command -v cli >/dev/null 2>&1; then
    echo "cli binary not found on PATH" >&2
    exit 1
  fi
}

smoke_assert_fails() {
  local desc="$1"
  shift
  set +e
  "$@" >/dev/null 2>&1
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    echo "expected failure: $desc" >&2
    exit 1
  fi
}

smoke_assert_output_contains() {
  local desc="$1"
  local needle="$2"
  shift 2
  local out
  out="$("$@")"
  if [[ "$out" != *"$needle"* ]]; then
    echo "expected output to contain '$needle' for: $desc" >&2
    echo "$out" >&2
    exit 1
  fi
}

smoke_prepare_git_repo() {
  SMOKE_GIT_ROOT="$(mktemp -d)"
  export CLI_GIT_ROOT="$SMOKE_GIT_ROOT"
  git -C "$SMOKE_GIT_ROOT" init -q -b main
  git -C "$SMOKE_GIT_ROOT" config user.email "smoke@test"
  git -C "$SMOKE_GIT_ROOT" config user.name "Smoke"
  echo init >"$SMOKE_GIT_ROOT/README.md"
  git -C "$SMOKE_GIT_ROOT" add README.md
  git -C "$SMOKE_GIT_ROOT" commit -q -m "init"
  git -C "$SMOKE_GIT_ROOT" checkout -q -b feature
  echo feature >>"$SMOKE_GIT_ROOT/README.md"
  git -C "$SMOKE_GIT_ROOT" commit -q -am "feature work"
  git -C "$SMOKE_GIT_ROOT" checkout -q main
}

smoke_cleanup_git_repo() {
  if [[ -n "${SMOKE_GIT_ROOT:-}" && -d "$SMOKE_GIT_ROOT" ]]; then
    rm -rf "$SMOKE_GIT_ROOT"
  fi
}

smoke_run_cli_help() {
  cli --help >/dev/null
  cli --version >/dev/null
  cli integration list >/dev/null
  cli git --help >/dev/null
  cli gh --help >/dev/null
}

smoke_run_readonly_git() {
  cli git branch current >/dev/null
  cli git branch list >/dev/null
  cli git log oneline --base main --head feature >/dev/null
  cli git diff stat --base main --head feature >/dev/null
  cli git rev-list count --base main --head feature >/dev/null
}

smoke_run_readonly_gh() {
  cli gh policy list >/dev/null
  smoke_assert_output_contains "gh policy list" "pr-merge" cli gh policy list
  smoke_assert_fails "gh issue close blocked" cli gh issue close 1 --yes
}

smoke_run_all() {
  smoke_require_cli
  smoke_setup_config
  trap smoke_cleanup_git_repo EXIT
  smoke_run_cli_help
  smoke_prepare_git_repo
  smoke_run_readonly_git
  smoke_run_readonly_gh
  echo "integration smoke passed"
}
