#!/usr/bin/env bash
# cli actions lint — actionlint over GitHub Actions workflows (orphanage image).
set -euo pipefail

cli_actions_help() {
  cat <<'EOF'
cli actions lint [PATH] [--json] — actionlint over .github/workflows/*.yml.
PATH: repo root (default ".").
EOF
}

cli_actions_main() {
  case "${1:-}" in
    -h|--help) cli_actions_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli actions lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool actionlint

  local workflows="${WS}/.github/workflows"
  if [[ ! -d "$workflows" ]]; then
    printf 'actions lint skipped: no .github/workflows\n'
    return 0
  fi
  local files=() f
  while IFS= read -r -d '' f; do files+=("$f"); done < <(
    find "$workflows" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) | sort
  )
  if ((${#files[@]} == 0)); then
    printf 'actions lint skipped: no workflow files\n'
    return 0
  fi
  if ! (cd "$WS" && actionlint "${files[@]}"); then
    report_fail "actions lint" "actionlint reported issues"
    return 1
  fi
  report_ok "actions lint" "${#files[@]}"
}
