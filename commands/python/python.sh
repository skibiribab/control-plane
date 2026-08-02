#!/usr/bin/env bash
# cli python lint|test — py_compile / pytest (python image).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_python_help() {
  cat <<'EOF'
cli python lint [PATH] [--json] — py_compile over *.py.
cli python test [PATH] — pytest.
PATH: a single file or a subtree root to scan (default ".").
EOF
}

cli_python_main() {
  case "${1:-}" in
    -h|--help) cli_python_help; return 0 ;;
    lint)
      shift
      noun_args "$@"
      require_tool python3

      py_check_one() {
        local rel="$1"
        lint_capture "$WS" python3 -m py_compile "$rel"
      }

      lint_each "python lint" py_check_one "*.py"
      ;;
    test)
      shift
      noun_args "$@"
      require_tool python3
      (cd "$WS" && python3 -m pytest) || { printf 'python test failed\n' >&2; return 1; }
      cli_ok "python test ok"
      ;;
    *) cli_die "usage: cli python lint|test [PATH]" ;;
  esac
}
