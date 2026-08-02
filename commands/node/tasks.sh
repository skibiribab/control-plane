#!/usr/bin/env bash
# cli tasks lint — validate tasks/tasks.pairs.json contract (node image).
set -euo pipefail

cli_tasks_help() {
  cat <<'EOF'
cli tasks lint [PATH] [--json] — validate tasks/tasks.pairs.json (node image).
EOF
}

cli_tasks_main() {
  case "${1:-}" in
    -h|--help) cli_tasks_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli tasks lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool jq
  local manifest="${WS}/tasks/tasks.pairs.json"
  if [[ ! -f "$manifest" ]]; then
    report_fail "tasks lint" "task pairs manifest not found: ${manifest}"
    return 1
  fi
  if ! jq empty "$manifest" >/dev/null 2>&1; then
    report_fail "tasks lint" "invalid task pairs manifest JSON"
    return 1
  fi
  report_ok "tasks lint" 1
}
