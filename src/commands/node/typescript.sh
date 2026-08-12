#!/usr/bin/env bash
# cli typescript lint|test — tsc/npm for TypeScript (node image).
set -euo pipefail

cli_typescript_help() {
  cat <<'EOF'
cli typescript lint [PATH] — tsc --noEmit (or npm run lint).
cli typescript test [PATH] — npm test.
EOF
}

cli_typescript_main() {
  case "${1:-}" in
    -h|--help) cli_typescript_help; return 0 ;;
    lint) shift; noun_args "$@"; require_tool npm; (cd "$WS" && npm run lint) || { printf 'typescript lint failed\n' >&2; return 1; }; cli_ok "typescript lint ok" ;;
    test) shift; noun_args "$@"; require_tool npm; (cd "$WS" && npm test) || { printf 'typescript test failed\n' >&2; return 1; }; cli_ok "typescript test ok" ;;
    *) cli_die "usage: cli typescript lint|test [PATH]" ;;
  esac
}
