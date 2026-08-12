#!/usr/bin/env bash
# cli javascript lint|test — node/eslint for JavaScript (node image).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_javascript_help() {
  cat <<'EOF'
cli javascript lint [PATH] [--json] — node --check over *.js/*.mjs.
cli javascript test [PATH] — npm test.
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_javascript_main() {
  case "${1:-}" in
    -h|--help) cli_javascript_help; return 0 ;;
    lint)
      shift
      noun_args "$@"
      require_tool node

      js_check_one() {
        local rel="$1"
        lint_capture "$WS" node --check "$rel"
      }

      lint_each "javascript lint" js_check_one "*.js" "*.mjs"
      ;;
    test)
      shift
      noun_args "$@"
      require_tool npm
      (cd "$WS" && npm test) || { printf 'javascript test failed\n' >&2; return 1; }
      cli_ok "javascript test ok"
      ;;
    *) cli_die "usage: cli javascript lint|test [PATH]" ;;
  esac
}
