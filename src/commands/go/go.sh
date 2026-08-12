#!/usr/bin/env bash
# cli go lint|test — gofmt + go vet / go test (go image).
set -euo pipefail

cli_go_help() {
  cat <<'EOF'
cli go lint [PATH] — gofmt -l + go vet ./...
cli go test [PATH] — go test ./...
EOF
}

cli_go_main() {
  case "${1:-}" in
    -h|--help) cli_go_help; return 0 ;;
    lint)
      shift
      noun_args "$@"
      require_tool go
      local unformatted
      unformatted="$(cd "$WS" && gofmt -l . 2>/dev/null)"
      if [[ -n "$unformatted" ]]; then
        printf '%s\n' "$unformatted" >&2
        report_fail "go lint" "gofmt needed"
        return 1
      fi
      (cd "$WS" && go vet ./...) || { report_fail "go lint" "go vet failed"; return 1; }
      report_ok "go lint" 0
      ;;
    test)
      shift
      noun_args "$@"
      require_tool go
      (cd "$WS" && go test ./...) || { printf 'go test failed\n' >&2; return 1; }
      cli_ok "go test ok"
      ;;
    *) cli_die "usage: cli go lint|test [PATH]" ;;
  esac
}
