#!/usr/bin/env bash
# cli yml lint — yamllint over *.yml/*.yaml (python image).
# shellcheck disable=SC2317  # callbacks invoked via lint_each
set -euo pipefail

cli_yml_help() {
  cat <<'EOF'
cli yml lint [PATH] [--config FILE] [--json] — yamllint over *.yml/*.yaml (python image).
PATH: a single file or a subtree root to scan (default ".").
--config: .yamllint file (tool-native) — overrides auto-detect.
EOF
}

cli_yml_main() {
  case "${1:-}" in
    -h|--help) cli_yml_help; return 0 ;;
  esac
  if [[ "${1:-}" != "lint" ]]; then
    cli_die "usage: cli yml lint [PATH] [--config FILE] [--json]"
  fi
  shift
  noun_args "$@"
  require_tool yamllint

  yml_check_one() {
    local rel="$1"
    if [[ -n "$CONFIG" ]]; then
      lint_capture "$WS" yamllint -c "$CONFIG" "$rel"
    else
      lint_capture "$WS" yamllint "$rel"
    fi
  }

  lint_each "yml lint" yml_check_one "*.yml" "*.yaml"
}
