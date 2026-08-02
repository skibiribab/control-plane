#!/usr/bin/env bash
# Shared find -> list -> iterate-one-by-one runner for file-type commands.
# A command picks files with one PATH (file or subtree root), then validates
# each file individually and reports per-file findings (text or --json).
# shellcheck disable=SC2034  # FAIL_MSG is set in callbacks, read in lint_each
set -euo pipefail

# lint_each <label> <callback> <glob...>
#   Resolve files via find_files "$TARGET" <glob...>, then for each file call
#   <callback> <rel> <ws>. On a non-zero return the callback must set FAIL_MSG.
#   Reports via report_result.
lint_each() {
  local label="$1" cb="$2"
  shift 2
  local files=() path
  while IFS= read -r path; do
    [[ -n "$path" ]] && files+=("$path")
  done < <(find_files "$TARGET" "$@")
  if ((${#files[@]} == 0)); then
    report_skipped "$label"
    return 0
  fi
  local failures="" rel f
  for f in "${files[@]}"; do
    rel="${f#"$WS"/}"
    FAIL_MSG=""
    if ! "$cb" "$rel" "$WS"; then
      failures+="$(printf '%s\t%s\n' "$rel" "${FAIL_MSG:-failed}")"
    fi
  done
  report_result "$label" "${#files[@]}" "$failures"
}

# lint_capture <ws> <cmd...> — run <cmd> with cwd <ws>; on failure set FAIL_MSG
# to the flattened (single-line) output.
lint_capture() {
  local ws="$1"
  shift
  local out
  if out="$(cd "$ws" && "$@" 2>&1)"; then
    return 0
  fi
  FAIL_MSG="$(printf '%s\n' "${out//$'\n'/ | }")"
  [[ -n "$FAIL_MSG" ]] || FAIL_MSG="failed"
  return 1
}
