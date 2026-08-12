#!/usr/bin/env bash
# File discovery / target resolution helpers for file-type commands.
# Standard: one PATH (a specific file, or a subtree root to discover), then
# find -> list -> iterate one by one.
# shellcheck disable=SC2034,SC2254  # CLI_JSON/CONFIG read cross-file; glob case patterns
set -euo pipefail

# dirs/suffixes always ignored by scans.
CLI_IGNORED_DIRS=(.git .venv __pycache__ node_modules .pytest_cache dist build)

# iter_files <root> [glob ...] — recursively collect matching files (sorted, dedup).
iter_files() {
  local root="$1" pattern
  shift || true
  local -a found=()
  for pattern in "$@"; do
    while IFS= read -r -d '' path; do
      if [[ -f "$path" ]]; then
        local rel="${path#"$root"/}"
        local ignored=0 part d
        for part in ${rel//\// }; do
          for d in "${CLI_IGNORED_DIRS[@]}"; do
            if [[ "$part" == "$d" ]]; then
              ignored=1
            fi
          done
        done
        if [[ "$ignored" == "0" ]]; then
          found+=("$path")
        fi
      fi
    done < <(find "$root" -path "$pattern" -print0 2>/dev/null)
  done
  if ((${#found[@]} > 0)); then
    printf '%s\n' "${found[@]}" | sort -u
  fi
}

# noun_args [PATH] [--config FILE] [--json] — sets TARGET, WS, CONFIG, CLI_JSON.
# Exactly one PATH: a specific file or a subtree root (default ".").
noun_args() {
  TARGET="."
  CONFIG=""
  CLI_JSON=0
  local pos=0
  while (($# > 0)); do
    case "$1" in
      --json) CLI_JSON=1 ;;
      --config) CONFIG="${2:-}"; shift ;;
      -*) cli_die "unknown option: $1" ;;
      *)
        pos=$((pos + 1))
        if ((pos > 1)); then
          cli_die "expected a single PATH (a file or a directory)"
        fi
        TARGET="$1"
        ;;
    esac
    shift
  done
  WS="$(realpath "$TARGET" 2>/dev/null || realpath -m "$TARGET")"
  if [[ -f "$WS" ]]; then
    WS="$(dirname "$WS")"
  fi
}

# find_files <PATH> <glob...> — a single file (if it matches a glob) or every
# matching file under a directory, recursively.
find_files() {
  local path="$1"
  shift
  if [[ -f "$path" ]]; then
    local name="${path##*/}" ok=0 p
    for p in "$@"; do
      case "$name" in
        $p) ok=1 ;;
      esac
    done
    if ((ok)); then
      printf '%s\n' "$path"
    else
      cli_die "file does not match this lint: $path"
    fi
    return 0
  fi
  if [[ -d "$path" ]]; then
    iter_files "$path" "$@"
    return 0
  fi
  cli_die "target does not exist: $path"
}

# collect_files <glob...> — fills FILES array from the workspace.
collect_files() {
  FILES=()
  local path
  while IFS= read -r path; do
    if [[ -n "$path" ]]; then
      FILES+=("$path")
    fi
  done < <(iter_files "$WS" "$@")
}

# rel_paths <workspace> <files...> — print files relative to the workspace.
rel_paths() {
  local workspace="$1"
  shift
  local f
  for f in "$@"; do
    printf '%s\n' "${f#"$workspace"/}"
  done
}
