#!/usr/bin/env bash
# cli rust lint|test — cargo clippy / cargo test (rust image).
set -euo pipefail

cli_rust_help() {
  cat <<'EOF'
cli rust lint [PATH] — cargo clippy.
cli rust test [PATH] — cargo test.
EOF
}

cli_rust_main() {
  case "${1:-}" in
    -h|--help) cli_rust_help; return 0 ;;
    lint) shift; noun_args "$@"; require_tool cargo; (cd "$WS" && cargo clippy --all-targets -- -D warnings) || { printf 'rust lint failed\n' >&2; return 1; }; cli_ok "rust lint ok" ;;
    test) shift; noun_args "$@"; require_tool cargo; (cd "$WS" && cargo test) || { printf 'rust test failed\n' >&2; return 1; }; cli_ok "rust test ok" ;;
    *) cli_die "usage: cli rust lint|test [PATH]" ;;
  esac
}
