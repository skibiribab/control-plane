#!/usr/bin/env bash
# cli json lint — JSON well-formedness over *.json via node (node image).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_json_help() {
  cat <<'EOF'
cli json lint [PATH] [--json] — JSON.parse over *.json (node image).
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_json_main() {
  case "${1:-}" in
    -h|--help) cli_json_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli json lint [PATH] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool node

  json_check_one() {
    local rel="$1"
    lint_capture "$WS" node -e \
      'const fs=require("fs");JSON.parse(fs.readFileSync(process.argv[1],"utf8"));' \
      "$rel"
  }

  lint_each "json lint" json_check_one "*.json"
}
