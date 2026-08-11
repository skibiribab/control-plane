#!/usr/bin/env bash
# cli url — link check via lychee (rust image).
set -euo pipefail

cli_url_help() {
  cat <<'EOF'
cli url [PATH] [--json] — check links in the repo with lychee (rust image).
EOF
}

cli_url_main() {
  case "${1:-}" in
    -h|--help) cli_url_help; return 0 ;;
  esac
  noun_args "$@"
  require_tool lychee
  [[ -d "$WS" ]] || { report_fail "url" "target is not a directory: ${TARGET}"; return 1; }
  if ! (cd "$WS" && lychee --no-progress .); then
    report_result "url" 1 "lychee reported broken links"
    return 1
  fi
  report_ok "url" 1
}
