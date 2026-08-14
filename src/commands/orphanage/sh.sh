#!/usr/bin/env bash
# cli sh lint — shellcheck over *.sh (orphanage image).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_sh_help() {
  cat <<'EOF'
cli sh lint [PATH] [--json] — shellcheck over *.sh (orphanage image).
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_sh_main() {
  case "${1:-}" in
    -h|--help) cli_sh_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli sh lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool shellcheck

  sh_check_one() {
    local rel="$1"
    lint_capture "$WS" shellcheck "$rel"
  }

  lint_each "sh lint" sh_check_one "*.sh"
}
